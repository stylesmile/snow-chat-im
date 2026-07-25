package com.stylesmile.chat.service.impl;

import com.stylesmile.chat.entity.ChatFriend;
import com.stylesmile.chat.mapper.ChatFriendMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.Spy;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doReturn;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ChatFriendServiceImplTest {

    @Mock
    private ChatFriendMapper mapper;

    @Spy
    private ChatFriendServiceImpl service;

    @BeforeEach
    void setUp() {
        ReflectionTestUtils.setField(service, "baseMapper", mapper);
    }

    @Test
    void delegatesFriendQueries() {
        List<ChatFriend> friends = List.of(new ChatFriend());
        ChatFriend friend = new ChatFriend();
        // 业务方法签名期望 Long
        when(mapper.getFriendsByUserId(1L)).thenReturn(friends);
        when(mapper.getFriend(1L, 2L)).thenReturn(friend);

        assertEquals(friends, service.getFriendsByUserId(1L));
        assertEquals(friend, service.getFriend(1L, 2L));
        assertTrue(service.isFriend(1L, 2L));
        when(mapper.getFriend(1L, 3L)).thenReturn(null);
        assertFalse(service.isFriend(1L, 3L));
    }

    @Test
    void createsFriendRelation() {
        doReturn(true).when(service).save(any(ChatFriend.class));

        // addFriend 签名期望 Long
        service.addFriend(1L, 2L);

        ArgumentCaptor<ChatFriend> captor = ArgumentCaptor.forClass(ChatFriend.class);
        verify(service).save(captor.capture());
        assertEquals(1L, captor.getValue().getUserId());
        assertEquals(2L, captor.getValue().getFriendId());
    }
}
