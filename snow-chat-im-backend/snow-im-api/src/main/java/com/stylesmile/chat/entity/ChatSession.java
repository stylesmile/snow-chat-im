package com.stylesmile.chat.entity;

import lombok.Data;

/**
 * @author chenye
 * @date 2018/12/10
 */
@Data
public class ChatSession {
    /**
     * 主键
     */
    private Integer id;
    /**
     * 用户ID
     */
    private Integer userId;
    /**
     * 目标ID（好友ID或群组ID）
     */
    private Integer targetId;
    /**
     * 目标类型 friend/group
     */
    private String targetType;
    /**
     * 最后一条消息
     */
    private String lastMsg;
    /**
     * 最后一条消息时间
     */
    private java.util.Date lastMsgTime;
    /**
     * 未读数
     */
    private Integer unreadCount;
    /**
     * 是否免打扰
     */
    private Integer isMuted;
    /**
     * 更新时间
     */
    private java.util.Date updateTime;
    private java.util.Date createTime;

    public ChatSession() {
    }

}
