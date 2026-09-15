package com.stylesmile.chat.shard;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;

import java.util.ArrayList;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.contains;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * 分表 DDL 维护的单元测试。
 *
 * <p>关键点：
 * <ol>
 *   <li>建表语句必须是 {@code CREATE TABLE IF NOT EXISTS <分表> LIKE chat_message}
 *       —— 用 LIKE 才能保证分表结构与主表永远一致；</li>
 *   <li>已建过的表走内存缓存，不再重复发 DDL；</li>
 *   <li>表名不合法（拼进了意外字符）必须直接拒绝，因为表名会拼进 DDL。</li>
 * </ol>
 */
class MessageShardSchemaServiceTest {

    private JdbcTemplate jdbcTemplate;
    private MessageShardSchemaService schemaService;
    private MessageShardRouter router;

    /** 捕获所有执行过的 DDL，便于断言 */
    private final List<String> executed = new ArrayList<>();

    @BeforeEach
    @SuppressWarnings("unchecked")
    void setUp() {
        jdbcTemplate = mock(JdbcTemplate.class);
        // execute(String) 是 void 方法，用 thenAnswer 记录调用
        org.mockito.Mockito.doAnswer(invocation -> {
            executed.add(invocation.getArgument(0));
            return null;
        }).when(jdbcTemplate).execute(anyString());

        schemaService = new MessageShardSchemaService(jdbcTemplate);
        router = new MessageShardRouter(new MessageShardProperties());
    }

    @Test
    void createsTableLikeMainTable() {
        schemaService.ensureFriendTableForUser(router, 42L);

        assertEquals(1, executed.size());
        assertEquals("CREATE TABLE IF NOT EXISTS `chat_message_friend_0` LIKE `chat_message`",
                executed.get(0));
    }

    @Test
    void createsGroupTableOnGroupCreation() {
        assertEquals("chat_message_group_1", schemaService.ensureGroupTable(router, 150L));
        assertEquals("CREATE TABLE IF NOT EXISTS `chat_message_group_1` LIKE `chat_message`",
                executed.get(0));
    }

    @Test
    void onlyCreatesOncePerTable() {
        schemaService.ensureFriendTableForUser(router, 42L);
        schemaService.ensureFriendTableForUser(router, 43L);   // 同一张表
        schemaService.ensureFriendTableForUser(router, 42L);

        assertEquals(1, executed.size(), "同一张表只应发一次 DDL");
    }

    @Test
    void differentShardsCreateDifferentTables() {
        schemaService.ensureFriendTableForUser(router, 42L);
        schemaService.ensureFriendTableForUser(router, 1000L);

        assertEquals(2, executed.size());
        assertTrue(executed.get(1).contains("chat_message_friend_1"));
    }

    @Test
    void resetCacheForcesRecreation() {
        schemaService.ensureFriendTableForUser(router, 42L);
        schemaService.resetCache();
        schemaService.ensureFriendTableForUser(router, 42L);

        assertEquals(2, executed.size());
    }

    @Test
    void rejectsUnsafeTableName() {
        // 表名会拼进 DDL，任何不符合 chat_message_xxx 形态的值都必须拒绝
        assertThrows(IllegalArgumentException.class, () -> schemaService.ensureTable("chat_message"));
        assertThrows(IllegalArgumentException.class, () -> schemaService.ensureTable("users; DROP TABLE x"));
        assertThrows(IllegalArgumentException.class, () -> schemaService.ensureTable(null));
    }

    @Test
    void tolerateConcurrentCreationWhenTableAlreadyExists() {
        // 并发下两个实例同时建表：DDL 抛异常，但查 information_schema 确认已存在 → 视为成功
        doThrow(new RuntimeException("Table 'chat_message_friend_0' already exists"))
                .when(jdbcTemplate).execute(contains("chat_message_friend_0"));
        when(jdbcTemplate.queryForObject(contains("information_schema.tables"), eq(Integer.class),
                eq("chat_message_friend_0"))).thenReturn(1);

        schemaService.ensureFriendTableForUser(router, 42L);

        verify(jdbcTemplate, times(1)).queryForObject(contains("information_schema.tables"),
                eq(Integer.class), eq("chat_message_friend_0"));
    }

    @Test
    void rethrowsWhenTableReallyMissing() {
        doThrow(new RuntimeException("Access denied"))
                .when(jdbcTemplate).execute(contains("chat_message_friend_0"));
        when(jdbcTemplate.queryForObject(contains("information_schema.tables"), eq(Integer.class),
                eq("chat_message_friend_0"))).thenReturn(0);

        assertThrows(IllegalStateException.class,
                () -> schemaService.ensureFriendTableForUser(router, 42L));
    }
}
