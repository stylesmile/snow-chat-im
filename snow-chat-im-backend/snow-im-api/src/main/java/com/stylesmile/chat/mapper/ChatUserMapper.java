package com.stylesmile.chat.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.stylesmile.chat.entity.ChatUser;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

import java.util.List;

/**
 * 聊天用户 mapper
 *
 * @author chenye
 * @date 2018/12/10
 */
@Mapper
public interface ChatUserMapper extends BaseMapper<ChatUser> {

    /**
     * 通过用户名查询用户
     *
     * @param username 用户名
     * @return ChatUser
     */
    ChatUser getUserByUsername(@Param("username") String username);

    /**
     * 模糊搜索用户（匹配 username 或 nickname）
     *
     * @param keyword 搜索关键词
     * @return 匹配的用户列表
     */
    List<ChatUser> searchUsers(@Param("keyword") String keyword);
}
