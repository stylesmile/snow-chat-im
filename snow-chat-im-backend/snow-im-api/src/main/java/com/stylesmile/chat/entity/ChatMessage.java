package com.stylesmile.chat.entity;

import lombok.Data;

/**
 * @author chenye
 * @date 2026/07/10
 */
@Data
public class ChatMessage {
    /**
     * 主键
     */
    private Long id;
    /**
     * 发送人ID
     */
    private Long fromUserId;
    /**
     * 接收人ID
     */
    private Long toUserId;
    /**
     * 群组ID
     */
    private Long groupId;
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
    private Long localSeq;
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

}
