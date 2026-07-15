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

    @Mock
    private ChatUserMapper mapper;

    @Spy
    private ChatUserServiceImpl service;

    @BeforeEach
    void setUp() {
        ReflectionTestUtils.setField(service, "baseMapper", mapper);
    }

    @Test
    void logsInWithMd5Password() {
        ChatUser user = new ChatUser();
        user.setUsername("alice");
        user.setPassword("6384e2b2184bcbf58eccf10ca7a6563c");
        when(mapper.getUserByUsername("alice")).thenReturn(user);

        Result result = service.login("alice", "secret");

        assertEquals("200", result.getCode());
        assertEquals(user, result.getData());
    }

    @Test
    void rejectsUnknownAndWrongPassword() {
        when(mapper.getUserByUsername("missing")).thenReturn(null);
        Result missing = service.login("missing", "secret");
        assertEquals("500", missing.getCode());
        assertEquals("用户不存在", missing.getMsg());

        ChatUser user = new ChatUser();
        user.setPassword("wrong");
        when(mapper.getUserByUsername("alice")).thenReturn(user);
        Result wrong = service.login("alice", "secret");
        assertEquals("500", wrong.getCode());
        assertEquals("用户名或者密码错误", wrong.getMsg());
    }

    @Test
    void countsOnlineUsers() {
        when(mapper.selectCount(any())).thenReturn(3L);

        assertEquals(3, service.countOnlineUsers());
        verify(mapper).selectCount(any());
    }

    @Test
    void registersUserWithDefaultsAndHashedPassword() {
        when(mapper.getUserByUsername("alice")).thenReturn(null);
        when(mapper.selectOne(any())).thenReturn(null);
        doAnswer(invocation -> {
            ChatUser user = invocation.getArgument(0);
            user.setId(11);
            return true;
        }).when(service).save(any(ChatUser.class));

        Result result = service.register("alice", "secret", null, "");

        assertEquals("200", result.getCode());
        ChatUser user = (ChatUser) result.getData();
        assertNotNull(user);
        assertEquals(11, user.getId());
        assertEquals("alice", user.getNickname());
        assertEquals("", user.getEmail());
        assertEquals("offline", user.getStatus());
        assertEquals("", user.getAvatar());
        assertEquals("", user.getSignature());
        assertEquals("6384e2b2184bcbf58eccf10ca7a6563c", user.getPassword());
        ArgumentCaptor<ChatUser> captor = ArgumentCaptor.forClass(ChatUser.class);
        verify(service).save(captor.capture());
        assertEquals(user, captor.getValue());
    }

    @Test
    void rejectsDuplicateUsernameOrEmail() {
        ChatUser existing = new ChatUser();
        when(mapper.getUserByUsername("alice")).thenReturn(existing);
        Result duplicateUsername = service.register("alice", "secret", "Alice", "a@example.com");
        assertEquals("500", duplicateUsername.getCode());
        assertEquals("用户名已存在", duplicateUsername.getMsg());

        when(mapper.getUserByUsername("bob")).thenReturn(null);
        when(mapper.selectOne(any())).thenReturn(existing);
        Result duplicateEmail = service.register("bob", "secret", "Bob", "a@example.com");
        assertEquals("500", duplicateEmail.getCode());
        assertEquals("邮箱已被注册", duplicateEmail.getMsg());
    }
}
