package com.stylesmile.chat.service.impl;

import cn.hutool.core.util.IdUtil;
import com.stylesmile.chat.entity.ChatGroupMember;
import com.stylesmile.chat.entity.ChatMessage;
import com.stylesmile.chat.entity.ChatMessageRoute;
import com.stylesmile.chat.entity.ChatOfflineMessage;
import com.stylesmile.chat.entity.ChatSession;
import com.stylesmile.chat.mapper.ChatMessageMapper;
import com.stylesmile.chat.mapper.ChatMessageRouteMapper;
import com.stylesmile.chat.mapper.ChatOfflineMessageMapper;
import com.stylesmile.chat.mqtt.MqttConnectStatusListener;
import com.stylesmile.chat.mqtt.MqttPushService;
import com.stylesmile.chat.mqtt.MqttTopics;
import com.stylesmile.chat.mqtt.WsCmd;
import com.stylesmile.chat.service.ChatGroupMemberService;
import com.stylesmile.chat.service.ChatMessageService;
import com.stylesmile.chat.service.ChatSessionService;
import com.stylesmile.chat.shard.MessageShardRouter;
import com.stylesmile.chat.shard.MessageShardSchemaService;
import com.stylesmile.common.service.BaseServiceImpl;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import javax.annotation.Resource;
import java.util.*;

/**
 * 消息服务实现。
 *
 * <p><b>分表</b>：消息按「群 / 私聊会话」落在不同的物理表
 * （{@code chat_message_group_N} / {@code chat_message_friend_N}，见 {@link MessageShardRouter}）。
 * 本类是唯一需要感知分表的地方，所有 SQL 都通过 {@link ChatMessageMapper} 带 {@code table}
 * 参数下发；上游 Controller 与前端完全无感。
 *
 * <p>两类入口的表定位方式不同：
 * <ul>
 *   <li>知道会话（拉历史、发消息、标记已读）→ 直接用 {@code targetType + userId + targetId} 算表；</li>
 *   <li>只知道 messageId（撤回、已读回执）→ 先查 {@code chat_message_route} 拿分片，再还原表名。</li>
 * </ul>
 */
@Service
public class ChatMessageServiceImpl extends BaseServiceImpl<ChatMessageMapper, ChatMessage> implements ChatMessageService {

    private static final Logger log = LoggerFactory.getLogger(ChatMessageServiceImpl.class);

    // 消息类型：self 表示"文件传输助手"（发给自己的消息，同步到自己的其他登录端）
    private static final String TYPE_SELF = "self";
    // 会话目标类型：file_helper 对应文件传输助手会话
    private static final String TARGET_FILE_HELPER = "file_helper";
    // 会话目标类型：group 对应群聊
    private static final String TARGET_GROUP = "group";
    // 会话目标类型：friend 对应私聊
    private static final String TARGET_FRIEND = "friend";

    @Resource
    private MqttPushService mqttPushService;
    @Resource
    private MqttConnectStatusListener mqttConnectStatusListener;
    @Resource
    private ChatOfflineMessageMapper chatOfflineMessageMapper;
    @Resource
    private ChatSessionService chatSessionService;
    @Resource
    private ChatGroupMemberService chatGroupMemberService;
    @Resource
    private ChatMessageRouteMapper chatMessageRouteMapper;
    @Resource
    private MessageShardRouter shardRouter;
    @Resource
    private MessageShardSchemaService shardSchemaService;

    @Override
    public List<ChatMessage> getHistoryMessages(Long userId, Long targetId, String targetType, int page, int size) {
        String table = resolveTable(targetType, userId, targetId);
        return baseMapper.getHistoryMessages(table, userId, targetId, targetType, (page - 1) * size, size);
    }

    @Override
    public List<ChatMessage> getHistoryMessagesByCursor(Long userId, Long targetId, String targetType, Long beforeMessageId, int size) {
        String table = resolveTable(targetType, userId, targetId);
        return baseMapper.getMessagesByCursor(table, userId, targetId, targetType, beforeMessageId, size);
    }

    @Override
    @Transactional
    public void sendMessage(ChatMessage message) {
        if (message.getFromUserId() == null) {
            throw new IllegalArgumentException("fromUserId is required");
        }
        if (message.getToUserId() == null && message.getGroupId() == null) {
            throw new IllegalArgumentException("toUserId or groupId is required");
        }
        message.setCreateTime(new Date());
        message.setStatus(0);
        message.setPushStatus("server_received"); // 服务器已收到
        saveMessage(message);

        // 更新发送方会话
        Long targetId = message.getGroupId() != null ? message.getGroupId() : message.getToUserId();
        chatSessionService.getOrCreateSession(message.getFromUserId(), targetId, resolveTargetType(message));

        publishMessage(message);

        // 向发送方回推回执，确认服务器已收到并推送
        sendReceiptAckToSender(message);
    }

    /**
     * 只落库：按分片写进对应的物理表并登记路由，不做任何推送。
     */
    @Override
    @Transactional
    public void saveMessage(ChatMessage message) {
        // 分表后各表的自增 ID 互不相干，必须用全局唯一 ID（与 MP 的 ASSIGN_ID 同款雪花）
        if (message.getId() == null) {
            message.setId(IdUtil.getSnowflakeNextId());
        }
        if (message.getCreateTime() == null) {
            message.setCreateTime(new Date());
        }
        if (message.getStatus() == null) {
            message.setStatus(0);
        }

        String targetType = resolveTargetType(message);
        Long shardKey = resolveShardKey(message);
        String table = shardEnabled()
                ? shardSchemaService.ensureTableByName(shardRouter.tableForRoute(targetType, shardKey))
                : shardRouter.mainTable();

        baseMapper.insertInto(table, message);
        saveRoute(message.getId(), targetType, shardKey);
    }

    /**
     * 判断消息属于哪类会话：群消息=group；type=self（发给自己的文件助手消息）=file_helper；其余=friend。
     */
    private String resolveTargetType(ChatMessage message) {
        return message.getGroupId() != null ? TARGET_GROUP
                : (TYPE_SELF.equals(message.getType()) ? TARGET_FILE_HELPER : TARGET_FRIEND);
    }

    /**
     * 计算分片键：群=groupId；私聊=min(收发双方用户ID)。
     */
    private Long resolveShardKey(ChatMessage message) {
        if (message.getGroupId() != null) {
            return message.getGroupId();
        }
        return shardRouter.friendShardKey(message.getFromUserId(), message.getToUserId());
    }

    /**
     * 写一行分片路由，供"只知 messageId"的撤回/回执定位表。
     */
    private void saveRoute(Long messageId, String targetType, Long shardKey) {
        if (!shardEnabled()) {
            return;
        }
        ChatMessageRoute route = new ChatMessageRoute();
        route.setId(messageId);
        route.setTargetType(targetType);
        route.setShardKey(shardKey);
        chatMessageRouteMapper.insert(route);
    }

    /**
     * 由会话信息算出物理表名（并确保表已存在）。
     */
    private String resolveTable(String targetType, Long userId, Long targetId) {
        if (!shardEnabled()) {
            return shardRouter.mainTable();
        }
        return shardSchemaService.ensureTableByName(shardRouter.tableFor(targetType, userId, targetId));
    }

    /**
     * 由 messageId 查路由还原物理表名；查不到路由（历史数据未迁移）时返回 null。
     */
    private String resolveTableByMessageId(Long messageId) {
        if (!shardEnabled()) {
            return shardRouter.mainTable();
        }
        ChatMessageRoute route = chatMessageRouteMapper.selectById(messageId);
        if (route == null || route.getShardKey() == null) {
            log.warn("消息 {} 没有分片路由记录，无法定位分表", messageId);
            return null;
        }
        return shardSchemaService.ensureTableByName(
                shardRouter.tableForRoute(route.getTargetType(), route.getShardKey()));
    }

    private boolean shardEnabled() {
        return shardRouter.isShardEnabled();
    }

    private void publishMessage(ChatMessage message) {
        Map<String, Object> data = new HashMap<>();
        data.put("id", message.getId());
        data.put("fromUserId", message.getFromUserId());
        data.put("toUserId", message.getToUserId());
        data.put("groupId", message.getGroupId());
        data.put("type", message.getType());
        data.put("content", message.getContent());
        data.put("localSeq", message.getLocalSeq());
        data.put("createTime", message.getCreateTime());

        log.info("Publishing message id={}, from={}, to={}, groupId={}",
                message.getId(), message.getFromUserId(), message.getToUserId(), message.getGroupId());

        if (message.getGroupId() != null) {
            // 群消息：推送给群内所有成员（发送方客户端通过 localSeq 去重自己的消息）
            mqttPushService.publish(MqttTopics.group(message.getGroupId()), WsCmd.MSG_PUSH, data);
            // 为不在线的群成员保存离线消息
            saveOfflineForGroup(message, data);
        } else if (message.getToUserId() != null) {
            // 私聊消息：只推送给接收方
            pushToUser(message.getToUserId(), WsCmd.MSG_PUSH, data, message);
        }
    }

    /**
     * 向发送方发送回执，确认服务器已收到并推送了消息
     */
    private void sendReceiptAckToSender(ChatMessage message) {
        if (message.getFromUserId() == null) return;
        Map<String, Object> receiptData = new HashMap<>();
        receiptData.put("messageId", message.getId());
        receiptData.put("fromUserId", message.getFromUserId());
        receiptData.put("toUserId", message.getToUserId());
        receiptData.put("groupId", message.getGroupId());
        receiptData.put("createTime", message.getCreateTime());

        String topic = MqttTopics.user(message.getFromUserId());
        mqttPushService.publish(topic, WsCmd.MSG_RECEIPT_ACK, receiptData);
        log.info("Sent receiptAck to sender userId={}, messageId={}", message.getFromUserId(), message.getId());
    }

    /**
     * 推送给用户；始终尝试 MQTT 实时推送，用户不在线时额外保存离线消息兜底
     */
    private void pushToUser(Long userId, int cmd, Map<String, Object> data, ChatMessage message) {
        String topic = MqttTopics.user(userId);
        // 始终尝试 MQTT 实时推送（在线客户端直接收到，broker 对 cleanSession 客户端不缓存）
        mqttPushService.publish(topic, cmd, data);
        // 用户不在线时额外保存离线消息，确保上线后能补投
        if (!mqttConnectStatusListener.isOnline(clientId(userId))) {
            saveOfflineMessage(userId, topic, cmd, data);
        }
        // 更新接收方会话与未读数
        Long targetId = message.getGroupId() != null ? message.getGroupId() : message.getFromUserId();
        // 会话目标类型：群消息=group；type=self（发给自己的文件助手消息）也会被推送到自己 topic，归为 file_helper；其余=friend
        String targetType = resolveTargetType(message);
        chatSessionService.getOrCreateSession(userId, targetId, targetType);
        chatSessionService.updateLastMessage(userId, targetId, targetType, message.getContent());
    }

    private String clientId(Long userId) {
        return userId == null ? "" : "user_" + userId;
    }

    /**
     * 为群离线成员保存离线消息
     */
    private void saveOfflineForGroup(ChatMessage message, Map<String, Object> data) {
        List<ChatGroupMember> members = chatGroupMemberService.getMembersByGroupId(message.getGroupId());
        if (members == null || members.isEmpty()) {
            return;
        }
        for (ChatGroupMember member : members) {
            Long userId = member.getUserId();
            // 不发给自己
            if (userId.equals(message.getFromUserId())) {
                continue;
            }
            if (!mqttConnectStatusListener.isOnline(clientId(userId))) {
                saveOfflineMessage(userId, MqttTopics.group(message.getGroupId()), WsCmd.MSG_PUSH, data);
            }
        }
    }

    private void saveOfflineMessage(Long toUserId, String topic, int cmd, Map<String, Object> data) {
        try {
            String payload = String.format(
                    "{\"cmd\":%d,\"seq\":\"%s\",\"data\":%s}",
                    cmd,
                    UUID.randomUUID().toString(),
                    toJson(data)
            );
            ChatOfflineMessage offline = new ChatOfflineMessage();
            offline.setToUserId(toUserId);
            offline.setTopic(topic);
            offline.setCmd(cmd);
            offline.setPayload(payload);
            offline.setCreateTime(new Date());
            chatOfflineMessageMapper.insert(offline);
        } catch (Exception e) {
            log.error("Failed to save offline message for user {}", toUserId, e);
        }
    }

    private String toJson(Map<String, Object> data) {
        StringBuilder sb = new StringBuilder("{");
        boolean first = true;
        for (Map.Entry<String, Object> entry : data.entrySet()) {
            if (!first) sb.append(",");
            first = false;
            sb.append("\"").append(entry.getKey()).append("\":");
            Object value = entry.getValue();
            if (value == null) {
                sb.append("null");
            } else if (value instanceof Number) {
                sb.append(value);
            } else {
                sb.append("\"").append(value).append("\"");
            }
        }
        sb.append("}");
        return sb.toString();
    }

    @Override
    @Transactional
    public void recallMessage(Long userId, Long messageId) {
        String table = resolveTableByMessageId(messageId);
        if (table == null) {
            return;
        }
        ChatMessage message = baseMapper.selectByIdFrom(table, messageId);
        if (message != null && message.getFromUserId().equals(userId)) {
            baseMapper.recallById(table, messageId);
            message.setContent("[消息已撤回]");
            message.setType("recall");

            Map<String, Object> data = new HashMap<>();
            data.put("messageId", messageId);
            data.put("fromUserId", userId);
            data.put("toUserId", message.getToUserId());
            data.put("groupId", message.getGroupId());
            data.put("type", "recall");
            data.put("createTime", message.getCreateTime());

            if (message.getGroupId() != null) {
                mqttPushService.publish(MqttTopics.group(message.getGroupId()), WsCmd.FRIEND_ACCEPTED, data);
            } else if (message.getToUserId() != null) {
                pushToUser(message.getToUserId(), WsCmd.FRIEND_ACCEPTED, data, message);
                if (!userId.equals(message.getToUserId())) {
                    pushToUser(userId, WsCmd.FRIEND_ACCEPTED, data, message);
                }
            }
        }
    }

    @Override
    public void markAsRead(Long userId, Long targetId, String targetType) {
        String table = resolveTable(targetType, userId, targetId);
        baseMapper.markRead(table, userId, targetId, targetType);
    }

    @Override
    @Transactional
    public void processReceipt(Long messageId, Long userId) {
        String table = resolveTableByMessageId(messageId);
        if (table == null) {
            return;
        }
        // 1. 更新消息推送状态为 delivered（接收方已确认收到）
        // 状态机：pending → server_received → delivered
        baseMapper.updatePushStatus(table, messageId, "delivered");

        // 2. 查询消息，获取发送方 ID，向发送方推送回执
        ChatMessage message = baseMapper.selectByIdFrom(table, messageId);
        if (message != null && message.getFromUserId() != null) {
            Map<String, Object> receiptData = new HashMap<>();
            receiptData.put("messageId", messageId);
            receiptData.put("userId", userId);
            receiptData.put("fromUserId", message.getFromUserId());
            receiptData.put("toUserId", message.getToUserId());
            receiptData.put("groupId", message.getGroupId());

            // 推送给发送方，告知消息已送达
            String senderTopic = MqttTopics.user(message.getFromUserId());
            mqttPushService.publish(senderTopic, WsCmd.MSG_RECEIPT_ACK, receiptData);
            log.info("Receipt processed: messageId={}, userId={}, notifying sender={}", messageId, userId, message.getFromUserId());
        }
    }

    @Override
    public void fetchAndPushUndelivered(Long userId, Long targetId, String targetType) {
        List<ChatMessage> undelivered = getUndeliveredMessages(userId, targetId, targetType);
        if (undelivered.isEmpty()) {
            return;
        }

        // 构造消息列表并推送给用户
        List<Map<String, Object>> messageList = new ArrayList<>();
        for (ChatMessage msg : undelivered) {
            Map<String, Object> data = new HashMap<>();
            data.put("id", msg.getId());
            data.put("fromUserId", msg.getFromUserId());
            data.put("toUserId", msg.getToUserId());
            data.put("groupId", msg.getGroupId());
            data.put("type", msg.getType());
            data.put("content", msg.getContent());
            data.put("localSeq", msg.getLocalSeq());
            data.put("createTime", msg.getCreateTime());
            messageList.add(data);
        }

        String topic = MqttTopics.user(userId);
        mqttPushService.publish(topic, WsCmd.FETCH_UNDELIVERED_ACK, Map.of("messages", messageList));
        log.info("Pushed {} undelivered messages to userId={}, targetId={}", undelivered.size(), userId, targetId);
    }

    @Override
    public List<ChatMessage> getUndeliveredMessages(Long userId, Long targetId, String targetType) {
        String table = resolveTable(targetType, userId, targetId);
        List<ChatMessage> undelivered = baseMapper.selectUndelivered(table, userId, targetId, targetType);
        log.info("Found {} undelivered messages for userId={}, targetId={}", undelivered.size(), userId, targetId);
        return undelivered;
    }
}
