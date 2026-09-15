package com.stylesmile.chat.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.conditions.update.LambdaUpdateWrapper;
import com.stylesmile.chat.entity.ChatSession;
import com.stylesmile.chat.mapper.ChatSessionMapper;
import com.stylesmile.chat.service.ChatSessionService;
import com.stylesmile.common.service.BaseServiceImpl;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Date;
import java.util.List;

/**
 * 会话服务实现
 */
@Service
public class ChatSessionServiceImpl extends BaseServiceImpl<ChatSessionMapper, ChatSession> implements ChatSessionService {

    @Override
    public List<ChatSession> getSessionsByUserId(Long userId) {
        LambdaQueryWrapper<ChatSession> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(ChatSession::getUserId, userId)
               .orderByDesc(ChatSession::getLastMsgTime)
               .orderByDesc(ChatSession::getUpdateTime);
        return baseMapper.selectList(wrapper);
    }

    @Override
    @Transactional
    public ChatSession getOrCreateSession(Long userId, Long targetId, String targetType) {
        LambdaQueryWrapper<ChatSession> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(ChatSession::getUserId, userId)
               .eq(ChatSession::getTargetId, targetId)
               .eq(ChatSession::getTargetType, targetType);
        ChatSession session = baseMapper.selectOne(wrapper);
        if (session != null) {
            return session;
        }
        session = new ChatSession();
        session.setUserId(userId);
        session.setTargetId(targetId);
        session.setTargetType(targetType);
        session.setUnreadCount(0);
        session.setCreateTime(new Date());
        session.setUpdateTime(new Date());
        baseMapper.insert(session);
        return session;
    }

    @Override
    @Transactional
    public void updateLastMessage(Long userId, Long targetId, String targetType, String lastMsg) {
        LambdaUpdateWrapper<ChatSession> wrapper = new LambdaUpdateWrapper<>();
        wrapper.eq(ChatSession::getUserId, userId)
               .eq(ChatSession::getTargetId, targetId)
               .eq(ChatSession::getTargetType, targetType)
               .set(ChatSession::getLastMsg, lastMsg)
               .set(ChatSession::getLastMsgTime, new Date())
               .setSql("unread_count = unread_count + 1")
               .set(ChatSession::getUpdateTime, new Date());
        int rows = baseMapper.update(null, wrapper);
        if (rows == 0) {
            ChatSession session = getOrCreateSession(userId, targetId, targetType);
            session.setLastMsg(lastMsg);
            session.setLastMsgTime(new Date());
            session.setUnreadCount(1);
            session.setUpdateTime(new Date());
            baseMapper.updateById(session);
        }
    }

    @Override
    @Transactional
    public void clearUnreadCount(Long userId, Long targetId) {
        LambdaUpdateWrapper<ChatSession> wrapper = new LambdaUpdateWrapper<>();
        wrapper.eq(ChatSession::getUserId, userId)
               .eq(ChatSession::getTargetId, targetId)
               .set(ChatSession::getUnreadCount, 0)
               .set(ChatSession::getUpdateTime, new Date());
        baseMapper.update(null, wrapper);
    }
}
