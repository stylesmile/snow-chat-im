package com.stylesmile.chat.entity;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DisplayName;

import java.util.Date;

import static org.junit.jupiter.api.Assertions.*;

/**
 * ChatSession实体类的单元测试
 *
 * 这个测试类验证ChatSession实体类的功能，包括：
 * 1. 对象创建和初始化
 * 2. getter/setter方法
 * 3. 字段值的有效性
 * 4. 边界条件测试
 *
 * 测试覆盖范围：
 * - 所有字段的getter/setter
 * - 无参构造函数
 * - 对象的创建和初始化
 * - 字段的默认值
 * - 边界值测试
 *
 * @author Snow Chat Team
 * @version 1.0.0
 * @since 2024-01-01
 */
@DisplayName("ChatSession实体类测试")
class ChatSessionTest {

    /**
     * 测试用的ChatSession对象
     */
    private ChatSession chatSession;

    /**
     * 测试前的准备工作
     *
     * 每个测试方法执行前都会调用此方法。
     * 初始化一个标准的ChatSession对象用于测试。
     */
    @BeforeEach
    void setUp() {
        // 创建一个标准的ChatSession对象
        chatSession = new ChatSession();
        chatSession.setId(1L);
        chatSession.setUserId(1001L);
        chatSession.setTargetId(1002L);
        chatSession.setTargetType("friend");
        chatSession.setLastMsg("Hello!");
        chatSession.setLastMsgTime(new Date());
        chatSession.setUnreadCount(5);
        chatSession.setCreateTime(new Date());
        chatSession.setIsMuted(0);
        chatSession.setUpdateTime(new Date());
    }

    /**
     * 测试无参构造函数
     *
     * 验证ChatSession可以正确地使用无参构造函数创建。
     * 这是MyBatis和Jackson等框架需要的。
     */
    @Test
    @DisplayName("应该能够使用无参构造函数创建ChatSession对象")
    void should_create_chat_session_with_no_arg_constructor() {
        // 执行
        ChatSession session = new ChatSession();

        // 验证
        assertNotNull(session, "ChatSession对象不应该为null");
        assertNull(session.getId(), "ID应该为null");
        assertNull(session.getUserId(), "用户ID应该为null");
        assertNull(session.getTargetId(), "目标ID应该为null");
        assertNull(session.getTargetType(), "目标类型应该为null");
        assertNull(session.getLastMsg(), "最后消息应该为null");
        assertNull(session.getLastMsgTime(), "最后消息时间应该为null");
        assertNull(session.getUnreadCount(), "未读数应该为null");
        assertNull(session.getCreateTime(), "创建时间应该为null");
        assertNull(session.getIsMuted(), "免打扰设置应该为null");
        assertNull(session.getUpdateTime(), "更新时间应该为null");
    }

    /**
     * 测试所有字段的getter/setter方法
     *
     * 验证所有字段都能正确地设置和获取值。
     */
    @Test
    @DisplayName("应该能够正确设置和获取所有字段")
    void should_set_and_get_all_fields_correctly() {
        // 执行和验证 - ID字段
        assertEquals(1L, chatSession.getId(), "ID应该正确设置");
        chatSession.setId(2L);
        assertEquals(2L, chatSession.getId(), "ID应该能够被更新");

        // 用户ID字段
        assertEquals(1001L, chatSession.getUserId(), "用户ID应该正确设置");
        chatSession.setUserId(2001L);
        assertEquals(2001L, chatSession.getUserId(), "用户ID应该能够被更新");

        // 目标ID字段
        assertEquals(1002L, chatSession.getTargetId(), "目标ID应该正确设置");
        chatSession.setTargetId(2002L);
        assertEquals(2002L, chatSession.getTargetId(), "目标ID应该能够被更新");

        // 目标类型字段
        assertEquals("friend", chatSession.getTargetType(), "目标类型应该正确设置");
        chatSession.setTargetType("group");
        assertEquals("group", chatSession.getTargetType(), "目标类型应该能够被更新");

        // 最后消息字段
        assertEquals("Hello!", chatSession.getLastMsg(), "最后消息应该正确设置");
        chatSession.setLastMsg("新的消息");
        assertEquals("新的消息", chatSession.getLastMsg(), "最后消息应该能够被更新");

        // 最后消息时间字段
        assertNotNull(chatSession.getLastMsgTime(), "最后消息时间不应该为null");
        Date newTime = new Date(System.currentTimeMillis() + 10000);
        chatSession.setLastMsgTime(newTime);
        assertEquals(newTime, chatSession.getLastMsgTime(), "最后消息时间应该能够被更新");

        // 未读数字段
        assertEquals(5, chatSession.getUnreadCount(), "未读数应该正确设置");
        chatSession.setUnreadCount(10);
        assertEquals(10, chatSession.getUnreadCount(), "未读数应该能够被更新");

        // 创建时间字段
        assertNotNull(chatSession.getCreateTime(), "创建时间不应该为null");
        Date createTime = new Date();
        chatSession.setCreateTime(createTime);
        assertEquals(createTime, chatSession.getCreateTime(), "创建时间应该能够被更新");

        // 免打扰设置字段
        assertEquals(0, chatSession.getIsMuted(), "免打扰设置应该正确设置");
        chatSession.setIsMuted(1);
        assertEquals(1, chatSession.getIsMuted(), "免打扰设置应该能够被更新");

        // 更新时间字段
        assertNotNull(chatSession.getUpdateTime(), "更新时间不应该为null");
        Date updateTime = new Date();
        chatSession.setUpdateTime(updateTime);
        assertEquals(updateTime, chatSession.getUpdateTime(), "更新时间应该能够被更新");
    }

    /**
     * 测试对象创建时的默认值
     *
     * 验证新创建的ChatSession对象的字段值符合预期。
     */
    @Test
    @DisplayName("新创建的ChatSession应该有正确的初始状态")
    void should_have_correct_initial_state_when_created() {
        // 执行
        ChatSession newSession = new ChatSession();

        // 验证所有字段都是null
        assertNull(newSession.getId(), "新会话的ID应该为null");
        assertNull(newSession.getUserId(), "新会话的用户ID应该为null");
        assertNull(newSession.getTargetId(), "新会话的目标ID应该为null");
        assertNull(newSession.getTargetType(), "新会话的目标类型应该为null");
        assertNull(newSession.getLastMsg(), "新会话的最后消息应该为null");
        assertNull(newSession.getLastMsgTime(), "新会话的最后消息时间应该为null");
        assertNull(newSession.getUnreadCount(), "新会话的未读数应该为null");
        assertNull(newSession.getCreateTime(), "新会话的创建时间应该为null");
        assertNull(newSession.getIsMuted(), "新会话的免打扰设置应该为null");
        assertNull(newSession.getUpdateTime(), "新会话的更新时间应该为null");
    }

    /**
     * 测试ID字段的边界条件
     *
     * 验证ID字段可以处理各种边界值。
     */
    @Test
    @DisplayName("应该能够处理ID字段的各种边界值")
    void should_handle_boundary_values_for_id_field() {
        // 测试0值
        chatSession.setId(0L);
        assertEquals(0L, chatSession.getId(), "ID可以为0");

        // 测试负值（虽然不应该出现，但应该能处理）
        chatSession.setId(-1L);
        assertEquals(-1L, chatSession.getId(), "ID可以为负值");

        // 测试最大Long值
        chatSession.setId(Long.MAX_VALUE);
        assertEquals(Long.MAX_VALUE, chatSession.getId(), "ID可以为最大Long值");

        // 测试最小Long值
        chatSession.setId(Long.MIN_VALUE);
        assertEquals(Long.MIN_VALUE, chatSession.getId(), "ID可以为最小Long值");
    }

    /**
     * 测试字符串字段的边界条件
     *
     * 验证字符串字段可以处理空字符串和长字符串。
     */
    @Test
    @DisplayName("应该能够处理字符串字段的各种边界值")
    void should_handle_boundary_values_for_string_fields() {
        // 测试空字符串
        chatSession.setTargetType("");
        assertEquals("", chatSession.getTargetType(), "目标类型可以为空字符串");

        chatSession.setLastMsg("");
        assertEquals("", chatSession.getLastMsg(), "最后消息可以为空字符串");

        // 测试长字符串（模拟数据库VARCHAR(20)的限制）
        String longString = "这是一条很长的消息内容，用来测试字符串字段的边界条件。" +
                           "这是一条很长的消息内容，用来测试字符串字段的边界条件。";
        chatSession.setLastMsg(longString);
        assertEquals(longString, chatSession.getLastMsg(), "最后消息可以包含长字符串");
    }

    /**
     * 测试数字字段的边界条件
     *
     * 验证数字字段可以处理各种边界值。
     */
    @Test
    @DisplayName("应该能够处理数字字段的各种边界值")
    void should_handle_boundary_values_for_numeric_fields() {
        // 测试未读数的各种值
        chatSession.setUnreadCount(0);
        assertEquals(0, chatSession.getUnreadCount(), "未读数可以为0");

        chatSession.setUnreadCount(Integer.MAX_VALUE);
        assertEquals(Integer.MAX_VALUE, chatSession.getUnreadCount(), "未读数可以为最大整数值");

        chatSession.setUnreadCount(-1);
        assertEquals(-1, chatSession.getUnreadCount(), "未读数可以为负值");

        // 测试免打扰设置的各种值
        chatSession.setIsMuted(0);
        assertEquals(0, chatSession.getIsMuted(), "免打扰设置可以为0（关闭）");

        chatSession.setIsMuted(1);
        assertEquals(1, chatSession.getIsMuted(), "免打扰设置可以为1（开启）");

        chatSession.setIsMuted(2);
        assertEquals(2, chatSession.getIsMuted(), "免打扰设置可以为其他值");
    }

    /**
     * 测试日期字段的边界条件
     *
     * 验证日期字段可以处理各种日期值。
     */
    @Test
    @DisplayName("应该能够处理日期字段的各种边界值")
    void should_handle_boundary_values_for_date_fields() {
        // 测试过去的时间
        Date pastDate = new Date(0); // 1970-01-01 00:00:00 UTC
        chatSession.setCreateTime(pastDate);
        assertEquals(pastDate, chatSession.getCreateTime(), "创建时间可以为过去的时间");

        chatSession.setLastMsgTime(pastDate);
        assertEquals(pastDate, chatSession.getLastMsgTime(), "最后消息时间可以为过去的时间");

        // 测试当前时间
        Date now = new Date();
        chatSession.setCreateTime(now);
        assertEquals(now, chatSession.getCreateTime(), "创建时间可以为当前时间");

        // 测试未来的时间（虽然不应该出现，但应该能处理）
        Date futureDate = new Date(System.currentTimeMillis() + 100000);
        chatSession.setUpdateTime(futureDate);
        assertEquals(futureDate, chatSession.getUpdateTime(), "更新时间可以为未来的时间");
    }

    /**
     * 测试对象的多次修改
     *
     * 验证对象可以被多次修改而不会出现问题。
     */
    @Test
    @DisplayName("应该能够多次修改对象的字段而不会出现问题")
    void should_allow_multiple_modifications_to_fields() {
        // 多次修改ID
        for (int i = 0; i < 10; i++) {
            chatSession.setId((long) i);
            assertEquals((long) i, chatSession.getId(), "ID应该正确更新为" + i);
        }

        // 多次修改未读数
        for (int i = 0; i < 100; i++) {
            chatSession.setUnreadCount(i);
            assertEquals(i, chatSession.getUnreadCount(), "未读数应该正确更新为" + i);
        }

        // 多次修改最后消息
        for (int i = 0; i < 10; i++) {
            String msg = "消息" + i;
            chatSession.setLastMsg(msg);
            assertEquals(msg, chatSession.getLastMsg(), "最后消息应该正确更新");
        }
    }

    /**
     * 测试对象的独立性
     *
     * 验证修改一个ChatSession对象不会影响另一个对象。
     */
    @Test
    @DisplayName("修改一个ChatSession对象不应该影响另一个对象")
    void should_not_affect_other_chat_session_when_modifying_one() {
        // 创建第二个ChatSession对象
        ChatSession otherSession = new ChatSession();
        otherSession.setId(100L);
        otherSession.setUserId(2000L);
        otherSession.setTargetId(3000L);

        // 修改第一个对象
        chatSession.setId(200L);
        chatSession.setUserId(4000L);
        chatSession.setTargetId(5000L);

        // 验证第二个对象没有被修改
        assertEquals(100L, otherSession.getId(), "第二个对象的ID不应该被修改");
        assertEquals(2000L, otherSession.getUserId(), "第二个对象的用户ID不应该被修改");
        assertEquals(3000L, otherSession.getTargetId(), "第二个对象的目标ID不应该被修改");
    }

    /**
     * 测试null值的处理
     *
     * 验证对象可以接受null值作为字段值。
     */
    @Test
    @DisplayName("应该能够处理null值作为字段值")
    void should_accept_null_values_for_fields() {
        // 设置所有字符串字段为null
        chatSession.setTargetType(null);
        chatSession.setLastMsg(null);

        assertNull(chatSession.getTargetType(), "目标类型应该可以为null");
        assertNull(chatSession.getLastMsg(), "最后消息应该可以为null");

        // 设置所有日期字段为null
        chatSession.setLastMsgTime(null);
        chatSession.setCreateTime(null);
        chatSession.setUpdateTime(null);

        assertNull(chatSession.getLastMsgTime(), "最后消息时间应该可以为null");
        assertNull(chatSession.getCreateTime(), "创建时间应该可以为null");
        assertNull(chatSession.getUpdateTime(), "更新时间应该可以为null");

        // 设置所有数字字段为null
        chatSession.setUnreadCount(null);
        chatSession.setIsMuted(null);

        assertNull(chatSession.getUnreadCount(), "未读数应该可以为null");
        assertNull(chatSession.getIsMuted(), "免打扰设置应该可以为null");
    }

    /**
     * 测试实际使用场景
     *
     * 验证ChatSession在实际使用场景中的表现。
     */
    @Test
    @DisplayName("应该能够在实际使用场景中正常工作")
    void should_work_correctly_in_real_use_cases() {
        // 场景1：创建新的私聊会话
        ChatSession privateChat = new ChatSession();
        privateChat.setUserId(1001L);
        privateChat.setTargetId(1002L);
        privateChat.setTargetType("friend");
        privateChat.setLastMsg("你好！");
        privateChat.setLastMsgTime(new Date());
        privateChat.setUnreadCount(1);
        privateChat.setCreateTime(new Date());
        privateChat.setIsMuted(0);
        privateChat.setUpdateTime(new Date());

        assertEquals(1001L, privateChat.getUserId(), "私聊会话的用户ID应该正确");
        assertEquals(1002L, privateChat.getTargetId(), "私聊会话的目标ID应该正确");
        assertEquals("friend", privateChat.getTargetType(), "私聊会话的目标类型应该为friend");
        assertEquals("你好！", privateChat.getLastMsg(), "私聊会话的最后消息应该正确");
        assertEquals(1, privateChat.getUnreadCount(), "私聊会话的未读数应该正确");
        assertEquals(0, privateChat.getIsMuted(), "私聊会话的免打扰设置应该为0");

        // 场景2：创建新的群聊会话
        ChatSession groupChat = new ChatSession();
        groupChat.setUserId(1001L);
        groupChat.setTargetId(5001L);
        groupChat.setTargetType("group");
        groupChat.setLastMsg("大家好！");
        groupChat.setLastMsgTime(new Date());
        groupChat.setUnreadCount(10);
        groupChat.setCreateTime(new Date());
        groupChat.setIsMuted(1); // 开启免打扰
        groupChat.setUpdateTime(new Date());

        assertEquals(1001L, groupChat.getUserId(), "群聊会话的用户ID应该正确");
        assertEquals(5001L, groupChat.getTargetId(), "群聊会话的目标ID应该正确");
        assertEquals("group", groupChat.getTargetType(), "群聊会话的目标类型应该为group");
        assertEquals("大家好！", groupChat.getLastMsg(), "群聊会话的最后消息应该正确");
        assertEquals(10, groupChat.getUnreadCount(), "群聊会话的未读数应该正确");
        assertEquals(1, groupChat.getIsMuted(), "群聊会话的免打扰设置应该为1");

        // 场景3：更新会话信息
        privateChat.setLastMsg("新的消息");
        privateChat.setLastMsgTime(new Date());
        privateChat.setUnreadCount(0);
        privateChat.setUpdateTime(new Date());

        assertEquals("新的消息", privateChat.getLastMsg(), "更新后的最后消息应该正确");
        assertEquals(0, privateChat.getUnreadCount(), "更新后的未读数应该为0");
    }
}
