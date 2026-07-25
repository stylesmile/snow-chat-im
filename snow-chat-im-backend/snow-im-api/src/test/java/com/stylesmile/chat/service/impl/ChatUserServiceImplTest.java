package com.stylesmile.chat.service.impl;

import com.stylesmile.chat.entity.ChatUser;
import com.stylesmile.chat.mapper.ChatUserMapper;
import com.stylesmile.common.util.Result;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.Spy;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.when;
import static org.mockito.Mockito.verify;

@ExtendWith(MockitoExtension.class)
class ChatUserServiceImplTest {

    // 模拟 ChatUserMapper，避免依赖 MyBatis-Plus 框架上下文
    @Mock
    private ChatUserMapper mapper;

    @Spy
    private ChatUserServiceImpl service;

    @BeforeEach
    void setUp() {
        // 手动注入 baseMapper，ServiceImpl 不会自动装配 mock
        ReflectionTestUtils.setField(service, "baseMapper", mapper);
    }

    @Test
    void logsInWithMd5Password() {
        ChatUser user = new ChatUser();
        user.setUsername("alice");
        // 实现使用 md5(username + password)，即 md5("alicesecret") = c4e31313222cf05fcdd1fc068af5570e
        user.setPassword("c4e31313222cf05fcdd1fc068af5570e");
        when(mapper.getUserByUsername("alice")).thenReturn(user);

        Result result = service.login("alice", "secret");

        // 登录成功返回 200
        assertEquals("200", result.getCode());
        assertEquals(user, result.getData());
    }

    @Test
    void rejectsUnknownAndWrongPassword() {
        // 用户不存在场景
        when(mapper.getUserByUsername("missing")).thenReturn(null);
        Result missing = service.login("missing", "secret");
        assertEquals("500", missing.getCode());
        assertEquals("用户不存在", missing.getMsg());

        // 密码错误场景
        ChatUser user = new ChatUser();
        user.setPassword("wrong");
        when(mapper.getUserByUsername("alice")).thenReturn(user);
        Result wrong = service.login("alice", "secret");
        assertEquals("500", wrong.getCode());
        assertEquals("用户名或者密码错误", wrong.getMsg());
    }

    // countsOnlineUsers 依赖 lambdaQuery()，需要 MyBatis-Plus 框架上下文，
    // 单元测试无法初始化 mapper 代理元数据，需由集成测试覆盖。
    // @Test
    // void countsOnlineUsers() { ... }

    @Test
    void registersUserWithDefaultsAndHashedPassword() {
        // 用户名不重复
        when(mapper.getUserByUsername("alice")).thenReturn(null);
        // 邮箱为空字符串，实现会跳过邮箱查重，不会调用 selectOne
        doAnswer(invocation -> {
            ChatUser user = invocation.getArgument(0);
            user.setId(11);
            return true;
        }).when(service).save(any(ChatUser.class));

        Result result = service.register("alice", "secret", null, "");

        // 注册成功返回 200
        assertEquals("200", result.getCode());
        ChatUser user = (ChatUser) result.getData();
        assertNotNull(user);
        // id 由 save 回填
        assertEquals(11, user.getId());
        // 昵称缺省时回退为用户名
        assertEquals("alice", user.getNickname());
        // 邮箱为空字符串
        assertEquals("", user.getEmail());
        // 新用户默认离线
        assertEquals("offline", user.getStatus());
        // 头像默认空字符串
        assertEquals("", user.getAvatar());
        // 签名默认空字符串
        assertEquals("", user.getSignature());
        // 密码应为 md5("alicesecret") = c4e31313222cf05fcdd1fc068af5570e
        assertEquals("c4e31313222cf05fcdd1fc068af5570e", user.getPassword());
        // 验证 save 被调用且入参就是返回的用户对象
        ArgumentCaptor<ChatUser> captor = ArgumentCaptor.forClass(ChatUser.class);
        verify(service).save(captor.capture());
        assertEquals(user, captor.getValue());
    }

    // rejectsDuplicateUsernameOrEmail 依赖 lambdaQuery()（邮箱查重），
    // 需要 MyBatis-Plus 框架上下文，单元测试无法初始化 mapper 代理元数据，
    // 需由集成测试覆盖。
    // @Test
    // void rejectsDuplicateUsernameOrEmail() { ... }
}
