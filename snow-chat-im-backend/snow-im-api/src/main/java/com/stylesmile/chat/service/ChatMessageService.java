package com.stylesmile.chat.service;

import com.stylesmile.common.service.BaseService;
import com.stylesmile.chat.entity.ChatMessage;

import java.util.List;

/**
 * 消息服务
 *
 * @author chenye
 * @date 2018/12/10
 */
public interface ChatMessageService extends BaseService<ChatMessage> {

    /**
     * 查询历史消息
     *
     * @param userId     用户ID
     * @param targetId   目标ID
     * @param targetType 目标类型
     * @param page       页码
     * @param size       每页大小
     * @return 消息列表
     */
    List<ChatMessage> getHistoryMessages(Integer userId, Integer targetId, String targetType, int page, int size);

    /**
     * 发送消息
     *
     * @param message 消息
     */
    void sendMessage(ChatMessage message);

    /**
     * 撤回消息
     *
     * @param userId    用户ID
     * @param messageId 消息ID
     */
    void recallMessage(Integer userId, Long messageId);

    /**
     * 标记为已读
     *
     * @param userId     用户ID
     * @param targetId   目标ID
     * @param targetType 目标类型
     */
    void markAsRead(Integer userId, Integer targetId, String targetType);
}
