package com.stylesmile.chat.entity;

import io.swagger.v3.oas.annotations.media.Schema;
import java.util.Date;

/**
 * 验证码实体类
 */
@Schema(description = "验证码实体")
public class ChatVerifyCode {
    @Schema(description = "主键ID")
    private Long id;
    @Schema(description = "邮箱地址", example = "zhangsan@example.com")
    private String email;
    @Schema(description = "6位数字验证码", example = "123456")
    private String code;
    @Schema(description = "类型：register/reset_password", example = "register")
    private String type;
    @Schema(description = "过期时间")
    private Date expireTime;
    @Schema(description = "是否已使用：0=未使用, 1=已使用", example = "0")
    private Integer used;
    @Schema(description = "创建时间")
    private Date createTime;

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }
    public String getCode() { return code; }
    public void setCode(String code) { this.code = code; }
    public String getType() { return type; }
    public void setType(String type) { this.type = type; }
    public Date getExpireTime() { return expireTime; }
    public void setExpireTime(Date expireTime) { this.expireTime = expireTime; }
    public Integer getUsed() { return used; }
    public void setUsed(Integer used) { this.used = used; }
    public Date getCreateTime() { return createTime; }
    public void setCreateTime(Date createTime) { this.createTime = createTime; }
}
