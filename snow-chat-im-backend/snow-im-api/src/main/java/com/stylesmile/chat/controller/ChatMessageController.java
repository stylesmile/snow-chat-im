package com.stylesmile.chat.controller;

import com.fasterxml.jackson.annotation.JsonAlias;
import com.stylesmile.chat.dto.ReadMessageDTO;
import com.stylesmile.chat.dto.RecallMessageDTO;
import com.stylesmile.chat.dto.SendMessageDTO;
import com.stylesmile.common.util.Result;
import com.stylesmile.chat.entity.ChatMessage;
import com.stylesmile.chat.service.ChatMessageService;
import lombok.Data;
import lombok.Getter;
import lombok.Setter;
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

    /**
     * 接收方发送消息回执：确认收到消息
     */
    @PostMapping("/receipt")
    public Result<Void> receipt(@RequestBody ReceiptDTO body) {
        chatMessageService.processReceipt(body.getMessageId(), body.getUserId());
        return Result.success();
    }

    /**
     * 进入聊天页面时请求未推送成功的消息
     * 返回未送达消息列表，由客户端主动拉取并写入本地 SQLite
     */
    @PostMapping("/undelivered")
    public Result<List<ChatMessage>> undelivered(@RequestBody FetchUndeliveredDTO body) {
        List<ChatMessage> messages = chatMessageService.getUndeliveredMessages(
                body.getUserId(), body.getTargetId(), body.getTargetType());
        return Result.success(messages);
    }

    /**
     * MQTT 重连后请求服务器补推未送达消息
     * 与 /undelivered 区别：本接口由服务器通过 MQTT 主动推送给客户端（FETCH_UNDELIVERED_ACK），
     * 而非返回列表由客户端拉取。适用于 MQTT 重连场景，客户端通知服务器"我回来了，把漏掉的消息推给我"。
     */
    @PostMapping("/sync")
    public Result<Void> sync(@RequestBody FetchUndeliveredDTO body) {
        // 委托给 service：查询未送达消息并通过 MQTT 推送到 chat/user/{userId} 主题
        chatMessageService.fetchAndPushUndelivered(
                body.getUserId(), body.getTargetId(), body.getTargetType());
        return Result.success();
    }

    @Data
    public static class ReceiptDTO {
        private Long messageId;
        private Long userId;
        private Long targetId;
        private String targetType;
    }

    @Data
    public static class FetchUndeliveredDTO {
        private Long userId;
        private Long targetId;
        private String targetType;
    }
}
