package com.stylesmile.chat.service.impl;

import cn.hutool.crypto.SecureUtil;
import com.stylesmile.common.service.BaseServiceImpl;
import com.stylesmile.common.util.Result;
import com.stylesmile.chat.entity.ChatUser;
import com.stylesmile.chat.mapper.ChatUserMapper;
import com.stylesmile.chat.service.ChatUserService;
import org.springframework.stereotype.Service;

/**
 * 聊天用户服务实现
 *
 * @author chenye
 * @date 2018/12/10
 */
@Service
public class ChatUserServiceImpl extends BaseServiceImpl<ChatUserMapper, ChatUser> implements ChatUserService {

    @Override
    public ChatUser getUserByUsername(String username) {
        return baseMapper.getUserByUsername(username);
    }

    @Override
    public ChatUser getUserById(Integer userId) {
        return getById(userId);
    }

    @Override
    public Result login(String username, String password) {
        ChatUser user = baseMapper.getUserByUsername(username);
        if (null == user) {
            return Result.failMessage("用户不存在");
        }
        String hashedPassword = SecureUtil.md5(username + password);
        if (!user.getPassword().equals(hashedPassword)) {
            return Result.failMessage("用户名或者密码错误");
        }
        return Result.success(user);
    }

    @Override
    public int countOnlineUsers() {
        return Math.toIntExact(lambdaQuery().eq(ChatUser::getStatus, "online").count());
    }

    @Override
    public Result register(String username, String password, String nickname, String email) {
        // 检查用户名是否已存在
        ChatUser existingUser = baseMapper.getUserByUsername(username);
        if (existingUser != null) {
            return Result.failMessage("用户名已存在");
        }

        // 检查邮箱是否已存在
        if (email != null && !email.isEmpty()) {
            ChatUser userByEmail = lambdaQuery().eq(ChatUser::getEmail, email).one();
            if (userByEmail != null) {
                return Result.failMessage("邮箱已被注册");
            }
        }

        // 密码加密：md5(username + password)
        String hashedPassword = SecureUtil.md5(username + password);

        // 创建新用户
        ChatUser newUser = new ChatUser(username, hashedPassword);
        newUser.setNickname(nickname != null ? nickname : username);
        newUser.setEmail(email != null ? email : "");
        newUser.setStatus("offline");
        newUser.setAvatar("");
        newUser.setSignature("");

        save(newUser);
        return Result.success(newUser);
    }
}
