package com.stylesmile.chat.entity;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.Date;

/**
 * @author chenye
 * @date 2018/12/10
 */
@NoArgsConstructor
@AllArgsConstructor
@Data
public class ChatGroupMember {
    /**
     * 主键
     */
    private Long id;
    /**
     * 群组ID
     */
    private Long groupId;
    /**
     * 用户ID
     */
    private Long userId;
    /**
     * 角色 admin/member
     */
    private String role;
    /**
     * 加入时间
     */
    private Date joinTime;
    /**
     * 是否禁言
     */
    private Integer mute;

}

