package com.stylesmile.chat.service;

import com.stylesmile.common.service.BaseService;
import com.stylesmile.chat.entity.ChatSession;

import java.util.List;

/**
 * 会话服务
 *
 * @author chenye
 * @date 2018/12/10
 */
public interface ChatSessionService extends BaseService<ChatSession> {

    /**
     * 查询用户的会话列表
     *
     * @param userId 用户ID
     * @return 会话列表
     */
    List<ChatSession> getSessionsByUserId(Long userId);

    /**
     * 查询或创建会话
     *
     * @param userId     用户ID
     * @param targetId   目标ID
     * @param targetType 目标类型
     * @return 会话
     */
    ChatSession getOrCreateSession(Long userId, Long targetId, String targetType);

    /**
     * 更新最后一条消息
     *
     * @param userId     用户ID
     * @param targetId   目标ID
     * @param targetType 目标类型
     * @param lastMsg    最后一条消息
     */
    void updateLastMessage(Long userId, Long targetId, String targetType, String lastMsg);

    /**
     * 清除未读数
     *
     * @param userId     用户ID
     * @param targetId   目标ID
     */
    void clearUnreadCount(Long userId, Long targetId);
}
