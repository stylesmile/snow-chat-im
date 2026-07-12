package com.stylesmile.chat.service;

import com.stylesmile.common.service.BaseService;
import com.stylesmile.chat.entity.ChatFriendRequest;

import java.util.List;

/**
 * 好友请求服务
 *
 * @author chenye
 * @date 2018/12/10
 */
public interface ChatFriendRequestService extends BaseService<ChatFriendRequest> {

    /**
     * 查询待处理的好友请求
     *
     * @param toUserId 接收人ID
     * @return 好友请求列表
     */
    List<ChatFriendRequest> getPendingRequests(Integer toUserId);

    /**
     * 发送好友请求
     *
     * @param fromUserId 发起人ID
     * @param toUserId   接收人ID
     * @param remark     备注
     */
    void sendRequest(Integer fromUserId, Integer toUserId, String remark);

    /**
     * 处理好友请求
     *
     * @param fromUserId 发起人ID
     * @param toUserId   接收人ID
     * @param accept     是否同意
     */
    void handleRequest(Integer fromUserId, Integer toUserId, boolean accept);
}
