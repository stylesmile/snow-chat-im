package com.stylesmile.chat.controller;

import com.stylesmile.common.util.Result;
import com.stylesmile.chat.entity.ChatFriend;
import com.stylesmile.chat.entity.ChatFriendRequest;
import com.stylesmile.chat.service.ChatFriendRequestService;
import com.stylesmile.chat.service.ChatFriendService;
import org.springframework.web.bind.annotation.*;

import javax.annotation.Resource;
import java.util.List;

/**
 * 好友控制器
 */
@RestController
@RequestMapping("/chat/friend")
public class ChatFriendController {

    @Resource
    private ChatFriendService chatFriendService;

    @Resource
    private ChatFriendRequestService chatFriendRequestService;

    /**
     * 获取好友列表
     */
    @GetMapping("/list")
    public Result<List<ChatFriend>> list(@RequestParam Integer userId) {
        List<ChatFriend> friends = chatFriendService.getFriendsByUserId(userId);
        return Result.success(friends);
    }

    /**
     * 发送好友请求
     */
    @PostMapping("/request")
    public Result<Void> request(@RequestBody FriendRequestDTO dto) {
        chatFriendRequestService.sendRequest(dto.getFromUserId(), dto.getToUserId(), dto.getRemark());
        return Result.success();
    }

    /**
     * 处理好友请求
     */
    @PostMapping("/handle")
    public Result<Void> handle(@RequestBody FriendHandleDTO dto) {
        chatFriendRequestService.handleRequest(dto.getFromUserId(), dto.getToUserId(), dto.getAccept());
        return Result.success();
    }

    /**
     * 获取待处理的好友请求（接收到的）
     */
    @GetMapping("/pending")
    public Result<List<ChatFriendRequest>> pending(@RequestParam Integer toUserId) {
        List<ChatFriendRequest> requests = chatFriendRequestService.getPendingRequests(toUserId);
        return Result.success(requests);
    }

    /**
     * 获取已发送的待处理请求
     */
    @GetMapping("/sent")
    public Result<List<ChatFriendRequest>> sent(@RequestParam Integer fromUserId) {
        List<ChatFriendRequest> requests = chatFriendRequestService.getSentRequests(fromUserId);
        return Result.success(requests);
    }

    /**
     * 删除好友（双向删除）
     */
    @DeleteMapping("/{userId}/{friendId}")
    public Result<Void> delete(@PathVariable Integer userId, @PathVariable Integer friendId) {
        chatFriendService.removeFriend(userId, friendId);
        return Result.success();
    }

    public static class FriendRequestDTO {
        private Integer fromUserId;
        private Integer toUserId;
        private String remark;

        public Integer getFromUserId() { return fromUserId; }
        public void setFromUserId(Integer fromUserId) { this.fromUserId = fromUserId; }
        public Integer getToUserId() { return toUserId; }
        public void setToUserId(Integer toUserId) { this.toUserId = toUserId; }
        public String getRemark() { return remark; }
        public void setRemark(String remark) { this.remark = remark; }
    }

    public static class FriendHandleDTO {
        private Integer fromUserId;
        private Integer toUserId;
        private Boolean accept;

        public Integer getFromUserId() { return fromUserId; }
        public void setFromUserId(Integer fromUserId) { this.fromUserId = fromUserId; }
        public Integer getToUserId() { return toUserId; }
        public void setToUserId(Integer toUserId) { this.toUserId = toUserId; }
        public Boolean getAccept() { return accept; }
        public void setAccept(Boolean accept) { this.accept = accept; }
    }
}
