package com.stylesmile.chat.controller;

import com.stylesmile.common.util.Result;
import com.stylesmile.chat.entity.ChatSession;
import com.stylesmile.chat.service.ChatSessionService;
import lombok.Data;
import org.springframework.web.bind.annotation.*;

import javax.annotation.Resource;
import java.util.List;

/**
 * 会话控制器
 *
 * @author chenye
 * @date 2018/12/10
 */
@RestController
@RequestMapping("/chat/session")
public class ChatSessionController {

    @Resource
    private ChatSessionService chatSessionService;

    /**
     * 获取会话列表
     *
     * @param userId 用户ID
     * @return Result
     */
    @GetMapping("/list")
    public Result<List<ChatSession>> list(@RequestParam Long userId) {
        List<ChatSession> sessions = chatSessionService.getSessionsByUserId(userId);
        return Result.success(sessions);
    }

    /**
     * 清除未读数
     *
     * @param body 包含userId和targetId
     * @return Result
     */
    @PostMapping("/unread/clear")
    public Result<Void> clearUnread(@RequestBody ClearUnreadDTO body) {
        chatSessionService.clearUnreadCount(body.getUserId(), body.getTargetId());
        return Result.success();
    }

    /**
     * 清除未读数DTO
     */
    @Data
    public static class ClearUnreadDTO {
        private Long userId;
        private Long targetId;
    }
}
