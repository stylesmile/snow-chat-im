package com.stylesmile.chat.controller;

import com.stylesmile.common.util.Result;
import com.stylesmile.chat.entity.ChatMessage;
import com.stylesmile.chat.service.ChatMessageService;
import org.springframework.web.bind.annotation.*;

import javax.annotation.Resource;
import java.util.List;

/**
 * 消息控制器
 *
 * @author chenye
 * @date 2018/12/10
 */
@RestController
@RequestMapping("/chat/message")
public class ChatMessageController {

    @Resource
    private ChatMessageService chatMessageService;

    /**
     * 获取历史消息
     *
     * @param userId     用户ID
     * @param targetId   目标ID
     * @param targetType 目标类型
     * @param page       页码
     * @param size       每页大小
     * @return Result
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
     * 撤回消息
     *
     * @param body 包含userId和messageId
     * @return Result
     */
    @PostMapping("/recall")
    public Result<Void> recall(@RequestBody RecallMessageDTO body) {
        chatMessageService.recallMessage(body.getUserId(), body.getMessageId());
        return Result.success();
    }

    /**
     * 标记为已读
     *
     * @param body 包含userId, targetId, targetType
     * @return Result
     */
    @PostMapping("/read")
    public Result<Void> markAsRead(@RequestBody ReadMessageDTO body) {
        chatMessageService.markAsRead(body.getUserId(), body.getTargetId(), body.getTargetType());
        return Result.success();
    }

    /**
     * 发送消息（REST fallback）
     *
     * @param body 包含fromUserId, toUserId, groupId, type, content
     * @return Result
     */
    @PostMapping("/send")
    public Result<Void> send(@RequestBody SendMessageDTO body) {
        ChatMessage message = new ChatMessage();
        message.setFromUserId(body.getFromUserId());
        message.setToUserId(body.getToUserId());
        message.setGroupId(body.getGroupId());
        message.setType(body.getType());
        message.setContent(body.getContent());
        chatMessageService.sendMessage(message);
        return Result.success();
    }

    /**
     * 撤回消息DTO
     */
    public static class RecallMessageDTO {
        private Integer userId;
        private Long messageId;

        public Integer getUserId() {
            return userId;
        }

        public void setUserId(Integer userId) {
            this.userId = userId;
        }

        public Long getMessageId() {
            return messageId;
        }

        public void setMessageId(Long messageId) {
            this.messageId = messageId;
        }
    }

    /**
     * 已读消息DTO
     */
    public static class ReadMessageDTO {
        private Integer userId;
        private Integer targetId;
        private String targetType;

        public Integer getUserId() {
            return userId;
        }

        public void setUserId(Integer userId) {
            this.userId = userId;
        }

        public Integer getTargetId() {
            return targetId;
        }

        public void setTargetId(Integer targetId) {
            this.targetId = targetId;
        }

        public String getTargetType() {
            return targetType;
        }

        public void setTargetType(String targetType) {
            this.targetType = targetType;
        }
    }

    /**
     * 发送消息DTO
     */
    public static class SendMessageDTO {
        private Integer fromUserId;
        private Integer toUserId;
        private Integer groupId;
        private String type;
        private String content;

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

        public Integer getGroupId() {
            return groupId;
        }

        public void setGroupId(Integer groupId) {
            this.groupId = groupId;
        }

        public String getType() {
            return type;
        }

        public void setType(String type) {
            this.type = type;
        }

        public String getContent() {
            return content;
        }

        public void setContent(String content) {
            this.content = content;
        }
    }
}
