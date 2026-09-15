package com.stylesmile.chat.vo;

import lombok.Data;

@Data
public class ChatUserVO {

    private Long id;

    private String username;

    private String nickname;

    private String avatar;

    private String status;
}
