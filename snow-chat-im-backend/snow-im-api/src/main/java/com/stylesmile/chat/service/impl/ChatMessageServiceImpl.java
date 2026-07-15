package com.stylesmile.chat.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.conditions.update.LambdaUpdateWrapper;
import com.stylesmile.common.service.BaseServiceImpl;
import com.stylesmile.chat.entity.ChatMessage;
import com.stylesmile.chat.mapper.ChatMessageMapper;
import com.stylesmile.chat.mqtt.MqttPushService;
import com.stylesmile.chat.mqtt.MqttTopics;
import com.stylesmile.chat.service.ChatMessageService;
import org.springframework.stereotype.Service;

import javax.annotation.Resource;
import java.util.*;

/**
 * 消息服务实现
 */
@Service
public class ChatMessageServiceImpl extends BaseServiceImpl<ChatMessageMapper, ChatMessage> implements ChatMessageService {

    @Resource
    private MqttPushService mqttPushService;

    @Override
    public List<ChatMessage> getHistoryMessages(Integer userId, Integer targetId, String targetType, int page, int size) {
        return baseMapper.getHistoryMessages(userId, targetId, targetType, page, size);
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
    public void sendMessage(ChatMessage message) {
        message.setCreateTime(new Date());
        message.setStatus(0);
        save(message);
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
        } else if (message.getToUserId() != null) {
            // 私聊消息：推送给接收方
            mqttPushService.publish(MqttTopics.user(message.getToUserId()), 2001, data);
            // 同时也推送给发送方（回显，确认发送成功）
            if (!message.getFromUserId().equals(message.getToUserId())) {
                mqttPushService.publish(MqttTopics.user(message.getFromUserId()), 2001, data);
            }
        }
    }

    @Override
    public void recallMessage(Integer userId, Long messageId) {
        ChatMessage message = getById(messageId);
        if (message != null && message.getFromUserId().equals(userId)) {
            message.setContent("[消息已撤回]");
            message.setType("recall");
            updateById(message);

            // 通过MQTT广播撤回消息
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
                mqttPushService.publish(MqttTopics.user(message.getToUserId()), 2006, data);
                mqttPushService.publish(MqttTopics.user(userId), 2006, data);
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
