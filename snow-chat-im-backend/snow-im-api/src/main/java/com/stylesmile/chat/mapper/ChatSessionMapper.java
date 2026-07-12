package com.stylesmile.chat.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.stylesmile.chat.entity.ChatSession;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

import java.util.List;

/**
 * 会话 mapper
 *
 * @author chenye
 * @date 2018/12/10
 */
@Mapper
public interface ChatSessionMapper extends BaseMapper<ChatSession> {

    /**
     * 查询用户的会话列表
     *
     * @param userId 用户ID
     * @return 会话列表
     */
    List<ChatSession> getSessionsByUserId(@Param("userId") Integer userId);

    /**
     * 查询或创建会话
     *
     * @param userId     用户ID
     * @param targetId   目标ID
     * @param targetType 目标类型
     * @return 会话
     */
    ChatSession getOrCreateSession(@Param("userId") Integer userId,
                                   @Param("targetId") Integer targetId,
                                   @Param("targetType") String targetType);

    /**
     * 更新最后一条消息
     *
     * @param userId     用户ID
     * @param targetId   目标ID
     * @param targetType 目标类型
     * @param lastMsg    最后一条消息
     */
    void updateLastMessage(@Param("userId") Integer userId,
                           @Param("targetId") Integer targetId,
                           @Param("targetType") String targetType,
                           @Param("lastMsg") String lastMsg);

    /**
     * 清除未读数
     *
     * @param userId     用户ID
     * @param targetId   目标ID
     */
    void clearUnreadCount(@Param("userId") Integer userId,
                          @Param("targetId") Integer targetId);
}
