package com.stylesmile.chat.shard;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.regex.Pattern;

/**
 * 消息分表的 DDL 维护：按需建表。
 *
 * <p>建表语句固定为 {@code CREATE TABLE IF NOT EXISTS <分表> LIKE chat_message} ——
 * 用 LIKE 而不是手写一份 DDL，好处是分表结构永远跟主表一致：
 * 以后给 chat_message 加列（Flyway 迁移），新建的分表自动带上，不用同步改第二处。
 *
 * <p>已经确认存在的表会记在内存 Set 里，避免每个请求都发一次 DDL。
 * MySQL 的 {@code CREATE TABLE IF NOT EXISTS} 本身也不是并发安全的
 * （两个连接同时建同一张表可能报 1050 或触发元数据锁等待），
 * 所以这里对已存在的表直接返回，未缓存的才去建，并对"已存在"异常做兜底忽略。
 *
 * @author mmm
 */
@Service
public class MessageShardSchemaService {

    private static final Logger log = LoggerFactory.getLogger(MessageShardSchemaService.class);

    /** 建表结构模板（主表） */
    private static final String TEMPLATE_TABLE = "chat_message";

    /**
     * 合法表名：只允许 chat_message_ 开头 + 字母数字下划线。
     * 表名虽然都是本类自己算出来的，但多一层校验能在拼接进 DDL 前挡住任何意外值。
     */
    private static final Pattern SAFE_TABLE_NAME = Pattern.compile("^chat_message_[A-Za-z0-9_]+$");

    private final JdbcTemplate jdbcTemplate;

    /** 已确认存在的分表（进程内缓存） */
    private final Set<String> existingTables = ConcurrentHashMap.newKeySet();

    public MessageShardSchemaService(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    /**
     * 确保某个用户所在的私聊分表存在（注册成功后调用）。
     *
     * @param router 路由组件
     * @param userId 用户 ID
     * @return 表名
     */
    public String ensureFriendTableForUser(MessageShardRouter router, Long userId) {
        return ensureTableByName(router.friendTableOfUser(userId));
    }

    /**
     * 确保某个群的群消息分表存在（建群成功后调用）。
     *
     * @param router  路由组件
     * @param groupId 群 ID
     * @return 表名
     */
    public String ensureGroupTable(MessageShardRouter router, Long groupId) {
        return ensureTableByName(router.groupTable(groupId));
    }

    /**
     * 确保分表存在并把表名原样返回（方便调用方链式使用）。
     *
     * @param table 表名
     * @return 同一个表名
     */
    public String ensureTableByName(String table) {
        ensureTable(table);
        return table;
    }

    /**
     * 确保分表存在（幂等）。
     *
     * @param table 表名（必须匹配 {@link #SAFE_TABLE_NAME}）
     */
    public void ensureTable(String table) {
        if (table == null || !SAFE_TABLE_NAME.matcher(table).matches()) {
            throw new IllegalArgumentException("非法的分表表名: " + table);
        }
        if (existingTables.contains(table)) {
            return;
        }
        try {
            jdbcTemplate.execute("CREATE TABLE IF NOT EXISTS `" + table + "` LIKE `" + TEMPLATE_TABLE + "`");
            existingTables.add(table);
            log.info("消息分表就绪: {}", table);
        } catch (Exception e) {
            // 并发下另一个实例可能刚建完，IF NOT EXISTS 之外的竞态在这里兜底：
            // 直接查一次 information_schema 确认，确认存在就当成功。
            if (tableExists(table)) {
                existingTables.add(table);
                log.info("消息分表已由其他实例创建: {}", table);
                return;
            }
            throw new IllegalStateException("创建消息分表失败: " + table, e);
        }
    }

    /**
     * 查 information_schema 判断表是否存在。
     *
     * @param table 表名
     * @return 存在返回 true
     */
    private boolean tableExists(String table) {
        try {
            Integer count = jdbcTemplate.queryForObject(
                    "SELECT COUNT(*) FROM information_schema.tables "
                            + "WHERE table_schema = DATABASE() AND table_name = ?",
                    Integer.class, table);
            return count != null && count > 0;
        } catch (Exception e) {
            log.warn("检查分表是否存在失败: {}", table, e);
            return false;
        }
    }

    /**
     * 清空"已建表"缓存（测试或运维手动删表后调用，强制下次重新建）。
     */
    public void resetCache() {
        existingTables.clear();
    }
}
