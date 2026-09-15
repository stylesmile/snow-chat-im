package com.stylesmile.chat.controller;

import com.stylesmile.common.util.Result;
import com.stylesmile.chat.entity.ChatSession;
import com.stylesmile.chat.service.ChatSessionService;
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
 * 会话控制器
 */
@RestController
@RequestMapping("/chat/session")
@Tag(name = "会话管理", description = "会话列表、未读数清除接口")
public class ChatSessionController {

    @Resource
    private ChatSessionService chatSessionService;

    /**
     * 获取会话列表
     */
    @Operation(summary = "获取会话列表", description = "获取指定用户的所有会话列表（私聊+群聊）")
    @ApiResponse(responseCode = "200", description = "查询成功")
    @GetMapping("/list")
    public Result<List<ChatSession>> list(
            @Parameter(description = "用户ID", required = true) @RequestParam Long userId) {
        List<ChatSession> sessions = chatSessionService.getSessionsByUserId(userId);
        return Result.success(sessions);
    }

    /**
     * 清除未读数
     */
    @Operation(summary = "清除未读数", description = "清除指定会话的未读消息数")
    @ApiResponse(responseCode = "200", description = "清除成功")
    @PostMapping("/unread/clear")
    public Result<Void> clearUnread(@RequestBody ClearUnreadDTO body) {
        chatSessionService.clearUnreadCount(body.getUserId(), body.getTargetId());
        return Result.success();
    }

    @Data
    @Schema(description = "清除未读数请求DTO")
    public static class ClearUnreadDTO {
        @Schema(description = "用户ID", example = "1")
        private Long userId;
        @Schema(description = "目标ID（好友ID或群组ID）", example = "2")
        private Long targetId;
    }
}
