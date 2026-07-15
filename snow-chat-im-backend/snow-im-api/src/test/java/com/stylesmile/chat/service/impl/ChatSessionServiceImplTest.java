package com.stylesmile.chat.service.impl;

import com.stylesmile.chat.entity.ChatSession;
import com.stylesmile.chat.mapper.ChatSessionMapper;
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
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ChatSessionServiceImplTest {

    @Mock
    private ChatSessionMapper mapper;

    @Spy
    private ChatSessionServiceImpl service;

    @BeforeEach
    void setUp() {
        ReflectionTestUtils.setField(service, "baseMapper", mapper);
    }

    @Test
    void delegatesSessionQueriesAndUpdates() {
        List<ChatSession> sessions = List.of(new ChatSession());
        when(mapper.getSessionsByUserId(4)).thenReturn(sessions);

        assertEquals(sessions, service.getSessionsByUserId(4));
        service.updateLastMessage(4, 7, "friend", "hello");
        service.clearUnreadCount(4, 7);

        verify(mapper).updateLastMessage(4, 7, "friend", "hello");
        verify(mapper).clearUnreadCount(4, 7);
    }

    @Test
    void returnsExistingSessionWithoutSaving() {
        ChatSession existing = new ChatSession();
        when(mapper.selectOne(any())).thenReturn(existing);

        assertEquals(existing, service.getOrCreateSession(4, 7, "friend"));
        verify(service, org.mockito.Mockito.never()).save(any(ChatSession.class));
    }

    @Test
    void createsSessionWithDefaultStateWhenMissing() {
        when(mapper.selectOne(any())).thenReturn(null);
        doAnswer(invocation -> {
            ChatSession session = invocation.getArgument(0);
            session.setId(30);
            return true;
        }).when(service).save(any(ChatSession.class));

        ChatSession result = service.getOrCreateSession(4, 7, "group");

        assertEquals(30, result.getId());
        assertEquals(4, result.getUserId());
        assertEquals(7, result.getTargetId());
        assertEquals("group", result.getTargetType());
        assertEquals(0, result.getUnreadCount());
        assertEquals(0, result.getIsMuted());
        assertNotNull(result.getUpdateTime());
        ArgumentCaptor<ChatSession> captor = ArgumentCaptor.forClass(ChatSession.class);
        verify(service).save(captor.capture());
        assertEquals(result, captor.getValue());
    }
}
