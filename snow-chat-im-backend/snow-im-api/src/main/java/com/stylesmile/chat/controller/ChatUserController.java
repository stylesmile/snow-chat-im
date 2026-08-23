package com.stylesmile.chat.controller;

import com.stylesmile.chat.service.ChatUserService;
import com.stylesmile.chat.service.ChatVerifyCodeService;
import com.stylesmile.chat.service.FileStorageService;
import com.stylesmile.common.util.JwtUtil;
import com.stylesmile.common.util.Result;
import com.stylesmile.chat.dto.UploadResult;
import com.stylesmile.chat.entity.ChatUser;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import javax.annotation.Resource;
import jakarta.servlet.http.HttpServletRequest;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

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

    @Resource
    private FileStorageService fileStorageService;

    /**
     * 用户登录：验证用户名密码，成功返回用户信息 + JWT token
     *
     * @param body     包含 username, password
     * @param request  ServletRequest，用于后续获取 token
     * @return Result  data 中包含 user 信息和 token
     */
    @PostMapping("/login")
    public Result<Map<String, Object>> login(@RequestBody CredentialsDTO body,
                                              HttpServletRequest request) {
        Result<ChatUser> result = chatUserService.login(body.getUsername(), body.getPassword());
        if (!"200".equals(result.getCode())) {
            return Result.failMessage(result.getMsg());
        }
        ChatUser user = result.getData();
        // 生成 JWT token
        String token = JwtUtil.createToken(user.getId(), user.getUsername());
        // 将 token 放入请求属性，供后续使用（保持和旧接口兼容）
        request.setAttribute("currentToken", token);
        // 返回结果：包裹 token 字段
        Map<String, Object> data = new HashMap<>();
        data.put("token", token);
        data.put("user", user);
        return Result.success(data);
    }

    /**
     * 用户退出登录（纯客户端操作，服务端无需清理，直接返回成功）
     * 客户端收到成功后清除本地存储的 token 即可
     */
    @PostMapping("/logout")
    public Result<Void> logout() {
        return Result.success();
    }

    /**
     * 上传用户头像（独立接口，上传到avatars/目录，持久化到DB，返回展示URL）
     *
     * <p>流程：
     * <ol>
     *   <li>从 token 解析当前 userId（由 AuthFilter 设置）；</li>
     *   <li>上传文件到对象存储（key 格式：avatars/{uuid}.{ext}）；</li>
     *   <li>将存储 key 写入 ChatUser.avatar 字段；</li>
     *   <li>返回 {key, url}，url 为永久可访问地址（非 pre-signed URL）。</li>
     * </ol>
     *
     * @param file multipart 头像文件，表单字段名 file
     * @return Result<Map> data 中包含 key（DB 存储值）和 url（前端展示地址）
     */
    @PostMapping("/avatar/upload")
    public Result<Map<String, String>> uploadAvatar(@RequestParam("file") MultipartFile file,
                                                     HttpServletRequest request) {
        // 1. 从 token 获取当前用户 ID（AuthFilter 已设置）
        Integer userId = get_currentUserId(request);
        if (userId == null) {
            return Result.failMessage("未登录");
        }
        // 2. 上传文件，获取 key 和预签名 URL
        UploadResult uploadResult = fileStorageService.uploadAndSign(file);
        if (uploadResult == null) {
            return Result.failMessage("头像上传失败");
        }
        String key = uploadResult.key();
        String presignedUrl = uploadResult.url();
        // 3. 更新 DB 中的头像字段为 storage key
        ChatUser user = chatUserService.getUserById(userId);
        if (user == null) {
            return Result.failMessage("用户不存在");
        }
        user.setAvatar(key);
        chatUserService.updateById(user);
        // 4. 返回：key 供后续查询，url 为可访问地址
        Map<String, String> data = new HashMap<>();
        data.put("key", key);
        data.put("url", presignedUrl);
        return Result.success(data);
    }

    /**
     * 模糊搜索用户（匹配 username 或 nickname，最多返回 20 条）
     *
     * @param keyword 搜索关键词
     * @return 匹配的用户列表
     */
    @GetMapping("/search")
    public Result<List<ChatUser>> searchUsers(@RequestParam String keyword) {
        if (keyword == null || keyword.trim().isEmpty()) {
            return Result.success(java.util.List.of());
        }
        java.util.List<ChatUser> users = chatUserService.searchUsers(keyword.trim());
        return Result.success(users);
    }

    /**
     * 获取当前用户信息（从 token 中解析 userId）
     *
     * <p>avatar 字段处理：
     * <ul>
     *   <li>若 avatar 以 {@code avatars/} 开头 → 视为 storage key，实时生成 pre-signed URL；</li>
     *   <li>否则 → 直接返回原始值（兼容历史全 URL 数据）。</li>
     * </ul>
     */
    @GetMapping("/info")
    public Result<ChatUser> info(HttpServletRequest request) {
        Integer userId = get_currentUserId(request);
        if (userId == null) {
            return Result.failMessage("未登录");
        }
        ChatUser user = chatUserService.getUserById(userId);
        if (user == null) {
            return Result.failMessage("用户不存在");
        }
        // 若 avatar 是 storage key，实时生成有效 URL
        String avatar = user.getAvatar();
        if (avatar != null && avatar.startsWith("avatars/")) {
            String url = fileStorageService.generateAvatarUrl(avatar);
            user.setAvatar(url);
        }
        return Result.success(user);
    }

    /**
     * 更新用户资料（昵称、头像、签名）
     */
    @PutMapping("/update")
    public Result<Void> updateProfile(@RequestBody UpdateProfileDTO body,
                                       HttpServletRequest request) {
        Integer userId = get_currentUserId(request);
        if (userId == null) {
            return Result.failMessage("未登录");
        }
        ChatUser user = chatUserService.getUserById(userId);
        if (user == null) {
            return Result.failMessage("用户不存在");
        }
        if (body.getNickname() != null) {
            user.setNickname(body.getNickname());
        }
        if (body.getAvatar() != null) {
            user.setAvatar(body.getAvatar());
        }
        if (body.getSignature() != null) {
            user.setSignature(body.getSignature());
        }
        chatUserService.updateById(user);
        return Result.success();
    }

    /**
     * 用户注册（邮箱必填 + 验证码校验）
     */
    @PostMapping("/register")
    public Result<Map<String, Object>> register(@RequestBody RegisterDTO body) {
        Result<ChatUser> result = chatUserService.register(
                body.getUsername(),
                body.getPassword(),
                body.getNickname(),
                body.getEmail(),
                body.getCode()
        );
        if (!"200".equals(result.getCode())) {
            return Result.failMessage(result.getMsg());
        }
        ChatUser user = result.getData();
        // 注册成功后直接登录，返回 token
        String token = JwtUtil.createToken(user.getId(), user.getUsername());
        Map<String, Object> data = new HashMap<>();
        data.put("token", token);
        data.put("user", user);
        return Result.success(data);
    }

    /**
     * 仅校验验证码是否有效（不消耗，用于注册步骤1预览）
     */
    @PostMapping("/verify/code")
    public Result<Boolean> verifyCodeOnly(@RequestBody VerifyCodeDTO body) {
        if (body.getEmail() == null || body.getEmail().trim().isEmpty()
                || body.getCode() == null || body.getCode().trim().isEmpty()) {
            return Result.failMessage("邮箱或验证码不能为空");
        }
        boolean valid = verifyCodeService.checkCode(
                body.getEmail().trim(), body.getCode().trim(), body.getType());
        return Result.success(valid);
    }

    /**
     * 发送邮箱验证码
     * type: register（注册验证） / reset_password（找回密码验证）
     */
    @PostMapping("/send/email/code")
    public Result<Void> sendEmailCode(@RequestParam String email, @RequestParam String type) {
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
     */
    @PostMapping("/reset/password")
    public Result<Void> resetPassword(@RequestBody ResetPasswordDTO body) {
        return chatUserService.resetPasswordByEmail(body.getEmail(), body.getCode(), body.getNewPassword());
    }

    // -------------------------------------------------------------------------
    // 辅助方法
    // -------------------------------------------------------------------------

    /**
     * 从请求属性中获取当前登录用户 ID（由 AuthFilter 设置）
     * 若未设置则返回 null（表示未登录）
     */
    private Integer get_currentUserId(HttpServletRequest request) {
        Object attr = request.getAttribute("currentUserId");
        return attr instanceof Integer ? (Integer) attr : null;
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
        private String code;
        public String getNickname() { return nickname; }
        public void setNickname(String nickname) { this.nickname = nickname; }
        public String getEmail() { return email; }
        public void setEmail(String email) { this.email = email; }
        public String getCode() { return code; }
        public void setCode(String code) { this.code = code; }
    }

    /** 更新资料请求体 */
    public static class UpdateProfileDTO {
        private String nickname;
        private String avatar;
        private String signature;
        public String getNickname() { return nickname; }
        public void setNickname(String nickname) { this.nickname = nickname; }
        public String getAvatar() { return avatar; }
        public void setAvatar(String avatar) { this.avatar = avatar; }
        public String getSignature() { return signature; }
        public void setSignature(String signature) { this.signature = signature; }
    }

    /** 重置密码请求体 */
    public static class ResetPasswordDTO {
        private String email;
        private String code;
        private String newPassword;
        public String getEmail() { return email; }
        public void setEmail(String email) { this.email = email; }
        public String getCode() { return code; }
        public void setCode(String code) { this.code = code; }
        public String getNewPassword() { return newPassword; }
        public void setNewPassword(String newPassword) { this.newPassword = newPassword; }
    }

    /** 仅校验验证码请求体（不消耗） */
    public static class VerifyCodeDTO {
        private String email;
        private String code;
        private String type;
        public String getEmail() { return email; }
        public void setEmail(String email) { this.email = email; }
        public String getCode() { return code; }
        public void setCode(String code) { this.code = code; }
        public String getType() { return type; }
        public void setType(String type) { this.type = type; }
    }
}
