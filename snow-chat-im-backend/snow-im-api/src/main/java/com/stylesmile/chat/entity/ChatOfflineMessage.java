package com.stylesmile.chat.entity;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Getter;
import lombok.Setter;

import java.util.Date;

/**
 * 离线消息实体类
 */
@Setter
@Getter
@Schema(description = "离线消息实体")
public class ChatOfflineMessage {
    @Schema(description = "主键ID")
    private Long id;
    @Schema(description = "接收者用户ID")
    private Long toUserId;
    @Schema(description = "MQTT主题", example = "chat/user/1001")
    private String topic;
    @Schema(description = "消息命令类型")
    private Integer cmd;
    @Schema(description = "消息体JSON")
    private String payload;
    @Schema(description = "创建时间")
    private Date createTime;
}
