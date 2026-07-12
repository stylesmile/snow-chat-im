package com.stylesmile.chat.controller;

import com.stylesmile.common.util.Result;
import com.stylesmile.chat.entity.ChatUser;
import com.stylesmile.chat.service.ChatUserService;
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

    @Resource
    private ChatUserService chatUserService;

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
     * 根据ID获取用户信息
     *
     * @param userId 用户ID
     * @return Result
     */
    @GetMapping("/info/{userId}")
    public Result<ChatUser> info(@PathVariable Integer userId) {
        ChatUser user = chatUserService.getUserById(userId);
        return Result.success(user);
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
     * @param userId    用户ID
     * @param nickname  昵称
     * @param avatar    头像
     * @param signature 签名
     * @return Result
     */
    @PutMapping("/profile")
    public Result<Void> updateProfile(@RequestParam Integer userId,
                                      @RequestParam(required = false) String nickname,
                                      @RequestParam(required = false) String avatar,
                                      @RequestParam(required = false) String signature) {
        ChatUser user = chatUserService.getUserById(userId);
        if (user != null) {
            if (nickname != null) {
                user.setNickname(nickname);
            }
            if (avatar != null) {
                user.setAvatar(avatar);
            }
            if (signature != null) {
                user.setSignature(signature);
            }
            chatUserService.updateById(user);
        }
        return Result.success();
    }
}
