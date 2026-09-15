package com.stylesmile.chat.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.*;

/**
 * 好友请求DTO
 */
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Schema(description = "好友请求DTO")
public class FriendRequestDTO {

    @Schema(description = "发起者用户ID", example = "1001")
    private Long fromUserId;

    @Schema(description = "接收者用户ID", example = "1002")
    private Long toUserId;

    @Schema(description = "验证消息", example = "你好，我是张三")
    private String remark;
}
