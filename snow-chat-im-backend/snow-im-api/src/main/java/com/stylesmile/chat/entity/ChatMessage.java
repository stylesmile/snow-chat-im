package com.stylesmile.chat.entity;

/**
 * @author chenye
 * @date 2018/12/10
 */
public class ChatMessage {
    /**
     * 主键
     */
    private Integer id;
    /**
     * 发送人ID
     */
    private Integer fromUserId;
    /**
     * 接收人ID
     */
    private Integer toUserId;
    /**
     * 群组ID
     */
    private Integer groupId;
    /**
     * 消息类型 text/image/file/video
     */
    private String type;
    /**
     * 消息内容
     */
    private String content;
    /**
     * 本地序列号
     */
    private Integer localSeq;
    /**
     * 状态
     */
    private Integer status;
    /**
     * 创建时间
     */
    private java.util.Date createTime;

    public ChatMessage() {
    }

    public Integer getId() {
        return id;
    }

    public void setId(Integer id) {
        this.id = id;
    }

    public Integer getFromUserId() {
        return fromUserId;
    }

    public void setFromUserId(Integer fromUserId) {
        this.fromUserId = fromUserId;
    }

    public Integer getToUserId() {
        return toUserId;
    }

    public void setToUserId(Integer toUserId) {
        this.toUserId = toUserId;
    }

    public Integer getGroupId() {
        return groupId;
    }

    public void setGroupId(Integer groupId) {
        this.groupId = groupId;
    }

    public String getType() {
        return type;
    }

    public void setType(String type) {
        this.type = type;
    }

    public String getContent() {
        return content;
    }

    public void setContent(String content) {
        this.content = content;
    }

    public Integer getLocalSeq() {
        return localSeq;
    }

    public void setLocalSeq(Integer localSeq) {
        this.localSeq = localSeq;
    }

    public Integer getStatus() {
        return status;
    }

    public void setStatus(Integer status) {
        this.status = status;
    }

    public java.util.Date getCreateTime() {
        return createTime;
    }

    public void setCreateTime(java.util.Date createTime) {
        this.createTime = createTime;
    }
}
