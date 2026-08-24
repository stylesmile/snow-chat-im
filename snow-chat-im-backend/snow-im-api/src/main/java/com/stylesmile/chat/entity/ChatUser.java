package com.stylesmile.chat.entity;

import io.swagger.v3.oas.annotations.media.Schema;

/**
 * 用户实体类
 */
@Schema(description = "用户实体")
public class ChatUser {
    @Schema(description = "主键ID")
    private Long id;
    @Schema(description = "用户名", example = "zhangsan")
    private String username;
    @Schema(description = "密码（加密存储）")
    private String password;
    @Schema(description = "昵称", example = "张三")
    private String nickname;
    @Schema(description = "邮箱", example = "zhangsan@example.com")
    private String email;
    @Schema(description = "头像URL或storage key", example = "avatars/abc123.jpg")
    private String avatar;
    @Schema(description = "个性签名", example = "Hello World")
    private String signature;
    @Schema(description = "在线状态：online/offline/busy", example = "online")
    private String status;
    @Schema(description = "创建时间")
    private java.util.Date createTime;
    @Schema(description = "更新时间")
    private java.util.Date updateTime;

    public ChatUser() {
    }

    public ChatUser(String username, String password) {
        this.username = username;
        this.password = password;
    }

    public ChatUser(String username) {
        this.username = username;
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getUsername() { return username; }
    public void setUsername(String username) { this.username = username; }
    public String getPassword() { return password; }
    public void setPassword(String password) { this.password = password; }
    public String getNickname() { return nickname; }
    public void setNickname(String nickname) { this.nickname = nickname; }
    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }
    public String getAvatar() { return avatar; }
    public void setAvatar(String avatar) { this.avatar = avatar; }
    public String getSignature() { return signature; }
    public void setSignature(String signature) { this.signature = signature; }
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
    public java.util.Date getCreateTime() { return createTime; }
    public void setCreateTime(java.util.Date createTime) { this.createTime = createTime; }
    public java.util.Date getUpdateTime() { return updateTime; }
    public void setUpdateTime(java.util.Date updateTime) { this.updateTime = updateTime; }
}
