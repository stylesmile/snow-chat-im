package com.stylesmile.chat.controller;

import com.stylesmile.chat.service.ChatUserService;
import com.stylesmile.chat.service.ChatVerifyCodeService;
import com.stylesmile.common.util.Result;
import org.springframework.web.bind.annotation.*;

import javax.annotation.Resource;

/**
 * 聊天用户控制器
 *
 * @author chenye
 * @date 2018/12/10
 */
@RestController
@RequestMapping("/chat/user")
public class ChatUserController {

    @Resource
    private ChatUserService chatUserService;

    @Resource
    private ChatVerifyCodeService verifyCodeService;

    /**
     * 用户登录
     *
     * @param username 用户名
     * @param password 密码
     * @return Result
     */
    @PostMapping("/login")
    public Result login(@RequestBody CredentialsDTO body) {
        return chatUserService.login(body.getUsername(), body.getPassword());
    }

    /**
     * 用户注册（邮箱必填 + 验证码校验）
     *
     * @param body 包含 username, password, nickname, email, code
     * @return Result
     */
    @PostMapping("/register")
    public Result register(@RequestBody RegisterDTO body) {
        return chatUserService.register(
                body.getUsername(),
                body.getPassword(),
                body.getNickname(),
                body.getEmail(),
                body.getCode()
        );
    }

    /**
     * 发送邮箱验证码
     * type: register（注册验证） / reset_password（找回密码验证）
     *
     * @param email 收件邮箱
     * @param type  验证码类型
     * @return Result
     */
    @PostMapping("/send/email/code")
    public Result sendEmailCode(@RequestParam String email, @RequestParam String type) {
        if (email == null || email.trim().isEmpty()) {
            return Result.failMessage("邮箱不能为空");
        }
        if (!"register".equals(type) && !"reset_password".equals(type)) {
            return Result.failMessage("无效的验证码类型");
        }
        boolean sent = verifyCodeService.sendCode(email.trim(), type);
        return sent ? Result.success() : Result.failMessage("验证码发送失败，请稍后重试");
    }

    /**
     * 通过邮箱+验证码重置密码
     *
     * @param email       注册时使用的邮箱
     * @param code        邮箱验证码
     * @param newPassword 新密码
     * @return Result
     */
    @PostMapping("/reset/password")
    public Result resetPassword(@RequestBody ResetPasswordDTO body) {
        return chatUserService.resetPasswordByEmail(
                body.getEmail(),
                body.getCode(),
                body.getNewPassword()
        );
    }

    // -------------------------------------------------------------------------
    // DTO 内部类
    // -------------------------------------------------------------------------

    /** 登录请求体 */
    public static class CredentialsDTO {
        private String username;
        private String password;
        public String getUsername() { return username; }
        public void setUsername(String username) { this.username = username; }
        public String getPassword() { return password; }
        public void setPassword(String password) { this.password = password; }
    }

    /** 注册请求体（含验证码） */
    public static class RegisterDTO extends CredentialsDTO {
        private String nickname;
        private String email;
        /** 邮箱验证码 */
        private String code;
        public String getNickname() { return nickname; }
        public void setNickname(String nickname) { this.nickname = nickname; }
        public String getEmail() { return email; }
        public void setEmail(String email) { this.email = email; }
        public String getCode() { return code; }
        public void setCode(String code) { this.code = code; }
    }

    /** 重置密码请求体 */
    public static class ResetPasswordDTO {
        private String email;
        /** 邮箱验证码 */
        private String code;
        private String newPassword;
        public String getEmail() { return email; }
        public void setEmail(String email) { this.email = email; }
        public String getCode() { return code; }
        public void setCode(String code) { this.code = code; }
        public String getNewPassword() { return newPassword; }
        public void setNewPassword(String newPassword) { this.newPassword = newPassword; }
    }
}
