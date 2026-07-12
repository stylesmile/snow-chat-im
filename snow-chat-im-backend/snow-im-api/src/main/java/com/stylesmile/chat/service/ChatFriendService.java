package com.stylesmile.chat.service;

import com.stylesmile.common.service.BaseService;
import com.stylesmile.chat.entity.ChatFriend;

import java.util.List;

/**
 * 好友服务
 *
 * @author chenye
 * @date 2018/12/10
 */
public interface ChatFriendService extends BaseService<ChatFriend> {

    /**
     * 查询用户的好友列表
     *
     * @param userId 用户ID
     * @return 好友列表
     */
    List<ChatFriend> getFriendsByUserId(Integer userId);

    /**
     * 查询两个用户之间的好友关系
     *
     * @param userId   用户ID
     * @param friendId 好友ID
     * @return 好友关系
     */
    ChatFriend getFriend(Integer userId, Integer friendId);

    /**
     * 判断两个用户是否为好友
     *
     * @param userId   用户ID
     * @param friendId 好友ID
     * @return true-是好友, false-不是好友
     */
    boolean isFriend(Integer userId, Integer friendId);

    /**
     * 添加好友
     *
     * @param userId   用户ID
     * @param friendId 好友ID
     */
    void addFriend(Integer userId, Integer friendId);
}
