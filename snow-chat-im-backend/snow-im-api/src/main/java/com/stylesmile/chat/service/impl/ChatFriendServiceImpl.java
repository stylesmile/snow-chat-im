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
 *
 * @author chenye
 * @date 2018/12/10
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
        ChatFriend chatFriend = new ChatFriend();
        chatFriend.setUserId(userId);
        chatFriend.setFriendId(friendId);
        save(chatFriend);
    }
}
