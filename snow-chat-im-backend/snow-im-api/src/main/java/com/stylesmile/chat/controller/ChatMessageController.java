package com.stylesmile.chat.controller;

import com.fasterxml.jackson.annotation.JsonAlias;
import com.stylesmile.chat.dto.ReadMessageDTO;
import com.stylesmile.chat.dto.RecallMessageDTO;
import com.stylesmile.chat.dto.SendMessageDTO;
import com.stylesmile.common.util.Result;
import com.stylesmile.chat.entity.ChatMessage;
import com.stylesmile.chat.service.ChatMessageService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Data;
import lombok.Getter;
import lombok.Setter;
import org.springframework.web.bind.annotation.*;

import javax.annotation.Resource;
import java.util.List;
import java.util.Set;

/**
 * 消息控制器 - 消息发送、历史消息、已读回执、撤回
 */
@RestController
@RequestMapping("/chat/message")
@Tag(name = "消息管理", description = "消息发送、历史消息查询、已读回执、消息撤回接口")
public class ChatMessageController {

    /**
     * 消息类型白名单：text / image / video / file / voice / emoji / self / recall。
     * 用于 {@link #send} 端点的 type 字段校验，防止任意字符串写入消息表。
     */
    private static final Set<String> ALLOWED_MESSAGE_TYPES = Set.of(
            "text", "image", "video", "file", "voice", "emoji", "self", "recall"
    );

    @Resource
    private ChatMessageService chatMessageService;

    /**
     * 获取历史消息（分页）
     */
    @Operation(summary = "获取历史消息（分页）", description = "根据userId、targetId、targetType分页获取历史消息")
    @ApiResponse(responseCode = "200", description = "查询成功")
    @GetMapping("/history")
    public Result<List<ChatMessage>> history(
            @Parameter(description = "用户ID", required = true) @RequestParam Long userId,
            @Parameter(description = "目标ID（好友ID或群组ID）", required = true) @RequestParam Long targetId,
            @Parameter(description = "目标类型：friend/group/file_helper", required = true) @RequestParam String targetType,
            @Parameter(description = "页码，从1开始", example = "1") @RequestParam(defaultValue = "1") Integer page,
            @Parameter(description = "每页条数", example = "20") @RequestParam(defaultValue = "20") Integer size) {
        List<ChatMessage> messages = chatMessageService.getHistoryMessages(userId, targetId, targetType, page, size);
        return Result.success(messages);
    }

    /**
     * 获取历史消息（游标分页，用于滚动加载）
     */
    @Operation(summary = "获取历史消息（游标分页）", description = "基于beforeMessageId游标分页，适用于滚动加载")
    @ApiResponse(responseCode = "200", description = "查询成功")
    @GetMapping("/history/cursor")
    public Result<List<ChatMessage>> historyCursor(
            @Parameter(description = "用户ID", required = true) @RequestParam Long userId,
            @Parameter(description = "目标ID", required = true) @RequestParam Long targetId,
            @Parameter(description = "目标类型：friend/group/file_helper", required = true) @RequestParam String targetType,
            @Parameter(description = "上一页最后一条消息ID，用于游标分页") @RequestParam(required = false) Long beforeMessageId,
            @Parameter(description = "每页条数", example = "20") @RequestParam(defaultValue = "20") Integer size) {
        List<ChatMessage> messages = chatMessageService.getHistoryMessagesByCursor(userId, targetId, targetType, beforeMessageId, size);
        return Result.success(messages);
    }

    /**
     * 发送文件传输助手消息（发送给自己，接收人=自己）
     */
    @Operation(summary = "发送文件传输助手消息", description = "发送给自己，接收人=自己，用于文件传输助手场景")
    @ApiResponse(responseCode = "200", description = "发送成功")
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
    @Operation(summary = "撤回消息", description = "撤回指定消息，发送后2分钟内可撤回")
    @ApiResponse(responseCode = "200", description = "撤回成功")
    @ApiResponse(responseCode = "400", description = "超出撤回时限或非本人消息")
    @PostMapping("/recall")
    public Result<Void> recall(@RequestBody RecallMessageDTO body) {
        chatMessageService.recallMessage(body.getUserId(), body.getMessageId());
        return Result.success();
    }

    /**
     * 标记为已读
     */
    @Operation(summary = "标记为已读", description = "标记消息或会话为已读状态")
    @ApiResponse(responseCode = "200", description = "标记成功")
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
     */
    @Operation(summary = "发送消息", description = "发送消息（REST fallback），type白名单校验：text/image/video/file/voice/emoji/self/recall")
    @ApiResponse(responseCode = "200", description = "发送成功")
    @ApiResponse(responseCode = "400", description = "参数缺失或type非法")
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
    @Operation(summary = "发送消息回执", description = "接收方确认收到消息")
    @ApiResponse(responseCode = "200", description = "回执成功")
    @PostMapping("/receipt")
    public Result<Void> receipt(@RequestBody ReceiptDTO body) {
        chatMessageService.processReceipt(body.getMessageId(), body.getUserId());
        return Result.success();
    }

    /**
     * 进入聊天页面时请求未推送成功的消息
     */
    @Operation(summary = "获取未送达消息", description = "进入聊天页面时请求未推送成功的消息列表")
    @ApiResponse(responseCode = "200", description = "查询成功")
    @PostMapping("/undelivered")
    public Result<List<ChatMessage>> undelivered(@RequestBody FetchUndeliveredDTO body) {
        List<ChatMessage> messages = chatMessageService.getUndeliveredMessages(
                body.getUserId(), body.getTargetId(), body.getTargetType());
        return Result.success(messages);
    }

    /**
     * MQTT 重连后请求服务器补推未送达消息
     */
    @Operation(summary = "MQTT重连补推", description = "MQTT重连后请求服务器补推未送达消息（主动推送模式）")
    @ApiResponse(responseCode = "200", description = "补推请求已接受")
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
