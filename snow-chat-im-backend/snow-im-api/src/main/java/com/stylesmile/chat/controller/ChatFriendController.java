package com.stylesmile.chat.controller;

import com.stylesmile.chat.dto.FriendRequestDTO;
import com.stylesmile.common.util.Result;
import com.stylesmile.chat.entity.ChatFriend;
import com.stylesmile.chat.entity.ChatFriendRequest;
import com.stylesmile.chat.service.ChatFriendRequestService;
import com.stylesmile.chat.service.ChatFriendService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Data;
import org.springframework.web.bind.annotation.*;

import javax.annotation.Resource;
import java.util.List;

/**
 * 好友控制器
 */
@RestController
@RequestMapping("/chat/friend")
@Tag(name = "好友管理", description = "好友列表、好友请求、删除好友接口")
public class ChatFriendController {

    @Resource
    private ChatFriendService chatFriendService;

    @Resource
    private ChatFriendRequestService chatFriendRequestService;

    /**
     * 获取好友列表
     */
    @Operation(summary = "获取好友列表", description = "根据用户ID获取好友列表")
    @ApiResponse(responseCode = "200", description = "查询成功")
    @GetMapping("/list")
    public Result<List<ChatFriend>> list(
            @Parameter(description = "用户ID", required = true) @RequestParam Long userId) {
        List<ChatFriend> friends = chatFriendService.getFriendsByUserId(userId);
        return Result.success(friends);
    }

    /**
     * 发送好友请求
     */
    @Operation(summary = "发送好友请求", description = "向指定用户发送好友请求")
    @ApiResponse(responseCode = "200", description = "请求发送成功")
    @ApiResponse(responseCode = "400", description = "参数错误")
    @PostMapping("/request")
    public Result<Void> request(
            @Parameter(description = "好友请求DTO，包含fromUserId, toUserId, remark")
            @RequestBody FriendRequestDTO dto) {
        chatFriendRequestService.sendRequest(dto.getFromUserId(), dto.getToUserId(), dto.getRemark());
        return Result.success();
    }

    /**
     * 处理好友请求
     */
    @Operation(summary = "处理好友请求", description = "接受或拒绝好友请求")
    @ApiResponse(responseCode = "200", description = "处理成功")
    @ApiResponse(responseCode = "400", description = "请求不存在或状态无效")
    @PostMapping("/handle")
    public Result<Void> handle(
            @Parameter(description = "好友处理DTO，包含fromUserId, toUserId, accept")
            @RequestBody FriendHandleDTO dto) {
        chatFriendRequestService.handleRequest(dto.getFromUserId(), dto.getToUserId(), dto.getAccept());
        return Result.success();
    }

    /**
     * 获取待处理的好友请求（接收到的）
     */
    @Operation(summary = "获取待处理好友请求", description = "获取当前用户收到的待处理好友请求列表")
    @ApiResponse(responseCode = "200", description = "查询成功")
    @GetMapping("/pending")
    public Result<List<ChatFriendRequest>> pending(
            @Parameter(description = "接收者用户ID", required = true) @RequestParam Long toUserId) {
        List<ChatFriendRequest> requests = chatFriendRequestService.getPendingRequests(toUserId);
        return Result.success(requests);
    }

    /**
     * 获取已发送的待处理请求
     */
    @Operation(summary = "获取已发送待处理请求", description = "获取当前用户发送的待处理好友请求列表")
    @ApiResponse(responseCode = "200", description = "查询成功")
    @GetMapping("/sent")
    public Result<List<ChatFriendRequest>> sent(
            @Parameter(description = "发起者用户ID", required = true) @RequestParam Long fromUserId) {
        List<ChatFriendRequest> requests = chatFriendRequestService.getSentRequests(fromUserId);
        return Result.success(requests);
    }

    /**
     * 删除好友（双向删除）
     */
    @Operation(summary = "删除好友", description = "双向删除好友关系")
    @ApiResponse(responseCode = "200", description = "删除成功")
    @DeleteMapping("/{userId}/{friendId}")
    public Result<Void> delete(
            @Parameter(description = "用户ID", required = true) @PathVariable Long userId,
            @Parameter(description = "好友ID", required = true) @PathVariable Long friendId) {
        chatFriendService.removeFriend(userId, friendId);
        return Result.success();
    }

    @Data
    @Schema(description = "好友请求处理DTO")
    public static class FriendHandleDTO {
        @Schema(description = "发起者用户ID")
        private Long fromUserId;
        @Schema(description = "接收者用户ID")
        private Long toUserId;
        @Schema(description = "是否接受：true=接受，false=拒绝")
        private Boolean accept;
    }
}
