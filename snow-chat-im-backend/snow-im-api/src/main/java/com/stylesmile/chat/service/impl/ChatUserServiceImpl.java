package com.stylesmile.chat.service.impl;

import cn.hutool.core.util.IdUtil;
import cn.hutool.crypto.SecureUtil;
import com.stylesmile.common.service.BaseServiceImpl;
import com.stylesmile.common.util.Result;
import com.stylesmile.chat.entity.ChatUser;
import com.stylesmile.chat.mapper.ChatUserMapper;
import com.stylesmile.chat.service.ChatUserService;
import com.stylesmile.chat.service.ChatVerifyCodeService;
import com.stylesmile.chat.shard.MessageShardRouter;
import com.stylesmile.chat.shard.MessageShardSchemaService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import javax.annotation.Resource;
import java.util.List;

/**
 * 聊天用户服务实现
 *
 * @author chenye
 * @date 2018/12/10
 */
@Service
public class ChatUserServiceImpl extends BaseServiceImpl<ChatUserMapper, ChatUser> implements ChatUserService {

    private static final Logger log = LoggerFactory.getLogger(ChatUserServiceImpl.class);

    @Resource
    private ChatVerifyCodeService verifyCodeService;
    @Resource
    private MessageShardRouter shardRouter;
    @Resource
    private MessageShardSchemaService shardSchemaService;

    /**
     * 注册成功后预建该用户的私聊消息分表。
     *
     * <p>建表失败<b>不影响注册成功</b>：分表在首次发消息时还会兜底再建一次，
     * 这里只是把 DDL 提前，避免第一条消息卡在 DDL 上。
     *
     * @param userId 新用户 ID
     */
    private void ensureMessageShardTable(Long userId) {
        try {
            if (!shardRouter.isShardEnabled()) {
                return;
            }
            shardSchemaService.ensureFriendTableForUser(shardRouter, userId);
        } catch (Exception e) {
            log.error("预建消息分表失败，userId={}（首次发消息时会重试）", userId, e);
        }
    }

    @Override
    public ChatUser getUserByUsername(String username) {
        return baseMapper.getUserByUsername(username);
    }

    @Override
    public ChatUser getUserById(Long userId) {
        return getById(userId);
    }

    /**
     * 通过邮箱查询用户（用于找回密码流程）
     */
    @Override
    public ChatUser getUserByEmail(String email) {
        return lambdaQuery()
                .eq(ChatUser::getEmail, email)
                .one();
    }

    @Override
    public Result login(String account, String password) {
        // 优先按用户名查询；查不到则按邮箱查询（支持邮箱登录）
        // First try username lookup; if not found, try email lookup (supports email login)
//        ChatUser user = baseMapper.getUserByUsername(account);
        ChatUser user = getUserByEmail(account);
//        if (user == null) {
//            user = getUserByEmail(account);
//        }
        if (null == user) {
            return Result.failMessage("用户不存在");
        }
        // 密码哈希规则：md5(密码) 与注册时保持一致
        // Password hash: md5(password), consistent with registration
        String hashedPassword = SecureUtil.md5(password);
        if (!user.getPassword().equals(hashedPassword)) {
            return Result.failMessage("用户名或者密码错误");
        }
        return Result.success(user);
    }

    @Override
    public int countOnlineUsers() {
        return Math.toIntExact(lambdaQuery().eq(ChatUser::getStatus, "online").count());
    }

    /**
     * 注册新用户：邮箱必填，需验证码校验
     * 注册成功后邮箱存入用户记录，密码用 md5(password) 加密
     */
    @Override
    public Result register(String username, String password, String nickname, String email, String code) {
        // 校验邮箱不能为空
        if (email == null || email.trim().isEmpty()) {
            return Result.failMessage("邮箱不能为空");
        }
        email = email.trim();

        // 校验用户名不能为空
        if (username == null || username.trim().isEmpty()) {
            return Result.failMessage("用户名不能为空");
        }

        // 检查用户名是否已存在
        ChatUser existingUser = baseMapper.getUserByUsername(username);
        if (existingUser != null) {
            return Result.failMessage("用户名已存在");
        }

        // 检查邮箱是否已被其他用户注册
        ChatUser userByEmail = lambdaQuery().eq(ChatUser::getEmail, email).one();
        if (userByEmail != null) {
            return Result.failMessage("邮箱已被注册");
        }

        // 校验邮箱验证码（验证后立即标记为已使用）
        if (!verifyCodeService.verifyCode(email, code, "register")) {
            return Result.failMessage("验证码错误或已过期");
        }

        // 密码哈希：md5(password)，与登录逻辑保持一致
        String hashedPassword = SecureUtil.md5(password);

        // 创建新用户并设置默认值
        ChatUser newUser = new ChatUser(username, hashedPassword);
        newUser.setNickname(nickname != null && !nickname.isEmpty() ? nickname : username);
        newUser.setEmail(email);
        newUser.setStatus("offline");
        newUser.setAvatar("");
        newUser.setSignature("");
        newUser.setId(IdUtil.getSnowflakeNextId());
        save(newUser);

        // 消息分表：新用户注册即预建他所在的私聊消息表，
        // 避免第一条私聊消息到来时才建表（DDL 混在发消息事务里）
        ensureMessageShardTable(newUser.getId());

        return Result.success(newUser);
    }

    /**
     * 通过邮箱+验证码重置密码
     * 流程：校验验证码 → 查找用户 → 更新密码（md5(newPassword)）
     */
    @Override
    public Result resetPasswordByEmail(String email, String code, String newPassword) {
        // 参数校验
        if (email == null || email.trim().isEmpty()) {
            return Result.failMessage("邮箱不能为空");
        }
        if (newPassword == null || newPassword.trim().isEmpty()) {
            return Result.failMessage("新密码不能为空");
        }

        email = email.trim();

        // 校验验证码（验证后立即标记为已使用）
        if (!verifyCodeService.verifyCode(email, code, "reset_password")) {
            return Result.failMessage("验证码错误或已过期");
        }

        // 查找对应用户
        ChatUser user = getUserByEmail(email);
        if (user == null) {
            return Result.failMessage("该邮箱未注册账号");
        }

        // 更新密码：md5(newPassword)
        user.setPassword(SecureUtil.md5(newPassword));
        updateById(user);
        return Result.success();
    }

    /**
     * 模糊搜索用户（匹配 username 或 nickname）
     */
    @Override
    public List<ChatUser> searchUsers(String keyword) {
        if (keyword == null || keyword.trim().isEmpty()) {
            return List.of();
        }
        return baseMapper.searchUsers(keyword.trim());
    }
}
