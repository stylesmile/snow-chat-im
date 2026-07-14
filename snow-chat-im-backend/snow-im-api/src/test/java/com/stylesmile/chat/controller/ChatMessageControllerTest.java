package com.stylesmile.chat.controller;

import com.stylesmile.chat.entity.ChatMessage;
import com.stylesmile.chat.service.ChatMessageService;
import com.stylesmile.common.util.Result;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ChatMessageControllerTest {

    @Mock
    private ChatMessageService chatMessageService;

    @InjectMocks
    private ChatMessageController controller;

    @Test
    void getsHistoryWithPagingArguments() {
        List<ChatMessage> messages = List.of(new ChatMessage());
        when(chatMessageService.getHistoryMessages(1, 2, "friend", 2, 15)).thenReturn(messages);

        Result<List<ChatMessage>> result = controller.history(1, 2, "friend", 2, 15);

        assertSuccess(result);
        assertEquals(messages, result.getData());
        verify(chatMessageService).getHistoryMessages(1, 2, "friend", 2, 15);
    }

    @Test
    void recallsAndMarksMessagesAsRead() {
        ChatMessageController.RecallMessageDTO recall = new ChatMessageController.RecallMessageDTO();
        recall.setUserId(1);
        recall.setMessageId(99L);
        ChatMessageController.ReadMessageDTO read = new ChatMessageController.ReadMessageDTO();
        read.setUserId(1);
        read.setTargetId(2);
        read.setTargetType("group");

        assertSuccess(controller.recall(recall));
        assertSuccess(controller.markAsRead(read));

        verify(chatMessageService).recallMessage(1, 99L);
        verify(chatMessageService).markAsRead(1, 2, "group");
    }

    @Test
    void mapsSendDtoToChatMessage() {
        ChatMessageController.SendMessageDTO dto = new ChatMessageController.SendMessageDTO();
        dto.setFromUserId(1);
        dto.setToUserId(2);
        dto.setGroupId(null);
        dto.setType("text");
        dto.setContent("hello");

        assertSuccess(controller.send(dto));

        ArgumentCaptor<ChatMessage> captor = ArgumentCaptor.forClass(ChatMessage.class);
        verify(chatMessageService).sendMessage(captor.capture());
        ChatMessage message = captor.getValue();
        assertEquals(1, message.getFromUserId());
        assertEquals(2, message.getToUserId());
        assertEquals("text", message.getType());
        assertEquals("hello", message.getContent());
    }

    private void assertSuccess(Result<?> result) {
        assertEquals("200", result.getCode());
    }
}
