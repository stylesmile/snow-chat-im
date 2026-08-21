package com.stylesmile.chat.dto;

import lombok.Data;

@Data
public  class FriendRequestDTO {
    private Long fromUserId;
    private Long toUserId;
    private String remark;
}