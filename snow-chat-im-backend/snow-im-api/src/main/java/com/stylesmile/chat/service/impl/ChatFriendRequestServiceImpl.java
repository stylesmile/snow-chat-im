package com.stylesmile.chat.service.impl;

import com.stylesmile.common.service.BaseServiceImpl;
import com.stylesmile.chat.entity.ChatFriendRequest;
import com.stylesmile.chat.mapper.ChatFriendRequestMapper;
import com.stylesmile.chat.service.ChatFriendRequestService;
import com.stylesmile.chat.service.ChatFriendService;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import javax.annotation.Resource;
import java.util.Date;
import java.util.List;

/**
 * 好友请求服务实现
 *
 * @author chenye
 * @date 2018/12/10
 */
@Service
public class ChatFriendRequestServiceImpl extends BaseServiceImpl<ChatFriendRequestMapper, ChatFriendRequest> implements ChatFriendRequestService {

    @Resource
    private ChatFriendRequestMapper chatFriendRequestMapper;

    @Resource
    private ChatFriendService chatFriendService;

    @Override
    public List<ChatFriendRequest> getPendingRequests(Integer toUserId) {
        return baseMapper.getPendingRequests(toUserId);
    }

    @Override
    @Transactional
    public void sendRequest(Integer fromUserId, Integer toUserId, String remark) {
        ChatFriendRequest request = new ChatFriendRequest();
        request.setFromUserId(fromUserId);
        request.setToUserId(toUserId);
        request.setStatus("pending");
        request.setRemark(remark);
        request.setCreateTime(new Date());
        save(request);
    }

    @Override
    @Transactional
    public void handleRequest(Integer fromUserId, Integer toUserId, boolean accept) {
        ChatFriendRequest request = lambdaQuery()
                .eq(ChatFriendRequest::getFromUserId, fromUserId)
                .eq(ChatFriendRequest::getToUserId, toUserId)
                .eq(ChatFriendRequest::getStatus, "pending")
                .one();
        if (request != null) {
            request.setStatus(accept ? "accepted" : "rejected");
            updateById(request);
        }
        if (accept) {
            chatFriendService.addFriend(fromUserId, toUserId);
        }
    }
}
