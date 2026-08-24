package com.stylesmile.chat.entity;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Data;

/**
 * 群组实体类
 */
@Data
@Schema(description = "群组实体")
public class ChatGroup {
    @Schema(description = "主键ID")
    private Long id;
    @Schema(description = "群名称", example = "测试群组")
    private String name;
    @Schema(description = "头像URL")
    private String avatar;
    @Schema(description = "群主ID")
    private Long ownerId;
    @Schema(description = "最大成员数", example = "500")
    private Integer maxMembers;
    @Schema(description = "创建时间")
    private java.util.Date createTime;
    @Schema(description = "更新时间")
    private java.util.Date updateTime;
    @Schema(description = "删除标识：0=未删除, 1=已删除", example = "0")
    private Integer delFlag;

    public ChatGroup() {
    }
}
