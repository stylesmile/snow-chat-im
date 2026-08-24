package com.stylesmile.chat.entity;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Data;

/**
 * 消息实体类
 */
@Data
@Schema(description = "消息实体")
public class ChatMessage {
    @Schema(description = "主键ID")
    private Long id;
    @Schema(description = "发送人ID")
    private Long fromUserId;
    @Schema(description = "接收人ID")
    private Long toUserId;
    @Schema(description = "群组ID（群聊时有效）")
    private Long groupId;
    @Schema(description = "消息类型：text/image/file/video/voice/emoji/self/recall", example = "text")
    private String type;
    @Schema(description = "消息内容")
    private String content;
    @Schema(description = "本地序列号，用于去重和排序")
    private Long localSeq;
    @Schema(description = "消息状态：0=未读, 1=已读", example = "0")
    private Integer status;
    @Schema(description = "推送状态：pending/server_received/client_ack/delivered", example = "server_received")
    private String pushStatus;
    @Schema(description = "创建时间")
    private java.util.Date createTime;

    public ChatMessage() {
    }
}
