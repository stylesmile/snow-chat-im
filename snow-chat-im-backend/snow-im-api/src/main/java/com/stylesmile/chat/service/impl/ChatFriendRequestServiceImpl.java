package com.stylesmile.chat.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.stylesmile.chat.mapper.ChatFriendMapper;
import com.stylesmile.chat.mapper.ChatFriendRequestMapper;
import com.stylesmile.common.service.BaseServiceImpl;
import com.stylesmile.chat.entity.ChatFriend;
import com.stylesmile.chat.entity.ChatFriendRequest;
import com.stylesmile.chat.mqtt.MqttPushService;
import com.stylesmile.chat.mqtt.MqttTopics;
import com.stylesmile.chat.service.ChatFriendRequestService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import javax.annotation.Resource;
import java.util.*;

/**
 * 好友请求服务实现
 */
@Service
public class ChatFriendRequestServiceImpl extends BaseServiceImpl<ChatFriendRequestMapper, ChatFriendRequest> implements ChatFriendRequestService {

    private static final Logger log = LoggerFactory.getLogger(ChatFriendRequestServiceImpl.class);

    @Resource
    private ChatFriendRequestMapper chatFriendRequestMapper;

    @Resource
    private MqttPushService mqttPushService;
    @Resource
    private ChatFriendMapper chatFriendMapper;

    @Override
    public List<ChatFriendRequest> getPendingRequests(Integer toUserId) {
        return baseMapper.getPendingRequests(toUserId);
    }

    @Override
    public List<ChatFriendRequest> getSentRequests(Integer fromUserId) {
        return lambdaQuery()
                .eq(ChatFriendRequest::getFromUserId, fromUserId)
                .eq(ChatFriendRequest::getStatus, "pending")
                .orderByDesc(ChatFriendRequest::getCreateTime)
                .list();
    }

    @Override
    @Transactional
    public void sendRequest(Integer fromUserId, Integer toUserId, String remark) {
        // 不能向自己发送请求
        if (fromUserId.equals(toUserId)) {
            throw new IllegalArgumentException("Cannot send friend request to yourself");
        }

        // 检查是否已经发送过 pending 请求
        ChatFriendRequest existing = lambdaQuery()
                .eq(ChatFriendRequest::getFromUserId, fromUserId)
                .eq(ChatFriendRequest::getToUserId, toUserId)
                .eq(ChatFriendRequest::getStatus, "pending")
                .one();
        if (existing != null) {
            throw new IllegalArgumentException("Friend request already sent");
        }

        // 检查对方是否已经发送过请求给自己（双向请求，直接变成好友）
        ChatFriendRequest reverse = lambdaQuery()
                .eq(ChatFriendRequest::getFromUserId, toUserId)
                .eq(ChatFriendRequest::getToUserId, fromUserId)
                .eq(ChatFriendRequest::getStatus, "pending")
                .one();

        if (reverse != null) {
            // 双向请求：标记原请求为 accepted，然后建立好友关系
            reverse.setStatus("accepted");
            updateById(reverse);

            // 创建双向好友关系
            ChatFriend f1 = new ChatFriend();
            f1.setUserId(fromUserId);
            f1.setFriendId(toUserId);
            f1.setCreateTime(new Date());
            chatFriendMapper.insert(f1);

            ChatFriend f2 = new ChatFriend();
            f2.setUserId(toUserId);
            f2.setFriendId(fromUserId);
            f2.setCreateTime(new Date());
            chatFriendMapper.insert(f2);

            // 也保存新请求
            ChatFriendRequest request = new ChatFriendRequest();
            request.setFromUserId(fromUserId);
            request.setToUserId(toUserId);
            request.setStatus("accepted");
            request.setRemark(remark);
            request.setCreateTime(new Date());
            save(request);
            return;
        }

        // 正常发送好友请求
        ChatFriendRequest request = new ChatFriendRequest();
        request.setFromUserId(fromUserId);
        request.setToUserId(toUserId);
        request.setStatus("pending");
        request.setRemark(remark);
        request.setCreateTime(new Date());
        save(request);

        // 通过MQTT通知接收方有新的好友请求
        try {
            Map<String, Object> data = new HashMap<>();
            data.put("fromUserId", fromUserId);
            data.put("toUserId", toUserId);
            data.put("remark", remark);
            mqttPushService.publish(MqttTopics.user(toUserId), 2002, data);
        } catch (Exception e) {
            log.warn("Failed to publish friend request notification via MQTT", e);
        }
    }

    @Override
    @Transactional
    public void handleRequest(Integer fromUserId, Integer toUserId, boolean accept) {
        ChatFriendRequest request = lambdaQuery()
                .eq(ChatFriendRequest::getFromUserId, fromUserId)
                .eq(ChatFriendRequest::getToUserId, toUserId)
                .eq(ChatFriendRequest::getStatus, "pending")
                .one();
        if (request == null) {
            return;
        }

        request.setStatus(accept ? "accepted" : "rejected");
        updateById(request);

        if (accept) {
            // 双向好友关系
            ChatFriend f1 = new ChatFriend();
            f1.setUserId(fromUserId);
            f1.setFriendId(toUserId);
            f1.setCreateTime(new Date());
            chatFriendMapper.insert(f1);


            ChatFriend f2 = new ChatFriend();
            f2.setUserId(toUserId);
            f2.setFriendId(fromUserId);
            f2.setCreateTime(new Date());
            chatFriendMapper.insert(f2);

        }
    }
}
