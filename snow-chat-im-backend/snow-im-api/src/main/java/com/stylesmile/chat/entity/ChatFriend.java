package com.stylesmile.chat.entity;

/**
 * @author chenye
 * @date 2018/12/10
 */
public class ChatFriend {
    /**
     * 主键
     */
    private Integer id;
    /**
     * 用户ID
     */
    private Integer userId;
    /**
     * 好友ID
     */
    private Integer friendId;
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

    public Integer getFriendId() {
        return friendId;
    }

    public void setFriendId(Integer friendId) {
        this.friendId = friendId;
    }

    public String getRemark() {
        return remark;
    }

    public void setRemark(String remark) {
        this.remark = remark;
    }

    public java.util.Date getCreateTime() {
        return createTime;
    }

    public void setCreateTime(java.util.Date createTime) {
        this.createTime = createTime;
    }

    public String getNickname() {
        return nickname;
    }

    public void setNickname(String nickname) {
        this.nickname = nickname;
    }

    public String getAvatar() {
        return avatar;
    }

    public void setAvatar(String avatar) {
        this.avatar = avatar;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }
}
