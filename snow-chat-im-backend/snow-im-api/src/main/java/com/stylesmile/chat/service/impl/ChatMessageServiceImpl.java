package com.stylesmile.chat.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.conditions.update.LambdaUpdateWrapper;
import com.stylesmile.chat.entity.ChatGroupMember;
import com.stylesmile.chat.entity.ChatMessage;
import com.stylesmile.chat.entity.ChatOfflineMessage;
import com.stylesmile.chat.entity.ChatSession;
import com.stylesmile.chat.mapper.ChatMessageMapper;
import com.stylesmile.chat.mapper.ChatOfflineMessageMapper;
import com.stylesmile.chat.mqtt.MqttConnectStatusListener;
import com.stylesmile.chat.mqtt.MqttPushService;
import com.stylesmile.chat.mqtt.MqttTopics;
import com.stylesmile.chat.service.ChatGroupMemberService;
import com.stylesmile.chat.service.ChatMessageService;
import com.stylesmile.chat.service.ChatSessionService;
import com.stylesmile.common.service.BaseServiceImpl;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import javax.annotation.Resource;
import java.util.*;

/**
 * 消息服务实现
 */
@Service
public class ChatMessageServiceImpl extends BaseServiceImpl<ChatMessageMapper, ChatMessage> implements ChatMessageService {

    private static final Logger log = LoggerFactory.getLogger(ChatMessageServiceImpl.class);

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

    @Override
    public List<ChatMessage> getHistoryMessages(Integer userId, Integer targetId, String targetType, int page, int size) {
        return baseMapper.getHistoryMessages(userId, targetId, targetType, (page - 1) * size, size);
    }

    @Override
    public List<ChatMessage> getHistoryMessagesByCursor(Integer userId, Integer targetId, String targetType, Integer beforeMessageId, int size) {
        LambdaQueryWrapper<ChatMessage> wrapper = new LambdaQueryWrapper<>();

        if ("friend".equalsIgnoreCase(targetType)) {
            wrapper.and(w -> w
                    .eq(ChatMessage::getFromUserId, userId).eq(ChatMessage::getToUserId, targetId)
                    .or()
                    .eq(ChatMessage::getFromUserId, targetId).eq(ChatMessage::getToUserId, userId));
        } else if ("group".equalsIgnoreCase(targetType)) {
            wrapper.eq(ChatMessage::getGroupId, targetId);
        }

        if (beforeMessageId != null) {
            wrapper.lt(ChatMessage::getId, beforeMessageId);
        }
        wrapper.orderByDesc(ChatMessage::getCreateTime);
        wrapper.last("LIMIT " + size);
        return baseMapper.selectList(wrapper);
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
        save(message);

        // 更新发送方会话
        Integer targetId = message.getGroupId() != null ? message.getGroupId() : message.getToUserId();
        String targetType = message.getGroupId() != null ? "group" : "friend";
        chatSessionService.getOrCreateSession(message.getFromUserId(), targetId, targetType);

        publishMessage(message);
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

        if (message.getGroupId() != null) {
            // 群消息：推送给群内所有成员
            mqttPushService.publish(MqttTopics.group(message.getGroupId()), 2001, data);
            // 为不在线的群成员保存离线消息
            saveOfflineForGroup(message, data);
        } else if (message.getToUserId() != null) {
            // 私聊消息：推送给接收方
            pushToUser(message.getToUserId(), 2001, data, message);
            // 同时也推送给发送方（回显，确认发送成功）
            if (!message.getFromUserId().equals(message.getToUserId())) {
                pushToUser(message.getFromUserId(), 2001, data, message);
            }
        }
    }

    /**
     * 推送给用户；如果用户不在线则保存离线消息
     */
    private void pushToUser(Integer userId, int cmd, Map<String, Object> data, ChatMessage message) {
        String topic = MqttTopics.user(userId);
        if (mqttConnectStatusListener.isOnline(clientId(userId))) {
            mqttPushService.publish(topic, cmd, data);
        } else {
            saveOfflineMessage(userId, topic, cmd, data);
        }
        // 更新接收方会话与未读数
        Integer targetId = message.getGroupId() != null ? message.getGroupId() : message.getFromUserId();
        String targetType = message.getGroupId() != null ? "group" : "friend";
        chatSessionService.getOrCreateSession(userId, targetId, targetType);
        chatSessionService.updateLastMessage(userId, targetId, targetType, message.getContent());
    }

    private String clientId(Integer userId) {
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
            Integer userId = member.getUserId();
            // 不发给自己
            if (userId.equals(message.getFromUserId())) {
                continue;
            }
            if (!mqttConnectStatusListener.isOnline(clientId(userId))) {
                saveOfflineMessage(userId, MqttTopics.group(message.getGroupId()), 2001, data);
            }
        }
    }

    private void saveOfflineMessage(Integer toUserId, String topic, int cmd, Map<String, Object> data) {
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
    public void recallMessage(Integer userId, Long messageId) {
        ChatMessage message = getById(messageId);
        if (message != null && message.getFromUserId().equals(userId)) {
            message.setContent("[消息已撤回]");
            message.setType("recall");
            updateById(message);

            Map<String, Object> data = new HashMap<>();
            data.put("messageId", messageId);
            data.put("fromUserId", userId);
            data.put("toUserId", message.getToUserId());
            data.put("groupId", message.getGroupId());
            data.put("type", "recall");
            data.put("createTime", message.getCreateTime());

            if (message.getGroupId() != null) {
                mqttPushService.publish(MqttTopics.group(message.getGroupId()), 2006, data);
            } else if (message.getToUserId() != null) {
                pushToUser(message.getToUserId(), 2006, data, message);
                if (!userId.equals(message.getToUserId())) {
                    pushToUser(userId, 2006, data, message);
                }
            }
        }
    }

    @Override
    public void markAsRead(Integer userId, Integer targetId, String targetType) {
        LambdaUpdateWrapper<ChatMessage> wrapper = new LambdaUpdateWrapper<>();
        wrapper.eq(ChatMessage::getToUserId, userId)
               .eq(ChatMessage::getStatus, 0)
               .set(ChatMessage::getStatus, 1);

        if ("friend".equalsIgnoreCase(targetType)) {
            wrapper.and(w -> w.eq(ChatMessage::getFromUserId, targetId));
        } else if ("group".equalsIgnoreCase(targetType)) {
            wrapper.eq(ChatMessage::getGroupId, targetId);
        }
        update(wrapper);
    }
}
