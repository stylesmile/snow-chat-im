package com.stylesmile.chat.service.impl;

import com.stylesmile.common.service.BaseServiceImpl;
import com.stylesmile.chat.entity.ChatMessage;
import com.stylesmile.chat.mapper.ChatMessageMapper;
import com.stylesmile.chat.mqtt.MqttPushService;
import com.stylesmile.chat.mqtt.MqttTopics;
import com.stylesmile.chat.service.ChatMessageService;
import org.springframework.stereotype.Service;

import javax.annotation.Resource;

import java.util.Date;
import java.util.List;

/**
 * 消息服务实现
 *
 * @author chenye
 * @date 2018/12/10
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
    public void sendMessage(ChatMessage message) {
        message.setCreateTime(new Date());
        message.setStatus(0);
        save(message);
        publishMessage(message);
    }

    private void publishMessage(ChatMessage message) {
        java.util.Map<String, Object> data = new java.util.HashMap<>();
        data.put("id", message.getId());
        data.put("fromUserId", message.getFromUserId());
        data.put("toUserId", message.getToUserId());
        data.put("groupId", message.getGroupId());
        data.put("type", message.getType());
        data.put("content", message.getContent());
        data.put("localSeq", message.getLocalSeq());
        data.put("createTime", message.getCreateTime());

        if (message.getGroupId() != null) {
            mqttPushService.publish(MqttTopics.group(message.getGroupId()), 2001, data);
        } else if (message.getToUserId() != null) {
            mqttPushService.publish(MqttTopics.user(message.getToUserId()), 2001, data);
        }
    }

    @Override
    public void recallMessage(Integer userId, Long messageId) {
        ChatMessage message = getById(messageId);
        if (message != null && message.getFromUserId().equals(userId)) {
            message.setContent("[消息已撤回]");
            message.setType("recall");
            updateById(message);
        }
    }

    @Override
    public void markAsRead(Integer userId, Integer targetId, String targetType) {
        lambdaUpdate()
                .eq(ChatMessage::getToUserId, userId)
                .apply("({} = 'friend' AND {} = to_user_id) OR ({} = 'group' AND {} = group_id)",
                        targetType, targetId, targetType, targetId)
                .set(ChatMessage::getStatus, 1)
                .update();
    }
}
