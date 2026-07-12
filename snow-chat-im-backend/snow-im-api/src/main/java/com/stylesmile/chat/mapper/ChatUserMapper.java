package com.stylesmile.chat.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.stylesmile.chat.entity.ChatUser;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

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
}
