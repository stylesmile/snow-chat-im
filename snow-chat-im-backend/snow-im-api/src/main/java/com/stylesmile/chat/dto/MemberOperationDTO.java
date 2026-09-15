package com.stylesmile.chat.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Data;


/**
 * 群组成员操作DTO类
 *
 * 这个类封装了群组成员管理操作所需的信息。
 * 支持的操作类型：
 *
 * 1. 添加成员（ADD）：
 *    - 验证操作者是否有权限添加成员
 *    - 验证被添加的用户是否已经存在
 *    - 发送邀请通知给被添加的用户
 *    - 更新群组成员列表
 *
 * 2. 删除成员（REMOVE）：
 *    - 验证操作者是否有权限删除成员
 *    - 不能删除群主（除非转让群主）
 *    - 发送通知给被删除的成员
 *    - 更新群组成员列表
 *
 * 3. 批量禁言（MUTE）：
 *    - 验证操作者是否有权限禁言
 *    - 记录禁言时长和原因
 *    - 限制被禁言成员的发言权限
 *
 * 4. 批量解禁（UNMUTE）：
 *    - 验证操作者是否有权限解禁
 *    - 恢复被禁言成员的发言权限
 *
 * 设计考虑：
 * - 支持批量操作，提高效率
 * - 使用数组存储用户ID，支持一次操作多个用户
 * - 简化API，减少网络请求
 *
 * @author Snow Chat Team
 * @version 1.0.0
 * @since 2026-01-01
 */
@Data
@Schema(description = "群组成员操作DTO")
public class MemberOperationDTO {
    /**
     * 群组ID - 被操作的群组
     *
     * 这个字段标识要进行成员管理操作的群组。
     * 所有成员管理操作都必须指定目标群组。
     *
     * 业务规则：
     * - 群组必须存在
     * - 操作者必须是该群组的成员
     * - 操作者必须具有相应的权限（群主或管理员）
     *
     * 权限矩阵：
     * | 操作     | 群主 | 管理员 | 普通成员 |
     * |---------|------|--------|----------|
     * | 添加成员 | ✓    | ✓      | ✗        |
     * | 删除成员 | ✓    | ✓      | ✗        |
     * | 禁言     | ✓    | ✓      | ✗        |
     * | 解禁     | ✓    | ✓      | ✗        |
     * | 转让群主 | ✓    | ✗      | ✗        |
     *
     * 数据库映射：对应chat_group表的id字段
     * 约束：不能为null，必须是有效的群组ID
     *
     * 错误处理：
     * - 如果群组不存在，抛出GroupNotFoundException
     * - 如果操作者不是群组成员，抛出PermissionDeniedException
     * - 如果操作者权限不足，抛出InsufficientPermissionException
     */
    @Schema(description = "群组ID", example = "1001", requiredMode = Schema.RequiredMode.REQUIRED)
    private Long groupId;
    /**
     * 用户ID数组 - 被操作的用户列表
     *
     * 这个字段存储要进行操作的用户ID列表。
     * 使用数组而不是单个用户ID的原因：
     *
     * 1. 支持批量操作：
     *    - 一次请求可以添加/删除多个成员
     *    - 减少网络请求次数，提高效率
     *    - 降低服务器负载
     *
     * 2. 简化客户端逻辑：
     *    - 客户端可以一次性选择多个用户
     *    - 不需要循环发送多个请求
     *    - 提供更好的用户体验
     *
     * 3. 事务性保证：
     *    - 所有操作可以在一个事务中完成
     *    - 要么全部成功，要么全部失败
     *    - 避免部分成功的情况
     *
     * 数据库映射：
     * - 不直接映射到数据库字段
     * - 在服务层拆分为多条记录
     *
     * 约束：
     * - 不能为null
     * - 不能为空数组
     * - 最大长度：100（防止DoS攻击）
     * - 数组中的每个用户ID必须有效
     *
     * 验证逻辑：
     * 1. 检查数组是否为空
     * 2. 检查数组长度是否超过限制
     * 3. 验证每个用户ID是否存在
     * 4. 检查用户是否已经是群组成员（添加时）
     * 5. 检查用户是否是群组成员（删除时）
     *
     * 示例：
     * ```java
     * MemberOperationDTO dto = new MemberOperationDTO();
     * dto.setGroupId(1001L);
     * dto.setUserIds(new Long[]{2001L, 2002L, 2003L}); // 添加3个新成员
     * ```
     */
    @Schema(description = "用户ID数组", example = "[2001, 2002, 2003]")
    private Long[] userIds;
}
