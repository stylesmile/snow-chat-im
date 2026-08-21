package com.stylesmile.chat.service;

import com.stylesmile.common.service.BaseService;
import com.stylesmile.common.util.Result;
import com.stylesmile.chat.entity.ChatUser;

/**
 * 聊天用户服务
 *
 * @author chenye
 * @date 2018/12/10
 */
public interface ChatUserService extends BaseService<ChatUser> {

    /**
     * 通过用户名查询用户
     *
     * @param username 用户名
     * @return ChatUser
     */
    ChatUser getUserByUsername(String username);

    /**
     * 通过ID查询用户
     *
     * @param userId 用户ID
     * @return ChatUser
     */
    ChatUser getUserById(Integer userId);

    /**
     * 通过邮箱查询用户
     *
     * @param email 邮箱
     * @return ChatUser
     */
    ChatUser getUserByEmail(String email);

    /**
     * 用户登录
     *
     * @param username 用户名
     * @param password 密码（未加密的明文）
     * @return Result
     */
    Result login(String username, String password);

    /**
     * 统计在线用户数
     *
     * @return int
     */
    int countOnlineUsers();

    /**
     * 用户注册（需邮箱验证码校验）
     *
     * @param username 用户名
     * @param password 密码
     * @param nickname 昵称
     * @param email    邮箱（必填）
     * @param code     邮箱验证码
     * @return Result
     */
    Result register(String username, String password, String nickname, String email, String code);

    /**
     * 通过邮箱重置密码
     *
     * @param email    注册时使用的邮箱
     * @param code     邮箱验证码
     * @param newPassword 新密码
     * @return Result
     */
    Result resetPasswordByEmail(String email, String code, String newPassword);
}
