package com.stylesmile.chat.service;

import com.stylesmile.common.service.BaseService;
import com.stylesmile.chat.entity.ChatMessage;

import java.util.List;

/**
 * 消息服务
 */
public interface ChatMessageService extends BaseService<ChatMessage> {

    /**
     * 查询历史消息（按时间倒序，最新在前）
     */
    List<ChatMessage> getHistoryMessages(Integer userId, Integer targetId, String targetType, int page, int size);

    /**
     * 查询历史消息（游标分页，基于 messageId）
     */
    List<ChatMessage> getHistoryMessagesByCursor(Integer userId, Integer targetId, String targetType, Integer beforeMessageId, int size);

    /**
     * 发送消息并广播
     */
    void sendMessage(ChatMessage message);

    /**
     * 撤回消息
     */
    void recallMessage(Long userId, Long messageId);

    /**
     * 标记为已读（按会话维度）
     */
    void markAsRead(Long userId, Long targetId, String targetType);

    /**
     * 处理接收方的消息回执：更新推送状态并通知发送方
     */
    void processReceipt(Long messageId, Long userId);

    /**
     * 查询未推送成功的消息（REST API 用，返回列表）
     */
    List<ChatMessage> getUndeliveredMessages(Long userId, Long targetId, String targetType);

    /**
     * 查询未推送成功的消息并推送给用户（MQTT 推送用）
     */
    void fetchAndPushUndelivered(Long userId, Long targetId, String targetType);
}
