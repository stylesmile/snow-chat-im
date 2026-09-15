package com.stylesmile.chat.entity;

import com.baomidou.mybatisplus.annotation.TableField;
import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Data;

/**
 * 好友请求实体类
 */
@Data
@Schema(description = "好友请求实体")
public class ChatFriendRequest {
    @Schema(description = "主键ID")
    private Long id;
    @Schema(description = "发起人ID")
    private Long fromUserId;
    @Schema(description = "接收人ID")
    private Long toUserId;
    @Schema(description = "状态：pending/accepted/rejected", example = "pending")
    private String status;
    @Schema(description = "验证消息")
    private String remark;
    @Schema(description = "创建时间")
    private java.util.Date createTime;
    @TableField(exist = false)
    @Schema(description = "发起人昵称（JOIN查询）")
    private String fromNickname;
    @TableField(exist = false)
    @Schema(description = "发起人头像（JOIN查询）")
    private String fromAvatar;

    public ChatFriendRequest() {
    }
}
