package com.stylesmile.chat.entity;

import java.util.Date;

/**
 * 验证码实体：邮箱注册验证 / 找回密码
 * Verify code entity: email registration verification / password reset
 *
 * @author chenye
 * @date 2026/08/19
 */
public class ChatVerifyCode {
    /** 主键 */
    private Long id;
    /** 邮箱地址 */
    private String email;
    /** 6位数字验证码 */
    private String code;
    /** 类型：register / reset_password */
    private String type;
    /** 过期时间 */
    private Date expireTime;
    /** 是否已使用：0=未使用 1=已使用 */
    private Integer used;
    /** 创建时间 */
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
