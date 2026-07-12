package com.stylesmile.chat.entity;

/**
 * @author chenye
 * @date 2018/12/10
 */
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

    public ChatSession() {
    }

    public Integer getId() {
        return id;
    }

    public void setId(Integer id) {
        this.id = id;
    }

    public Integer getUserId() {
        return userId;
    }

    public void setUserId(Integer userId) {
        this.userId = userId;
    }

    public Integer getTargetId() {
        return targetId;
    }

    public void setTargetId(Integer targetId) {
        this.targetId = targetId;
    }

    public String getTargetType() {
        return targetType;
    }

    public void setTargetType(String targetType) {
        this.targetType = targetType;
    }

    public String getLastMsg() {
        return lastMsg;
    }

    public void setLastMsg(String lastMsg) {
        this.lastMsg = lastMsg;
    }

    public java.util.Date getLastMsgTime() {
        return lastMsgTime;
    }

    public void setLastMsgTime(java.util.Date lastMsgTime) {
        this.lastMsgTime = lastMsgTime;
    }

    public Integer getUnreadCount() {
        return unreadCount;
    }

    public void setUnreadCount(Integer unreadCount) {
        this.unreadCount = unreadCount;
    }

    public Integer getIsMuted() {
        return isMuted;
    }

    public void setIsMuted(Integer isMuted) {
        this.isMuted = isMuted;
    }

    public java.util.Date getUpdateTime() {
        return updateTime;
    }

    public void setUpdateTime(java.util.Date updateTime) {
        this.updateTime = updateTime;
    }
}
