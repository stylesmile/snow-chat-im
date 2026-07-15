package com.stylesmile.chat.service;

import com.stylesmile.common.service.BaseService;
import com.stylesmile.chat.entity.ChatFriend;

import java.util.List;

/**
 * 好友服务
 */
public interface ChatFriendService extends BaseService<ChatFriend> {

    /**
     * 查询用户的好友列表
     */
    List<ChatFriend> getFriendsByUserId(Integer userId);

    /**
     * 查询两个用户之间的好友关系
     */
    ChatFriend getFriend(Integer userId, Integer friendId);

    /**
     * 判断两个用户是否为好友
     */
    boolean isFriend(Integer userId, Integer friendId);

    /**
     * 添加好友（幂等）
     */
    void addFriend(Integer userId, Integer friendId);

    /**
     * 删除好友（双向删除）
     */
    void removeFriend(Integer userId, Integer friendId);
}
