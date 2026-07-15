package com.stylesmile.chat.service.impl;

import com.stylesmile.common.service.BaseServiceImpl;
import com.stylesmile.chat.entity.ChatFriend;
import com.stylesmile.chat.mapper.ChatFriendMapper;
import com.stylesmile.chat.service.ChatFriendService;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

/**
 * 好友服务实现
 */
@Service
public class ChatFriendServiceImpl extends BaseServiceImpl<ChatFriendMapper, ChatFriend> implements ChatFriendService {

    @Override
    public List<ChatFriend> getFriendsByUserId(Integer userId) {
        return baseMapper.getFriendsByUserId(userId);
    }

    @Override
    public ChatFriend getFriend(Integer userId, Integer friendId) {
        return baseMapper.getFriend(userId, friendId);
    }

    @Override
    public boolean isFriend(Integer userId, Integer friendId) {
        return getFriend(userId, friendId) != null;
    }

    @Override
    @Transactional
    public void addFriend(Integer userId, Integer friendId) {
        // 避免重复添加
        if (isFriend(userId, friendId)) {
            return;
        }
        ChatFriend chatFriend = new ChatFriend();
        chatFriend.setUserId(userId);
        chatFriend.setFriendId(friendId);
        save(chatFriend);
    }

    @Override
    @Transactional
    public void removeFriend(Integer userId, Integer friendId) {
        // 双向删除好友关系
        remove(new com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper<ChatFriend>()
                .eq(ChatFriend::getUserId, userId)
                .eq(ChatFriend::getFriendId, friendId));
        remove(new com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper<ChatFriend>()
                .eq(ChatFriend::getUserId, friendId)
                .eq(ChatFriend::getFriendId, userId));
    }
}
