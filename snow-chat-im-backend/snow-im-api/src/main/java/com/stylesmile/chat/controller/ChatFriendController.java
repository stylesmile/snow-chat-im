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
 *
 * @author chenye
 * @date 2018/12/10
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
     *
     * @param userId 用户ID
     * @return Result
     */
    @GetMapping("/list")
    public Result<List<ChatFriend>> list(@RequestParam Integer userId) {
        List<ChatFriend> friends = chatFriendService.getFriendsByUserId(userId);
        return Result.success(friends);
    }

    /**
     * 发送好友请求
     *
     * @param fromUserId 发起人ID
     * @param toUserId   接收人ID
     * @param remark     备注
     * @return Result
     */
    @PostMapping("/request")
    public Result<Void> request(@RequestBody FriendRequestDTO dto) {
        chatFriendRequestService.sendRequest(dto.getFromUserId(), dto.getToUserId(), dto.getRemark());
        return Result.success();
    }

    /**
     * 处理好友请求
     *
     * @param fromUserId 发起人ID
     * @param toUserId   接收人ID
     * @param accept     是否同意
     * @return Result
     */
    @PostMapping("/handle")
    public Result<Void> handle(@RequestBody FriendHandleDTO dto) {
        chatFriendRequestService.handleRequest(dto.getFromUserId(), dto.getToUserId(), dto.getAccept());
        return Result.success();
    }

    /**
     * 获取待处理的好友请求
     *
     * @param toUserId 接收人ID
     * @return Result
     */
    @GetMapping("/pending")
    public Result<List<ChatFriendRequest>> pending(@RequestParam Integer toUserId) {
        List<ChatFriendRequest> requests = chatFriendRequestService.getPendingRequests(toUserId);
        return Result.success(requests);
    }

    /**
     * 删除好友
     *
     * @param userId   用户ID
     * @param friendId 好友ID
     * @return Result
     */
    @DeleteMapping("/{userId}/{friendId}")
    public Result<Void> delete(@PathVariable Integer userId, @PathVariable Integer friendId) {
        chatFriendService.remove(
                new com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper<ChatFriend>()
                        .eq(ChatFriend::getUserId, userId)
                        .eq(ChatFriend::getFriendId, friendId)
        );
        chatFriendService.remove(
                new com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper<ChatFriend>()
                        .eq(ChatFriend::getUserId, friendId)
                        .eq(ChatFriend::getFriendId, userId)
        );
        return Result.success();
    }

    /**
     * 好友请求DTO
     */
    public static class FriendRequestDTO {
        private Integer fromUserId;
        private Integer toUserId;
        private String remark;

        public Integer getFromUserId() {
            return fromUserId;
        }

        public void setFromUserId(Integer fromUserId) {
            this.fromUserId = fromUserId;
        }

        public Integer getToUserId() {
            return toUserId;
        }

        public void setToUserId(Integer toUserId) {
            this.toUserId = toUserId;
        }

        public String getRemark() {
            return remark;
        }

        public void setRemark(String remark) {
            this.remark = remark;
        }
    }

    /**
     * 好友请求处理DTO
     */
    public static class FriendHandleDTO {
        private Integer fromUserId;
        private Integer toUserId;
        private Boolean accept;

        public Integer getFromUserId() {
            return fromUserId;
        }

        public void setFromUserId(Integer fromUserId) {
            this.fromUserId = fromUserId;
        }

        public Integer getToUserId() {
            return toUserId;
        }

        public void setToUserId(Integer toUserId) {
            this.toUserId = toUserId;
        }

        public Boolean getAccept() {
            return accept;
        }

        public void setAccept(Boolean accept) {
            this.accept = accept;
        }
    }
}
