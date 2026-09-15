package com.stylesmile.chat.entity;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Data;

import java.util.Date;

/**
 * 会话实体类
 */
@Data
@Schema(description = "会话实体")
public class ChatSession {
    @Schema(description = "会话主键ID")
    private Long id;
    @Schema(description = "用户ID")
    private Long userId;
    @Schema(description = "目标ID（好友ID或群组ID）")
    private Long targetId;
    @Schema(description = "目标类型：friend/group/file_helper", example = "friend")
    private String targetType;
    @Schema(description = "最后一条消息内容")
    private String lastMsg;
    @Schema(description = "最后一条消息时间")
    private Date lastMsgTime;
    @Schema(description = "未读消息数", example = "0")
    private Integer unreadCount;
    @Schema(description = "创建时间")
    private Date createTime;
    @Schema(description = "是否免打扰：0=关闭, 1=开启", example = "0")
    private Integer isMuted;
    @Schema(description = "更新时间")
    private Date updateTime;

    public ChatSession() {
    }
}
