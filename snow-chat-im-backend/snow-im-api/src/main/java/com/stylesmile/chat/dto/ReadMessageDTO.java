package com.stylesmile.chat.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/**
 * 消息已读DTO - 用于封装标记消息已读的请求数据
 */
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Schema(description = "消息已读请求DTO")
public class ReadMessageDTO {

    /**
     * 用户ID - 标记消息为已读的用户
     *
     * 这个字段标识哪个用户标记消息为已读。
     * 在已读回执系统中，只有消息的接收者才能标记消息为已读。
     *
     * 业务规则：
     * - 用户只能标记自己收到的消息为已读
     * - 如果用户尝试标记不是发给他的消息为已读，抛出PermissionDeniedException
     * - 系统会验证用户身份，防止伪造已读回执
     *
     * 数据库映射：对应chat_message_read表的user_id字段
     * 约束：不能为null，必须是有效的用户ID
     *
     * 验证逻辑：
     * 1. 检查用户是否存在
     * 2. 检查用户是否有权限标记该消息为已读
     * 3. 检查消息是否已经被标记为已读（避免重复处理）
     */
    @Schema(description = "用户ID", example = "1001")
    private Long userId;
    /**
     * 目标ID - 被标记为已读的消息或会话
     *
     * 这个字段根据targetType的不同而有不同的含义：
     *
     * 如果targetType是"message":
     * - 目标ID是消息ID
     * - 标记单条消息为已读
     * - 适用于用户滚动到特定消息时
     *
     * 如果targetType是"conversation":
     * - 目标ID是会话ID（私聊的对方用户ID或群组ID）
     * - 标记该会话的所有未读消息为已读
     * - 适用于用户打开聊天界面时
     *
     * 数据库映射：
     * - 如果是消息ID，对应chat_message表的id字段
     * - 如果是会话ID，对应chat_conversation表的id字段
     *
     * 约束：不能为null，必须是有效的消息或会话ID
     *
     * 性能优化：
     * - 优先使用会话级别的已读标记（批量更新）
     * - 只在必要时使用单条消息的已读标记
     */
    @Schema(description = "目标ID（消息ID或会话ID）", example = "5001")
    private Long targetId;
    /**
     * 目标类型 - 指示targetId的类型
     *
     * 这个字段用于区分targetId是消息ID还是会话ID。
     * 不同的类型有不同的处理逻辑：
     *
     * 支持的类型：
     * - "message": 标记单条消息为已读
     *   - 更新chat_message表的is_read字段
     *   - 创建chat_message_read记录
     *   - 通知发送者消息已被阅读
     *
     * - "conversation": 标记整个会话为已读
     *   - 批量更新所有未读消息为已读
     *   - 更新会话的最后阅读时间
     *   - 重新计算未读消息计数
     *
     * 数据库映射：不直接映射到数据库字段，仅用于业务逻辑判断
     *
     * 约束：不能为null，必须是"message"或"conversation"
     *
     * 为什么需要这个字段：
     * - 提高API的灵活性
     * - 支持不同的已读粒度
     * - 优化性能（批量更新 vs 单条更新）
     *
     * 示例：
     * ```java
     * ReadMessageDTO dto = new ReadMessageDTO();
     * dto.setUserId(1001L);
     * dto.setTargetId(5001L);
     * dto.setTargetType("conversation"); // 标记整个会话为已读
     * ```
     */
    @Schema(description = "目标类型：message=单条消息, conversation=整个会话", example = "conversation")
    private String targetType;
}
