package com.stylesmile.chat.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.stylesmile.chat.entity.ChatFriendRequest;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

import java.util.List;

/**
 * 好友请求 mapper
 *
 * @author chenye
 * @date 2018/12/10
 */
@Mapper
public interface ChatFriendRequestMapper extends BaseMapper<ChatFriendRequest> {

    /**
     * 查询待处理的好友请求
     *
     * @param toUserId 接收人ID
     * @return 好友请求列表
     */
    List<ChatFriendRequest> getPendingRequests(@Param("toUserId") Integer toUserId);
}
