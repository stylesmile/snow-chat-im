package com.stylesmile.chat.entity;

/**
 * @author chenye
 * @date 2018/12/10
 */
public class ChatGroupMember {
    /**
     * 主键
     */
    private Integer id;
    /**
     * 群组ID
     */
    private Integer groupId;
    /**
     * 用户ID
     */
    private Integer userId;
    /**
     * 角色 admin/member
     */
    private String role;
    /**
     * 加入时间
     */
    private java.util.Date joinTime;
    /**
     * 是否禁言
     */
    private Integer mute;

    public ChatGroupMember() {
    }

    public Integer getId() {
        return id;
    }

    public void setId(Integer id) {
        this.id = id;
    }

    public Integer getGroupId() {
        return groupId;
    }

    public void setGroupId(Integer groupId) {
        this.groupId = groupId;
    }

    public Integer getUserId() {
        return userId;
    }

    public void setUserId(Integer userId) {
        this.userId = userId;
    }

    public String getRole() {
        return role;
    }

    public void setRole(String role) {
        this.role = role;
    }

    public java.util.Date getJoinTime() {
        return joinTime;
    }

    public void setJoinTime(java.util.Date joinTime) {
        this.joinTime = joinTime;
    }

    public Integer getMute() {
        return mute;
    }

    public void setMute(Integer mute) {
        this.mute = mute;
    }
}
