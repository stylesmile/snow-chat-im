package com.stylesmile.chat.service;

import com.stylesmile.common.service.BaseService;
import com.stylesmile.chat.entity.ChatFriendRequest;

import java.util.List;

/**
 * 好友请求服务
 */
public interface ChatFriendRequestService extends BaseService<ChatFriendRequest> {

    /**
     * 查询待处理的好友请求（接收到的）
     */
    List<ChatFriendRequest> getPendingRequests(Integer toUserId);

    /**
     * 查询已发送的待处理请求
     */
    List<ChatFriendRequest> getSentRequests(Integer fromUserId);

    /**
     * 发送好友请求
     */
    void sendRequest(Integer fromUserId, Integer toUserId, String remark);

    /**
     * 处理好友请求
     */
    void handleRequest(Integer fromUserId, Integer toUserId, boolean accept);
}
