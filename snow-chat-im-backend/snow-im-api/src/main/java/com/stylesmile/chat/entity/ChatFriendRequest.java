package com.stylesmile.chat.entity;

import com.baomidou.mybatisplus.annotation.TableField;
import lombok.Data;

/**
 * @author chenye
 * @date 2018/12/10
 */
@Data
public class ChatFriendRequest {
    /**
     * 主键
     */
    private Long id;
    /**
     * 发起人ID
     */
    private Long fromUserId;
    /**
     * 接收人ID
     */
    private Long toUserId;
    /**
     * 状态 pending/accepted/rejected
     */
    private String status;
    /**
     * 备注
     */
    private String remark;
    /**
     * 创建时间
     */
    private java.util.Date createTime;
    /**
     * 发起人昵称（JOIN查询）
     */
    @TableField(exist = false)
    private String fromNickname;
    /**
     * 发起人头像（JOIN查询）
     */
    @TableField(exist = false)
    private String fromAvatar;

    public ChatFriendRequest() {
    }

 }
