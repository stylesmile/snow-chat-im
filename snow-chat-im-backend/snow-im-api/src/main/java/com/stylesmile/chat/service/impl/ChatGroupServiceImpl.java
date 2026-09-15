package com.stylesmile.chat.service.impl;

import com.stylesmile.common.service.BaseServiceImpl;
import com.stylesmile.chat.entity.ChatGroup;
import com.stylesmile.chat.entity.ChatMessage;
import com.stylesmile.chat.mapper.ChatGroupMapper;
import com.stylesmile.chat.mqtt.MqttPushService;
import com.stylesmile.chat.mqtt.MqttTopics;
import com.stylesmile.chat.mqtt.WsCmd;
import com.stylesmile.chat.service.ChatGroupMemberService;
import com.stylesmile.chat.service.ChatGroupService;
import com.stylesmile.chat.service.ChatMessageService;
import com.stylesmile.chat.service.ChatUserService;
import com.stylesmile.chat.shard.MessageShardRouter;
import com.stylesmile.chat.shard.MessageShardSchemaService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import javax.annotation.Resource;
import java.util.*;

/**
 * 群组服务实现
 *
 * @author chenye
 * @date 2018/12/10
 */
@Service
public class ChatGroupServiceImpl extends BaseServiceImpl<ChatGroupMapper, ChatGroup> implements ChatGroupService {

    private static final Logger log = LoggerFactory.getLogger(ChatGroupServiceImpl.class);

    @Resource
    private ChatGroupMemberService chatGroupMemberService;

    @Resource
    private ChatMessageService chatMessageService;

    @Resource
    private ChatUserService chatUserService;

    @Resource
    private MqttPushService mqttPushService;

    @Resource
    private MessageShardRouter shardRouter;

    @Resource
    private MessageShardSchemaService shardSchemaService;

    @Override
    public ChatGroup getGroupById(Long groupId) {
        return getById(groupId);
    }

    @Override
    public List<ChatGroup> getGroupsByUserId(Long userId) {
        return baseMapper.getGroupsByUserId(userId);
    }

    /**
     * 建群成功后预建该群的群消息分表。
     *
     * <p>与注册时同理：建表失败不回滚建群，首次发群消息时还会兜底再建。
     *
     * @param groupId 群 ID
     */
    private void ensureMessageShardTable(Long groupId) {
        try {
            if (!shardRouter.isShardEnabled()) {
                return;
            }
            shardSchemaService.ensureGroupTable(shardRouter, groupId);
        } catch (Exception e) {
            log.error("预建群消息分表失败，groupId={}（首次发群消息时会重试）", groupId, e);
        }
    }

    @Override
    @Transactional
    public Long createGroup(Long ownerId, String name, String avatar, Integer maxMembers, List<Long> memberIds) {
        ChatGroup group = new ChatGroup();
        group.setOwnerId(ownerId);
        group.setName(name);
        group.setAvatar(avatar);
        group.setMaxMembers(maxMembers != null ? maxMembers : 500);
        group.setDelFlag(0);
        group.setCreateTime(new Date());
        group.setUpdateTime(new Date());
        save(group);

        // 消息分表：建群即预建该群的群消息表，避免第一条群消息到来时才建表
        ensureMessageShardTable(group.getId());

        // 群主自动成为群成员（admin 角色）
        chatGroupMemberService.addMember(group.getId(), ownerId);

        // 添加初始成员
        Set<Long> allMemberIds = new LinkedHashSet<>();
        allMemberIds.add(ownerId);
        if (memberIds != null) {
            for (Long memberId : memberIds) {
                if (!memberId.equals(ownerId)) {
                    chatGroupMemberService.addMember(group.getId(), memberId);
                    allMemberIds.add(memberId);
                }
            }
        }

        // 获取群主昵称，用于系统消息
        String ownerName = getUserName(ownerId);

        // 给每个成员发送系统消息："xxx 已经加入了群"
        for (Long memberId : allMemberIds) {
            sendSystemMessage(memberId, group.getId(), ownerName + " 已经创建了群「" + name + "」");
        }

        // 给非群主的成员发送"xxx 已经加入了群"通知
        for (Long memberId : allMemberIds) {
            if (!memberId.equals(ownerId)) {
                String memberName = getUserName(memberId);
                // 广播给群内所有成员
                broadcastToGroup(group.getId(), memberName + " 已经加入了群");
            }
        }

        log.info("Group created: id={}, name={}, ownerId={}, members={}", group.getId(), name, ownerId, allMemberIds);
        return group.getId();
    }

    /**
     * 获取用户昵称
     */
    private String getUserName(Long userId) {
        try {
            // 直接传 Long：intValue() 会把超过 int 范围的用户 ID 截断成错误值，导致查无此人
            var user = chatUserService.getUserById(userId);
            if (user != null) {
                String nickname = user.getNickname();
                return (nickname != null && !nickname.isEmpty()) ? nickname : "用户" + userId;
            }
        } catch (Exception e) {
            log.warn("Failed to get user name for userId={}", userId, e);
        }
        return "用户" + userId;
    }

    /**
     * 发送系统消息给指定用户
     */
    private void sendSystemMessage(Long userId, Long groupId, String content) {
        try {
            ChatMessage message = new ChatMessage();
            message.setFromUserId(0L); // 系统消息，fromUserId 为 0
            message.setGroupId(groupId);
            message.setType("system");
            message.setContent(content);
            message.setStatus(0);
            message.setCreateTime(new Date());
            chatMessageService.saveMessage(message); // 走分表：save() 会写进 chat_message 主表

            // 通过 MQTT 推送给用户
            Map<String, Object> data = new HashMap<>();
            data.put("id", message.getId());
            data.put("fromUserId", 0);
            data.put("groupId", groupId);
            data.put("type", "system");
            data.put("content", content);
            data.put("createTime", message.getCreateTime());

            mqttPushService.publish(MqttTopics.user(userId), WsCmd.MSG_PUSH, data);
        } catch (Exception e) {
            log.error("Failed to send system message to userId={}, groupId={}", userId, groupId, e);
        }
    }

    /**
     * 广播系统消息给群内所有成员
     */
    private void broadcastToGroup(Long groupId, String content) {
        try {
            ChatMessage message = new ChatMessage();
            message.setFromUserId(0L);
            message.setGroupId(groupId);
            message.setType("system");
            message.setContent(content);
            message.setStatus(0);
            message.setCreateTime(new Date());
            chatMessageService.saveMessage(message); // 走分表：save() 会写进 chat_message 主表

            // 通过 MQTT 广播到群主题
            Map<String, Object> data = new HashMap<>();
            data.put("id", message.getId());
            data.put("fromUserId", 0);
            data.put("groupId", groupId);
            data.put("type", "system");
            data.put("content", content);
            data.put("createTime", message.getCreateTime());

            mqttPushService.publish(MqttTopics.group(groupId), WsCmd.MSG_PUSH, data);
        } catch (Exception e) {
            log.error("Failed to broadcast system message to groupId={}", groupId, e);
        }
    }
}
