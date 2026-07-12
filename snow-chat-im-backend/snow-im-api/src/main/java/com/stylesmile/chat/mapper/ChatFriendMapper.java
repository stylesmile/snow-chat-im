package com.stylesmile.chat.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.stylesmile.chat.entity.ChatFriend;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

import java.util.List;

/**
 * 好友关系 mapper
 *
 * @author chenye
 * @date 2018/12/10
 */
@Mapper
public interface ChatFriendMapper extends BaseMapper<ChatFriend> {

    /**
     * 查询用户的好友列表
     *
     * @param userId 用户ID
     * @return 好友列表
     */
    List<ChatFriend> getFriendsByUserId(@Param("userId") Integer userId);

    /**
     * 查询两个用户是否为好友
     *
     * @param userId   用户ID
     * @param friendId 好友ID
     * @return 好友关系
     */
    ChatFriend getFriend(@Param("userId") Integer userId, @Param("friendId") Integer friendId);
}
