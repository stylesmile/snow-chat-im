package com.stylesmile.chat.entity;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.Date;

/**
 * 群组成员实体类
 */
@NoArgsConstructor
@AllArgsConstructor
@Data
@Schema(description = "群组成员实体")
public class ChatGroupMember {
    @Schema(description = "主键ID")
    private Long id;
    @Schema(description = "群组ID")
    private Long groupId;
    @Schema(description = "用户ID")
    private Long userId;
    @Schema(description = "角色：admin/member", example = "member")
    private String role;
    @Schema(description = "加入时间")
    private Date joinTime;
    @Schema(description = "是否禁言：0=否, 1=是", example = "0")
    private Integer mute;
}
