package com.stylesmile.chat.entity;

import com.fasterxml.jackson.annotation.JsonProperty;
import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Data;

/**
 * 好友实体类
 */
@Data
@Schema(description = "好友实体")
public class ChatFriend {
    @Schema(description = "主键ID")
    private Long id;
    @Schema(description = "用户ID")
    private Long userId;
    @Schema(description = "好友ID")
    @JsonProperty("friendId")
    private Long friendId;
    @Schema(description = "备注")
    private String remark;
    @Schema(description = "创建时间")
    private java.util.Date createTime;
    @Schema(description = "好友昵称（JOIN查询）")
    @JsonProperty("nickname")
    private String nickname;
    @Schema(description = "好友头像（JOIN查询）")
    @JsonProperty("avatar")
    private String avatar;
    @Schema(description = "好友在线状态（JOIN查询）")
    @JsonProperty("status")
    private String status;

    public ChatFriend() {
    }
}
