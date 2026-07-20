package com.stylesmile.chat.entity;

import lombok.Data;

/**
 * @author chenye
 * @date 2018/12/10
 */
@Data
public class ChatGroup {
    /**
     * 主键
     */
    private Long id;
    /**
     * 群名称
     */
    private String name;
    /**
     * 头像
     */
    private String avatar;
    /**
     * 群主ID
     */
    private Long ownerId;
    /**
     * 最大成员数
     */
    private Integer maxMembers;
    /**
     * 创建时间
     */
    private java.util.Date createTime;
    /**
     * 更新时间
     */
    private java.util.Date updateTime;
    /**
     * 删除标识 0.未删除，1.删除
     */
    private Integer delFlag;

    public ChatGroup() {
    }
}
