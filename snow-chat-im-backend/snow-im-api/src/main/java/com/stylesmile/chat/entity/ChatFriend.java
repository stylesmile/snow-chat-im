package com.stylesmile.chat.entity;

import lombok.Data;

/**
 * @author chenye
 * @date 2018/12/10
 */
@Data
public class ChatFriend {
    /**
     * 主键
     */
    private Long id;
    /**
     * 用户ID
     */
    private Long userId;
    /**
     * 好友ID
     */
    private Long friendId;
    /**
     * 备注
     */
    private String remark;
    /**
     * 创建时间
     */
    private java.util.Date createTime;
    /**
     * 好友昵称（JOIN查询）
     */
    private String nickname;
    /**
     * 好友头像（JOIN查询）
     */
    private String avatar;
    /**
     * 好友在线状态（JOIN查询）
     */
    private String status;

    public ChatFriend() {
    }


}
