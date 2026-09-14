package com.stylesmile.chat.shard;

import org.springframework.stereotype.Component;

/**
 * 消息分表路由：把「会话」映射到具体的物理表名。
 *
 * <h3>分片规则</h3>
 * <ul>
 *   <li>群聊：{@code chat_message_group_{groupId / groupsPerTable}}</li>
 *   <li>私聊：{@code chat_message_friend_{min(fromUserId, toUserId) / usersPerTable}}</li>
 * </ul>
 *
 * <h3>为什么私聊用 min(双方 ID)</h3>
 * <p>一条私聊消息只存<b>一份</b>，收发双方查的是同一行，因此分片键必须对双方一致 ——
 * 用 {@code min(a, b)} 就能保证 A→B 和 B→A 算出同一张表。
 * 另一种做法是"写扩散"（收发双方各存一份，各自落在自己的表里），
 * 但那样插入/撤回都要写两遍，且历史数据要翻倍迁移，这里没采用。
 *
 * <p>"文件传输助手"是发给自己的消息（{@code type=self}、toUserId == fromUserId），
 * min 就是自己，自然落到 {@code chat_message_friend_{userId / usersPerTable}}。
 *
 * @author mmm
 * @see MessageShardProperties
 */
@Component
public class MessageShardRouter {

    /** 私聊（含文件助手）消息表前缀 */
    public static final String FRIEND_TABLE_PREFIX = "chat_message_friend_";

    /** 群聊消息表前缀 */
    public static final String GROUP_TABLE_PREFIX = "chat_message_group_";

    /** 未分表时的主表名（{@code chat.message.shard.enabled=false} 时使用） */
    public static final String MAIN_TABLE = "chat_message";

    private final MessageShardProperties properties;

    public MessageShardRouter(MessageShardProperties properties) {
        this.properties = properties;
    }

    /**
     * 私聊会话的分片键：双方用户 ID 中较小的那个。
     *
     * @param userIdA 一方用户 ID
     * @param userIdB 另一方用户 ID
     * @return 分片键（min）
     */
    public Long friendShardKey(Long userIdA, Long userIdB) {
        Long a = userIdA == null ? Long.MAX_VALUE : userIdA;
        Long b = userIdB == null ? Long.MAX_VALUE : userIdB;
        return Math.min(a, b);
    }

    /**
     * 私聊消息表名。
     *
     * @param userIdA 一方用户 ID
     * @param userIdB 另一方用户 ID
     * @return 形如 {@code chat_message_friend_1}
     */
    public String friendTable(Long userIdA, Long userIdB) {
        return friendTableByShardKey(friendShardKey(userIdA, userIdB));
    }

    /**
     * 按分片Key直接算私聊表名（路由表里存的就是 shardKey，从它还原表名）。
     *
     * @param shardKey {@link #friendShardKey} 的结果
     * @return 形如 {@code chat_message_friend_1}
     */
    public String friendTableByShardKey(Long shardKey) {
        if (shardKey == null) {
            throw new IllegalArgumentException("私聊分片 shardKey 不能为空");
        }
        return FRIEND_TABLE_PREFIX + (shardKey / properties.getUsersPerTable());
    }

    /**
     * 单个用户所在的表名（注册时预建表用）。
     *
     * <p>注意：这只是"该用户作为较小一方时"的表；和更大 ID 的用户聊天时同样落这张表，
     * 和更小 ID 的用户聊天时则落在对方那张。所以注册时只需建这一张即可覆盖
     * "以自己为分片键"的所有会话，其余组合由对方注册时保证。
     *
     * @param userId 用户 ID
     * @return 形如 {@code chat_message_friend_1}
     */
    public String friendTableOfUser(Long userId) {
        if (userId == null) {
            throw new IllegalArgumentException("userId 不能为空");
        }
        return FRIEND_TABLE_PREFIX + (userId / properties.getUsersPerTable());
    }

    /**
     * 群消息表名。
     *
     * @param groupId 群 ID
     * @return 形如 {@code chat_message_group_0}
     */
    public String groupTable(Long groupId) {
        if (groupId == null) {
            throw new IllegalArgumentException("groupId 不能为空");
        }
        return GROUP_TABLE_PREFIX + (groupId / properties.getGroupsPerTable());
    }

    /**
     * 按会话维度算表名（发送消息、拉历史时用）。
     *
     * @param targetType {@code group} / {@code friend} / {@code file_helper}
     * @param userId     当前用户 ID（私聊时用）
     * @param targetId   目标 ID（私聊=对方用户 ID，群聊=群 ID）
     * @return 物理表名
     */
    public String tableFor(String targetType, Long userId, Long targetId) {
        if ("group".equalsIgnoreCase(targetType)) {
            return groupTable(targetId);
        }
        // friend / file_helper 都存私聊表
        return friendTable(userId, targetId);
    }

    /**
     * 由路由记录还原表名（按 messageId 定位时用）。
     *
     * @param targetType 路由表里记录的会话类型
     * @param shardKey   路由表里记录的分片键（群=groupId，私聊=min(双方)）
     * @return 物理表名
     */
    public String tableForRoute(String targetType, Long shardKey) {
        if ("group".equalsIgnoreCase(targetType)) {
            return groupTable(shardKey);
        }
        return friendTableByShardKey(shardKey);
    }

    /**
     * 分表开关关闭时的兜底表名。
     *
     * @return {@code chat_message}
     */
    public String mainTable() {
        return MAIN_TABLE;
    }

    /**
     * 判断分表是否启用。
     *
     * @return 启用返回 true
     */
    public boolean isShardEnabled() {
        return properties.isEnabled();
    }
}
