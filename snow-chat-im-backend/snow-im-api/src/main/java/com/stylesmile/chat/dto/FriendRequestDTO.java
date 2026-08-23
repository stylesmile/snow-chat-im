package com.stylesmile.chat.dto;

import lombok.*;


@Setter
@Getter
@NoArgsConstructor
@AllArgsConstructor
public  class FriendRequestDTO {
    private Long fromUserId;
    private Long toUserId;
    private String remark;
}