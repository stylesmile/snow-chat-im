package com.stylesmile.chat.service.impl;

import com.stylesmile.common.service.BaseServiceImpl;
import com.stylesmile.chat.entity.ChatSession;
import com.stylesmile.chat.mapper.ChatSessionMapper;
import com.stylesmile.chat.service.ChatSessionService;
import org.springframework.stereotype.Service;

import java.util.Date;
import java.util.List;

/**
 * 会话服务实现
 *
 * @author chenye
 * @date 2018/12/10
 */
@Service
public class ChatSessionServiceImpl extends BaseServiceImpl<ChatSessionMapper, ChatSession> implements ChatSessionService {

    @Override
    public List<ChatSession> getSessionsByUserId(Integer userId) {
        return baseMapper.getSessionsByUserId(userId);
    }

    @Override
    public ChatSession getOrCreateSession(Integer userId, Integer targetId, String targetType) {
        ChatSession session = lambdaQuery()
                .eq(ChatSession::getUserId, userId)
                .eq(ChatSession::getTargetId, targetId)
                .eq(ChatSession::getTargetType, targetType)
                .one();
        if (session == null) {
            session = new ChatSession();
            session.setUserId(userId);
            session.setTargetId(targetId);
            session.setTargetType(targetType);
            session.setUnreadCount(0);
            session.setIsMuted(0);
            session.setUpdateTime(new Date());
            save(session);
        }
        return session;
    }

    @Override
    public void updateLastMessage(Integer userId, Integer targetId, String targetType, String lastMsg) {
        baseMapper.updateLastMessage(userId, targetId, targetType, lastMsg);
    }

    @Override
    public void clearUnreadCount(Integer userId, Integer targetId) {
        baseMapper.clearUnreadCount(userId, targetId);
    }
}
