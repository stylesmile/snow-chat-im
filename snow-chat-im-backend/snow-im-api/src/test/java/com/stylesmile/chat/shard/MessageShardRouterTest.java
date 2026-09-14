package com.stylesmile.chat.shard;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * 消息分表路由的单元测试。
 *
 * <p>这里锁死的是「同一会话必须永远算出同一张表」—— 一旦规则漂移，
 * 历史消息就会凭空消失（查的是另一张空表），而且没有任何报错，
 * 是最难排查的一类故障，所以把各种组合都钉住。
 */
class MessageShardRouterTest {

    private static MessageShardRouter router(int usersPerTable, int groupsPerTable) {
        MessageShardProperties props = new MessageShardProperties();
        props.setUsersPerTable(usersPerTable);
        props.setGroupsPerTable(groupsPerTable);
        return new MessageShardRouter(props);
    }

    private static final MessageShardRouter DEFAULT = router(1000, 100);

    @Test
    void friendShardKeyIsTheSmallerUserId() {
        assertEquals(10L, DEFAULT.friendShardKey(10L, 42L));
        assertEquals(10L, DEFAULT.friendShardKey(42L, 10L));
        // 文件传输助手：收发都是自己
        assertEquals(7L, DEFAULT.friendShardKey(7L, 7L));
    }

    @Test
    void friendTableUsesMinUserId() {
        assertEquals("chat_message_friend_0", DEFAULT.friendTable(10L, 42L));
        assertEquals("chat_message_friend_0", DEFAULT.friendTable(999L, 1L));
        // 1000 起进入下一张表
        assertEquals("chat_message_friend_1", DEFAULT.friendTable(1000L, 1001L));
        assertEquals("chat_message_friend_2", DEFAULT.friendTable(2500L, 3000L));
        // 决定分片的是较小的那个 ID，不是第一个参数：min(2500,3)=3 → 第 0 张
        assertEquals("chat_message_friend_0", DEFAULT.friendTable(2500L, 3L));
    }

    @Test
    void friendTableIsSymmetricForBothSides() {
        // 收发双方必须算出同一张表，否则消息只能被一方看到
        for (long a : new long[]{1L, 999L, 1000L, 12345L, 2091818653023719424L}) {
            for (long b : new long[]{2L, 1001L, 2091818653023719423L}) {
                assertEquals(DEFAULT.friendTable(a, b), DEFAULT.friendTable(b, a),
                        "双方算出的表必须一致: " + a + " <-> " + b);
            }
        }
    }

    @Test
    void friendTableHandlesSnowflakeIds() {
        // 线上真实的雪花 ID 远超 int 范围，除法必须按 long 走
        assertEquals("chat_message_friend_2091818653023719",
                DEFAULT.friendTable(2091818653023719424L, 2091818653023719425L));
    }

    @Test
    void groupTableUsesGroupId() {
        assertEquals("chat_message_group_0", DEFAULT.groupTable(7L));
        assertEquals("chat_message_group_0", DEFAULT.groupTable(99L));
        assertEquals("chat_message_group_1", DEFAULT.groupTable(100L));
        assertEquals("chat_message_group_10", DEFAULT.groupTable(1099L));
    }

    @Test
    void tableForRoutesByTargetType() {
        // 群 → 群表；私聊/文件助手 → 私聊表
        assertEquals("chat_message_group_0", DEFAULT.tableFor("group", 10L, 42L));
        assertEquals("chat_message_friend_0", DEFAULT.tableFor("friend", 10L, 42L));
        assertEquals("chat_message_friend_0", DEFAULT.tableFor("file_helper", 10L, 10L));
        // 大小写不敏感
        assertEquals("chat_message_group_0", DEFAULT.tableFor("GROUP", 10L, 42L));
    }

    @Test
    void tableForRouteRestoresTableFromRouteRecord() {
        assertEquals("chat_message_friend_0", DEFAULT.tableForRoute("friend", 10L));
        assertEquals("chat_message_friend_1", DEFAULT.tableForRoute("friend", 1500L));
        assertEquals("chat_message_group_1", DEFAULT.tableForRoute("group", 150L));
    }

    @Test
    void friendTableOfUserMatchesFriendTableWhenUserIsSmaller() {
        // 注册时只知道自己 id，建的表必须和"自己作为较小一方"时的表一致
        assertEquals(DEFAULT.friendTable(42L, 100L), DEFAULT.friendTableOfUser(42L));
    }

    @Test
    void customShardSizeIsHonoured() {
        MessageShardRouter r = router(2, 5);
        assertEquals("chat_message_friend_0", r.friendTable(0L, 1L));
        assertEquals("chat_message_friend_1", r.friendTable(2L, 3L));
        assertEquals("chat_message_group_1", r.groupTable(5L));
        assertEquals("chat_message_group_2", r.groupTable(10L));
    }

    @Test
    void nullArgumentsAreRejected() {
        assertThrows(IllegalArgumentException.class, () -> DEFAULT.groupTable(null));
        assertThrows(IllegalArgumentException.class, () -> DEFAULT.friendTableOfUser(null));
        assertThrows(IllegalArgumentException.class, () -> DEFAULT.friendTableByShardKey(null));
    }

    @Test
    void shardEnabledFollowsProperties() {
        assertTrue(DEFAULT.isShardEnabled(), "默认应启用分表");

        MessageShardProperties off = new MessageShardProperties();
        off.setEnabled(false);
        MessageShardRouter r = new MessageShardRouter(off);
        assertFalse(r.isShardEnabled());
        assertEquals("chat_message", r.mainTable());
    }

    @Test
    void invalidShardSizeIsRejected() {
        MessageShardProperties props = new MessageShardProperties();
        assertThrows(IllegalArgumentException.class, () -> props.setUsersPerTable(0));
        assertThrows(IllegalArgumentException.class, () -> props.setGroupsPerTable(-1));
    }
}
