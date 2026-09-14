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
    List<ChatMessage> getHistoryMessages(Long userId, Long targetId, String targetType, int page, int size);

    /**
     * 查询历史消息（游标分页，基于 messageId）
     */
    List<ChatMessage> getHistoryMessagesByCursor(Long userId, Long targetId, String targetType, Long beforeMessageId, int size);

    /**
     * 发送消息并广播
     */
    void sendMessage(ChatMessage message);

    /**
     * 只落库（按分片写入并登记路由），不做 MQTT 推送。
     *
     * <p>给"自己负责推送"的调用方用，例如建群时写入的系统通知 ——
     * 它们推的是自己构造的报文，不需要 sendMessage 那套收发双方会话与回执逻辑。
     *
     * <p>⚠️ 不要用继承来的 {@code save()}：那个走实体固定表名，会写进 chat_message 主表，
     * 分表之后消息就查不到了。
     *
     * @param message 消息实体
     */
    void saveMessage(ChatMessage message);

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
