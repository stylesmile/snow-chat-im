package com.stylesmile.chat.controller;

import com.stylesmile.common.util.Result;
import com.stylesmile.chat.entity.ChatUser;
import com.stylesmile.chat.service.ChatUserService;
import com.stylesmile.chat.storage.FileStorage;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import org.springframework.web.bind.annotation.*;

import javax.annotation.Resource;
import java.util.List;

/**
 * 聊天用户控制器
 *
 * @author chenye
 * @date 2018/12/10
 */
@RestController
@RequestMapping("/chat/user")
public class ChatUserController {

    /**
     * 头像对象 key 的统一前缀。
     * DB 的 avatar 字段若以此前缀开头，则视为 MinIO 对象 key，需要在 info 端点动态生成 pre-signed URL。
     */
    private static final String AVATAR_KEY_PREFIX = "avatars/";

    /**
     * pre-signed URL 有效期：7 天（单位：分钟）。
     * 7 * 24 * 60 = 10080 分钟。
     */
    private static final int PRESIGN_EXPIRATION_MINUTES = 7 * 24 * 60;

    @Resource
    private ChatUserService chatUserService;

    /**
     * 文件存储出站端口：用于 info 端点将 avatar key 转换为 pre-signed URL。
     * 由 Spring 注入 MinioFileStorage 或 InMemoryFileStorage。
     */
    @Resource
    private FileStorage fileStorage;

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
     * 用户注册
     *
     * @param username 用户名
     * @param password 密码
     * @param nickname 昵称
     * @param email    邮箱
     * @return Result
     */
    @PostMapping("/register")
    public Result register(@RequestBody RegisterDTO body) {
        return chatUserService.register(body.getUsername(), body.getPassword(), body.getNickname(), body.getEmail());
    }

    public static class CredentialsDTO {
        private String username;
        private String password;

        public String getUsername() { return username; }
        public void setUsername(String username) { this.username = username; }
        public String getPassword() { return password; }
        public void setPassword(String password) { this.password = password; }
    }

    public static class RegisterDTO extends CredentialsDTO {
        private String nickname;
        private String email;

        public String getNickname() { return nickname; }
        public void setNickname(String nickname) { this.nickname = nickname; }
        public String getEmail() { return email; }
        public void setEmail(String email) { this.email = email; }
    }

    /**
     * 更新个人资料 DTO。
     *
     * <p>使用 @RequestBody 接收 JSON 请求体（与前端 Flutter 调用方式对齐）。
     * 字段为 null 表示不更新该字段。
     */
    public static class UpdateProfileDTO {
        /** 用户 ID（必传） */
        private Integer userId;
        /** 昵称（可选） */
        private String nickname;
        /** 头像（可选；前端应传 MinIO 对象 key，如 avatars/uuid.jpg） */
        private String avatar;
        /** 签名（可选） */
        private String signature;

        public Integer getUserId() { return userId; }
        public void setUserId(Integer userId) { this.userId = userId; }
        public String getNickname() { return nickname; }
        public void setNickname(String nickname) { this.nickname = nickname; }
        public String getAvatar() { return avatar; }
        public void setAvatar(String avatar) { this.avatar = avatar; }
        public String getSignature() { return signature; }
        public void setSignature(String signature) { this.signature = signature; }
    }

    /**
     * 根据ID获取用户信息
     *
     * <p>若 DB 中 avatar 字段以 {@code avatars/} 开头（即 MinIO 对象 key），
     * 则动态生成 7 天有效的 pre-signed URL 后返回；否则原样返回（兼容历史数据）。
     *
     * @param userId 用户ID
     * @return Result
     */
    @GetMapping("/info/{userId}")
    public Result<ChatUser> info(@PathVariable Integer userId) {
        ChatUser user = chatUserService.getUserById(userId);
        // 用户存在时，按需转换 avatar key → pre-signed URL
        if (user != null) {
            convertAvatarIfNeeded(user);
        }
        return Result.success(user);
    }

    /**
     * 若 avatar 是 MinIO 对象 key（以 avatars/ 开头），转换为 pre-signed URL；
     * 否则原样保留（兼容历史 URL 数据或 null）。
     *
     * @param user 待转换的用户对象
     */
    private void convertAvatarIfNeeded(ChatUser user) {
        String avatar = user.getAvatar();
        // null 或非 avatars/ 前缀的字符串直接跳过
        if (avatar == null || !avatar.startsWith(AVATAR_KEY_PREFIX)) {
            return;
        }
        // 调用 FileStorage 生成 7 天有效的 pre-signed URL
        String presignedUrl = fileStorage.generatePresignedUrl(avatar, PRESIGN_EXPIRATION_MINUTES);
        user.setAvatar(presignedUrl);
    }

    /**
     * 搜索用户
     *
     * @param keyword 关键词
     * @param page    页码
     * @param size    每页大小
     * @return Result
     */
    @GetMapping("/search")
    public Result<List<ChatUser>> search(@RequestParam(required = false) String keyword,
                                         @RequestParam(defaultValue = "1") Integer page,
                                         @RequestParam(defaultValue = "10") Integer size) {
        LambdaQueryWrapper<ChatUser> wrapper = new LambdaQueryWrapper<>();
        if (keyword != null && !keyword.isEmpty()) {
            wrapper.and(w -> w.like(ChatUser::getUsername, keyword)
                    .or()
                    .like(ChatUser::getNickname, keyword));
        }
        List<ChatUser> users = chatUserService.page(new Page<>(page, size), wrapper).getRecords();
        return Result.success(users);
    }

    /**
     * 更新个人资料
     *
     * <p>使用 @RequestBody 接收 JSON（修复原 @RequestParam 与前端 JSON body 不匹配的 bug）。
     * 只更新 DTO 中非 null 的字段。
     *
     * @param dto 更新资料 DTO
     * @return Result
     */
    @PutMapping("/profile")
    public Result<Void> updateProfile(@RequestBody UpdateProfileDTO dto) {
        ChatUser user = chatUserService.getUserById(dto.getUserId());
        if (user != null) {
            // 仅更新非 null 字段
            if (dto.getNickname() != null) {
                user.setNickname(dto.getNickname());
            }
            if (dto.getAvatar() != null) {
                user.setAvatar(dto.getAvatar());
            }
            if (dto.getSignature() != null) {
                user.setSignature(dto.getSignature());
            }
            chatUserService.updateById(user);
        }
        return Result.success();
    }
}
