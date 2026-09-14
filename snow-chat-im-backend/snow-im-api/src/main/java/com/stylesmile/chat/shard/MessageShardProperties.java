package com.stylesmile.chat.shard;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * 消息分表配置（{@code chat.message.shard}）。
 *
 * <p>两个"每表多少个"的分片粒度都可以在 yml 里改：
 * <pre>
 * chat:
 *   message:
 *     shard:
 *       enabled: true
 *       users-per-table: 1000   # 每 1000 个用户 ID 一张私聊消息表
 *       groups-per-table: 100   # 每 100 个群一张群消息表
 * </pre>
 *
 * <p>⚠️ 一旦上线后不要轻易改这两个值：分片号 = {@code id / 粒度}，
 * 改了之后同样的 ID 会落到另一张表，历史消息全部"查不到"。
 * 真要调整粒度必须做一次全量重分布（把所有分表数据读出来按新粒度重写）。
 *
 * @author mmm
 * @see MessageShardRouter
 */
@ConfigurationProperties(prefix = "chat.message.shard")
public class MessageShardProperties {

    /** 是否启用分表；关闭时所有消息回到 chat_message 主表 */
    private boolean enabled = true;

    /** 私聊消息：每多少个用户 ID 一张表 */
    private int usersPerTable = 1000;

    /** 群聊消息：每多少个群一张表 */
    private int groupsPerTable = 100;

    public boolean isEnabled() {
        return enabled;
    }

    public void setEnabled(boolean enabled) {
        this.enabled = enabled;
    }

    public int getUsersPerTable() {
        return usersPerTable;
    }

    public void setUsersPerTable(int usersPerTable) {
        if (usersPerTable <= 0) {
            throw new IllegalArgumentException("chat.message.shard.users-per-table 必须大于 0");
        }
        this.usersPerTable = usersPerTable;
    }

    public int getGroupsPerTable() {
        return groupsPerTable;
    }

    public void setGroupsPerTable(int groupsPerTable) {
        if (groupsPerTable <= 0) {
            throw new IllegalArgumentException("chat.message.shard.groups-per-table 必须大于 0");
        }
        this.groupsPerTable = groupsPerTable;
    }
}
