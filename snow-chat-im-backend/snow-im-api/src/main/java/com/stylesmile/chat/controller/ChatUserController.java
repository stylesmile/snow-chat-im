package com.stylesmile.chat.controller;

import com.stylesmile.chat.service.ChatUserService;
import com.stylesmile.chat.service.ChatVerifyCodeService;
import com.stylesmile.chat.service.FileStorageService;
import com.stylesmile.common.util.JwtUtil;
import com.stylesmile.common.util.Result;
import com.stylesmile.chat.dto.UploadResult;
import com.stylesmile.chat.entity.ChatUser;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import io.swagger.v3.oas.annotations.media.Schema;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import javax.annotation.Resource;
import jakarta.servlet.http.HttpServletRequest;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 聊天用户控制器 - 用户认证、资料管理、头像上传
 *
 * @author chenye
 * @date 2018/12/10
 */
@RestController
@RequestMapping("/chat/user")
@Tag(name = "用户管理", description = "用户登录、注册、资料管理、头像上传接口")
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
    @Operation(summary = "用户登录", description = "验证用户名密码，成功返回用户信息 + JWT token")
    @ApiResponse(responseCode = "200", description = "登录成功")
    @ApiResponse(responseCode = "401", description = "用户名或密码错误")
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
    @Operation(summary = "用户退出登录", description = "客户端清除本地token即可，服务端无需清理")
    @ApiResponse(responseCode = "200", description = "退出成功")
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
    @Operation(summary = "上传用户头像", description = "上传头像到avatars/目录，持久化到DB，返回展示URL")
    @ApiResponse(responseCode = "200", description = "上传成功")
    @ApiResponse(responseCode = "401", description = "未登录")
    @PostMapping("/avatar/upload")
    public Result<Map<String, String>> uploadAvatar(@RequestParam("file") MultipartFile file,
                                                     HttpServletRequest request) {
        // 1. 从 token 获取当前用户 ID（AuthFilter 已设置）
        Long userId = get_currentUserId(request);
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
    @Operation(summary = "搜索用户", description = "模糊搜索用户，匹配username或nickname")
    @ApiResponse(responseCode = "200", description = "搜索成功")
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
    @Operation(summary = "获取当前用户信息", description = "从JWT token中解析用户ID，返回用户详细信息")
    @ApiResponse(responseCode = "200", description = "获取成功")
    @ApiResponse(responseCode = "401", description = "未登录")
    @GetMapping("/info")
    public Result<ChatUser> info(HttpServletRequest request) {
        Long userId = get_currentUserId(request);
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
     * 按任意 userId 查询用户公开信息（扫码添加好友预览用）
     *
     * <p>与 {@code /info} 的区别：这里按 URL 传入的 userId 查询，而非从 JWT token
     * 解析当前用户，且不做登录态校验——因为扫码场景需要查看【对方】的资料。
     *
     * <p>avatar 处理逻辑与 /info 保持一致：若以 {@code avatars/} 开头则视为 storage key，
     * 实时生成 pre-signed URL；否则原样返回。</p>
     *
     * @param userId 目标用户 ID（来自二维码内容）
     * @return 该用户公开信息；不存在时返回失败
     */
    @Operation(summary = "按用户ID查询公开信息", description = "扫码添加好友时按userId查询对方资料（无需登录态校验）")
    @ApiResponse(responseCode = "200", description = "查询成功")
    @ApiResponse(responseCode = "500", description = "用户不存在")
    @GetMapping("/infoById")
    // 参数用 Long：雪花 ID 超出 int 范围时，Integer 会在参数绑定阶段就失败（400），
    // 扫码添加这类用户将直接查不到人
    public Result<ChatUser> infoById(@RequestParam Long userId, HttpServletRequest request) {
        ChatUser user = chatUserService.getUserById(userId);
        if (user == null) {
            return Result.failMessage("用户不存在");
        }
        // 若 avatar 是 storage key，实时生成有效 URL（与 /info 一致）
        String avatar = user.getAvatar();
        if (avatar != null && avatar.startsWith("avatars/")) {
            String url = fileStorageService.generateAvatarUrl(avatar);
            user.setAvatar(url);
        }
        return Result.success(user);
    }

    /**
     * 更新用户资料（昵称、头像、签名、性别）
     */
    @Operation(summary = "更新用户资料", description = "更新用户昵称、头像、签名、性别")
    @ApiResponse(responseCode = "200", description = "更新成功")
    @ApiResponse(responseCode = "401", description = "未登录")
    @PutMapping("/update")
    public Result<Void> updateProfile(@RequestBody UpdateProfileDTO body,
                                       HttpServletRequest request) {
        Long userId = get_currentUserId(request);
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
        // 用户名（登录账号）：空白值不覆盖，避免前端传空串把账号清空
        if (body.getUsername() != null && !body.getUsername().isBlank()) {
            user.setUsername(body.getUsername().trim());
        }
        if (body.getSignature() != null) {
            user.setSignature(body.getSignature());
        }
        // 性别：仅当 DTO 中非 null 时才更新，保持与其他字段一致的处理方式
        if (body.getGender() != null) {
            user.setGender(body.getGender());
        }
        chatUserService.updateById(user);
        return Result.success();
    }

    /**
     * 用户注册（邮箱必填 + 验证码校验）
     */
    @Operation(summary = "用户注册", description = "邮箱注册，需要验证码校验")
    @ApiResponse(responseCode = "200", description = "注册成功")
    @ApiResponse(responseCode = "400", description = "验证码无效或邮箱已注册")
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
    @Operation(summary = "校验验证码", description = "仅校验验证码有效性，不消耗验证码")
    @ApiResponse(responseCode = "200", description = "校验完成")
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
    @Operation(summary = "发送邮箱验证码", description = "发送邮箱验证码，type: register/reset_password")
    @ApiResponse(responseCode = "200", description = "发送成功")
    @ApiResponse(responseCode = "400", description = "邮箱格式错误")
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
    @Operation(summary = "重置密码", description = "通过邮箱+验证码重置密码")
    @ApiResponse(responseCode = "200", description = "重置成功")
    @ApiResponse(responseCode = "400", description = "验证码无效或已过期")
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
    private Long get_currentUserId(HttpServletRequest request) {
        // AuthFilter 写入的是 Long（用户 ID 由雪花算法生成，可能超出 int 范围），
        // 这里必须按 Number 取值，否则旧写法 `attr instanceof Integer` 恒为 false，
        // 所有已登录用户都会被判成"未登录"，/user/info、头像上传、资料更新全部失效。
        Object attr = request.getAttribute("currentUserId");
        return attr instanceof Number ? ((Number) attr).longValue() : null;
    }

    // -------------------------------------------------------------------------
    // DTO 内部类
    // -------------------------------------------------------------------------

    /** 登录请求体 */
    @Schema(description = "登录请求体")
    public static class CredentialsDTO {
        @Schema(description = "用户名", example = "zhangsan")
        private String username;
        @Schema(description = "密码", example = "123456")
        private String password;
        public String getUsername() { return username; }
        public void setUsername(String username) { this.username = username; }
        public String getPassword() { return password; }
        public void setPassword(String password) { this.password = password; }
    }

    /** 注册请求体（含验证码） */
    @Schema(description = "注册请求体")
    public static class RegisterDTO extends CredentialsDTO {
        @Schema(description = "昵称", example = "张三")
        private String nickname;
        @Schema(description = "邮箱", example = "zhangsan@example.com")
        private String email;
        @Schema(description = "验证码", example = "123456")
        private String code;
        public String getNickname() { return nickname; }
        public void setNickname(String nickname) { this.nickname = nickname; }
        public String getEmail() { return email; }
        public void setEmail(String email) { this.email = email; }
        public String getCode() { return code; }
        public void setCode(String code) { this.code = code; }
    }

    /** 更新资料请求体 */
    @Schema(description = "更新资料请求体")
    public static class UpdateProfileDTO {
        @Schema(description = "昵称", example = "张三")
        private String nickname;
        @Schema(description = "头像URL", example = "https://example.com/avatar.jpg")
        private String avatar;
        @Schema(description = "用户名（登录账号）", example = "zhangsan")
        private String username;
        @Schema(description = "个性签名", example = "Hello World")
        private String signature;
        @Schema(description = "性别：0=未设置,1=男,2=女", example = "1")
        private Integer gender;
        public String getNickname() { return nickname; }
        public void setNickname(String nickname) { this.nickname = nickname; }
        public String getAvatar() { return avatar; }
        public String getUsername() { return username; }
        public void setUsername(String username) { this.username = username; }
        public void setAvatar(String avatar) { this.avatar = avatar; }
        public String getSignature() { return signature; }
        public void setSignature(String signature) { this.signature = signature; }
        public Integer getGender() { return gender; }
        public void setGender(Integer gender) { this.gender = gender; }
    }

    /** 重置密码请求体 */
    @Schema(description = "重置密码请求体")
    public static class ResetPasswordDTO {
        @Schema(description = "邮箱", example = "zhangsan@example.com")
        private String email;
        @Schema(description = "验证码", example = "123456")
        private String code;
        @Schema(description = "新密码", example = "newpassword123")
        private String newPassword;
        public String getEmail() { return email; }
        public void setEmail(String email) { this.email = email; }
        public String getCode() { return code; }
        public void setCode(String code) { this.code = code; }
        public String getNewPassword() { return newPassword; }
        public void setNewPassword(String newPassword) { this.newPassword = newPassword; }
    }

    /** 仅校验验证码请求体（不消耗） */
    @Schema(description = "验证码校验请求体")
    public static class VerifyCodeDTO {
        @Schema(description = "邮箱", example = "zhangsan@example.com")
        private String email;
        @Schema(description = "验证码", example = "123456")
        private String code;
        @Schema(description = "验证码类型: register/reset_password", example = "register")
        private String type;
        public String getEmail() { return email; }
        public void setEmail(String email) { this.email = email; }
        public String getCode() { return code; }
        public void setCode(String code) { this.code = code; }
        public String getType() { return type; }
        public void setType(String type) { this.type = type; }
    }
}
