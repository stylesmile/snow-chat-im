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
import java.util.Set;

/**
 * 消息控制器
 */
@RestController
@RequestMapping("/chat/message")
public class ChatMessageController {

    /**
     * 消息类型白名单：text / image / video / file / self / recall。
     * 用于 {@link #send} 端点的 type 字段校验，防止任意字符串写入消息表。
     */
    private static final Set<String> ALLOWED_MESSAGE_TYPES = Set.of(
            "text", "image", "video", "file", "self", "recall"
    );

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
     * 发送文件传输助手消息（发送给自己，接收人=自己）
     *
     * 文件传输助手本质是"发给自己的消息"：
     * - 接收人强制设为发送人自己，便于消息同步到本人的其他登录端
     * - 类型标记为 self，用于在后端各查询/分类中识别文件助手消息
     */
    @PostMapping("/send/file-helper")
    public Result<Void> sendFileHelper(@RequestBody SendMessageDTO body) {
        // 接收人改成自己（使消息能推送到本人 topic，同步到其他登录端）
        body.setToUserId(body.getFromUserId());
        ChatMessage message = new ChatMessage();
        message.setFromUserId(body.getFromUserId());
        message.setToUserId(body.getFromUserId()); // 接收人=自己
        message.setType("self");                   // 新增消息类型：self（文件传输助手）
        message.setContent(body.getContent());
        message.setLocalSeq(body.getLocalSeq());
        message.setStatus(0);
        message.setCreateTime(new java.util.Date());
        message.setPushStatus("server_received");
        chatMessageService.sendMessage(message);
        return Result.success();
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
     *
     * <p>白名单校验 type 字段，只允许以下值：
     * <ul>
     *   <li>{@code text}：纯文本；</li>
     *   <li>{@code image}：图片消息（content 为图片 URL）；</li>
     *   <li>{@code video}：视频消息（content 为视频 URL）；</li>
     *   <li>{@code file}：文件消息（content 为文件 URL + 文件名元数据）；</li>
     *   <li>{@code self}：文件传输助手（发送给自己，同步到其他登录端）；</li>
     *   <li>{@code recall}：已撤回消息。</li>
     * </ul>
     * 非法 type 直接返回 400，避免写入无意义或潜在危险的类型。
     */
    @PostMapping("/send")
    public Result<Void> send(@RequestBody SendMessageDTO body) {
        if (body.getFromUserId() == null || (body.getToUserId() == null && body.getGroupId() == null)) {
            return Result.failMessage("发送人、接收人或群组ID不能为空");
        }
        // 安全校验：type 必须在白名单内，防止任意字符串写入数据库并触发未预期的渲染逻辑
        if (!ALLOWED_MESSAGE_TYPES.contains(body.getType())) {
            return Result.failMessage(
                    "非法的消息类型 '" + body.getType() + "'，只允许 " + ALLOWED_MESSAGE_TYPES);
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
