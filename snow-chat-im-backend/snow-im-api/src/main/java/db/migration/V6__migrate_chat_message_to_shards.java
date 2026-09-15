package db.migration;

import org.flywaydb.core.api.migration.BaseJavaMigration;
import org.flywaydb.core.api.migration.Context;

import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.List;

/**
 * 把 chat_message 里的历史消息按分片规则搬到分表，并补齐路由记录。
 *
 * <p>为什么必须用 Java 迁移而不是 SQL：需要按「现有数据里出现了哪些分片」动态建表
 * （{@code CREATE TABLE ... LIKE chat_message}）再逐表搬运，SQL 迁移写不了这种循环。
 *
 * <p>分片粒度这里用常量（{@link #USERS_PER_TABLE} / {@link #GROUPS_PER_TABLE}），因为 Flyway
 * 迁移跑在 Spring 上下文之前，读不到 {@code chat.message.shard.*}。
 * <b>如果 yml 里的粒度改过，需要同步改这里的常量后重跑一次全量重分布。</b>
 *
 * <p>主表数据<b>保留不删</b>：分表上线后查询一律走分表，主表只作为结构模板
 * （新分表由 {@code CREATE TABLE LIKE chat_message} 生成），
 * 残留的历史行相当于一份回滚备份，确认无误后可自行清理。
 */
public class V6__migrate_chat_message_to_shards extends BaseJavaMigration {

    /** 私聊分片粒度，与 application.yml 的 chat.message.shard.users-per-table 保持一致 */
    private static final long USERS_PER_TABLE = 1000L;

    /** 群聊分片粒度，与 application.yml 的 chat.message.shard.groups-per-table 保持一致 */
    private static final long GROUPS_PER_TABLE = 100L;

    /** 主表名（同时是分表的结构模板） */
    private static final String MAIN_TABLE = "chat_message";

    @Override
    public Integer getChecksum() {
        return null; // 交给 Flyway 按类名+内容自己算
    }

    @Override
    public void migrate(Context context) throws Exception {
        Connection conn = context.getConnection();
        try (Statement stmt = conn.createStatement()) {
            // 群聊：按 group_id 分片
            for (Long shard : queryShards(stmt,
                    "SELECT DISTINCT group_id DIV " + GROUPS_PER_TABLE
                            + " FROM " + MAIN_TABLE + " WHERE group_id IS NOT NULL")) {
                String table = "chat_message_group_" + shard;
                createTableLike(stmt, table);
                insertFrom(stmt, table, "group_id IS NOT NULL AND group_id DIV " + GROUPS_PER_TABLE + " = " + shard);
                fillRoute(stmt, table);
            }

            // 私聊（含 file_helper）：按 min(双方用户ID) 分片
            for (Long shard : queryShards(stmt,
                    "SELECT DISTINCT LEAST(from_user_id, COALESCE(to_user_id, from_user_id)) DIV " + USERS_PER_TABLE
                            + " FROM " + MAIN_TABLE + " WHERE group_id IS NULL")) {
                String table = "chat_message_friend_" + shard;
                createTableLike(stmt, table);
                insertFrom(stmt, table,
                        "group_id IS NULL AND LEAST(from_user_id, COALESCE(to_user_id, from_user_id)) DIV "
                                + USERS_PER_TABLE + " = " + shard);
                fillRoute(stmt, table);
            }
        }
    }

    /**
     * 按 SQL 查出所有出现过的分片号。
     */
    private List<Long> queryShards(Statement stmt, String sql) throws Exception {
        List<Long> shards = new ArrayList<>();
        try (ResultSet rs = stmt.executeQuery(sql)) {
            while (rs.next()) {
                shards.add(rs.getLong(1));
            }
        }
        return shards;
    }

    /**
     * 以主表为模板建分表（结构、索引、列注释全部继承）。
     */
    private void createTableLike(Statement stmt, String table) throws Exception {
        stmt.execute("CREATE TABLE IF NOT EXISTS `" + table + "` LIKE `" + MAIN_TABLE + "`");
    }

    /**
     * 把符合条件的历史行搬进分表（id 原样保留，避免与路由对不上）。
     */
    private void insertFrom(Statement stmt, String table, String where) throws Exception {
        stmt.execute("INSERT IGNORE INTO `" + table + "`"
                + " (id, from_user_id, to_user_id, group_id, type, content, local_seq, status, create_time, push_status)"
                + " SELECT id, from_user_id, to_user_id, group_id, type, content, local_seq, status, create_time, push_status"
                + " FROM `" + MAIN_TABLE + "` WHERE " + where);
    }

    /**
     * 为刚搬进分表的消息补写路由记录。
     */
    private void fillRoute(Statement stmt, String table) throws Exception {
        stmt.execute("INSERT IGNORE INTO chat_message_route (id, target_type, shard_key, create_time)"
                + " SELECT id,"
                + "   CASE WHEN group_id IS NOT NULL THEN 'group'"
                + "        WHEN type = 'self' THEN 'file_helper'"
                + "        ELSE 'friend' END,"
                + "   CASE WHEN group_id IS NOT NULL THEN group_id"
                + "        ELSE LEAST(from_user_id, COALESCE(to_user_id, from_user_id)) END,"
                + "   NOW()"
                + " FROM `" + table + "`");
    }
}
