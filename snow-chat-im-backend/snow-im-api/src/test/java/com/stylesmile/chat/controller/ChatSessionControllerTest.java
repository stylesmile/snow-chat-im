package com.stylesmile.chat.controller;

import com.stylesmile.chat.entity.ChatSession;
import com.stylesmile.chat.service.ChatSessionService;
import com.stylesmile.common.util.Result;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ChatSessionControllerTest {

    @Mock
    private ChatSessionService chatSessionService;

    @InjectMocks
    private ChatSessionController controller;

    @Test
    void listsSessionsForUser() {
        List<ChatSession> sessions = List.of(new ChatSession());
        when(chatSessionService.getSessionsByUserId(5L)).thenReturn(sessions);

        Result<List<ChatSession>> result = controller.list(5L);

        assertSuccess(result);
        assertEquals(sessions, result.getData());
    }

    @Test
    void clearsUnreadCountFromDto() {
        ChatSessionController.ClearUnreadDTO dto = new ChatSessionController.ClearUnreadDTO();
        dto.setUserId(5L);
        dto.setTargetId(8L);

        assertSuccess(controller.clearUnread(dto));

        verify(chatSessionService).clearUnreadCount(5L, 8L);
    }

    private void assertSuccess(Result<?> result) {
        assertEquals("200", result.getCode());
    }
}
