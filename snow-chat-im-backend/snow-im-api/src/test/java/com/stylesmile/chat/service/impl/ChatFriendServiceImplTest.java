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
        when(mapper.getFriendsByUserId(1)).thenReturn(friends);
        when(mapper.getFriend(1, 2)).thenReturn(friend);

        assertEquals(friends, service.getFriendsByUserId(1));
        assertEquals(friend, service.getFriend(1, 2));
        assertTrue(service.isFriend(1, 2));
        when(mapper.getFriend(1, 3)).thenReturn(null);
        assertFalse(service.isFriend(1, 3));
    }

    @Test
    void createsFriendRelation() {
        doReturn(true).when(service).save(any(ChatFriend.class));

        service.addFriend(1, 2);

        ArgumentCaptor<ChatFriend> captor = ArgumentCaptor.forClass(ChatFriend.class);
        verify(service).save(captor.capture());
        assertEquals(1, captor.getValue().getUserId());
        assertEquals(2, captor.getValue().getFriendId());
    }
}
