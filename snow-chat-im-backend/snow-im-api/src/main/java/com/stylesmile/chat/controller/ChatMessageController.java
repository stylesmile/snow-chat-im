package com.stylesmile.chat.controller;

import com.fasterxml.jackson.annotation.JsonAlias;
import com.stylesmile.common.util.Result;
import com.stylesmile.chat.entity.ChatMessage;
import com.stylesmile.chat.service.ChatMessageService;
import org.springframework.web.bind.annotation.*;

import javax.annotation.Resource;
import java.util.List;

/**
 * 消息控制器
 */
@RestController
@RequestMapping("/chat/message")
public class ChatMessageController {

    @Resource
    private ChatMessageService chatMessageService;

    /**
     * 获取历史消息（分页）
     */
    @GetMapping("/history")
    public Result<List<ChatMessage>> history(@RequestParam Integer userId,
                                              @RequestParam Integer targetId,
                                              @RequestParam String targetType,
                                              @RequestParam(defaultValue = "1") Integer page,
                                              @RequestParam(defaultValue = "20") Integer size) {
        List<ChatMessage> messages = chatMessageService.getHistoryMessages(userId, targetId, targetType, page, size);
        return Result.success(messages);
    }

    /**
     * 获取历史消息（游标分页，用于滚动加载）
     */
    @GetMapping("/history/cursor")
    public Result<List<ChatMessage>> historyCursor(@RequestParam Integer userId,
                                                    @RequestParam Integer targetId,
                                                    @RequestParam String targetType,
                                                    @RequestParam(required = false) Integer beforeMessageId,
                                                    @RequestParam(defaultValue = "20") Integer size) {
        List<ChatMessage> messages = chatMessageService.getHistoryMessagesByCursor(userId, targetId, targetType, beforeMessageId, size);
        return Result.success(messages);
    }

    /**
     * 撤回消息
     */
    @PostMapping("/recall")
    public Result<Void> recall(@RequestBody RecallMessageDTO body) {
        chatMessageService.recallMessage(body.getUserId(), body.getMessageId());
        return Result.success();
    }

    /**
     * 标记为已读
     */
    @PostMapping("/read")
    public Result<Void> markAsRead(@RequestBody ReadMessageDTO body) {
        chatMessageService.markAsRead(body.getUserId(), body.getTargetId(), body.getTargetType());
        return Result.success();
    }

    /**
     * 发送消息（REST fallback）
     */
    @PostMapping("/send")
    public Result<Void> send(@RequestBody SendMessageDTO body) {
        if (body.getFromUserId() == null || (body.getToUserId() == null && body.getGroupId() == null)) {
            return Result.failMessage("发送人、接收人或群组ID不能为空");
        }
        ChatMessage message = new ChatMessage();
        message.setFromUserId(body.getFromUserId());
        message.setToUserId(body.getToUserId());
        message.setGroupId(body.getGroupId());
        message.setType(body.getType());
        message.setContent(body.getContent());
        message.setLocalSeq(body.getLocalSeq());
        chatMessageService.sendMessage(message);
        return Result.success();
    }

    public static class RecallMessageDTO {
        private Integer userId;
        private Long messageId;
        public Integer getUserId() { return userId; }
        public void setUserId(Integer userId) { this.userId = userId; }
        public Long getMessageId() { return messageId; }
        public void setMessageId(Long messageId) { this.messageId = messageId; }
    }

    public static class ReadMessageDTO {
        private Integer userId;
        private Integer targetId;
        private String targetType;
        public Integer getUserId() { return userId; }
        public void setUserId(Integer userId) { this.userId = userId; }
        public Integer getTargetId() { return targetId; }
        public void setTargetId(Integer targetId) { this.targetId = targetId; }
        public String getTargetType() { return targetType; }
        public void setTargetType(String targetType) { this.targetType = targetType; }
    }

    public static class SendMessageDTO {
        @JsonAlias({"fromUserId", "from_user_id"})
        private Integer fromUserId;
        @JsonAlias({"toUserId", "to_user_id"})
        private Integer toUserId;
        @JsonAlias({"groupId", "group_id"})
        private Integer groupId;
        @JsonAlias({"type", "msgType"})
        private String type;
        @JsonAlias({"content"})
        private String content;
        @JsonAlias({"localSeq", "local_seq"})
        private Integer localSeq;
        public Integer getFromUserId() { return fromUserId; }
        public void setFromUserId(Integer fromUserId) { this.fromUserId = fromUserId; }
        public Integer getToUserId() { return toUserId; }
        public void setToUserId(Integer toUserId) { this.toUserId = toUserId; }
        public Integer getGroupId() { return groupId; }
        public void setGroupId(Integer groupId) { this.groupId = groupId; }
        public String getType() { return type; }
        public void setType(String type) { this.type = type; }
        public String getContent() { return content; }
        public void setContent(String content) { this.content = content; }
        public Integer getLocalSeq() { return localSeq; }
        public void setLocalSeq(Integer localSeq) { this.localSeq = localSeq; }
    }
}
