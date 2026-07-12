package com.stylesmile.modules.chat.service.impl;

import com.stylesmile.chat.entity.ChatMessage;
import com.stylesmile.chat.mqtt.MqttPushService;
import com.stylesmile.chat.service.impl.ChatMessageServiceImpl;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.Spy;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doReturn;
import static org.mockito.Mockito.verify;

@ExtendWith(MockitoExtension.class)
class ChatMessageServiceImplTest {

    @Mock
    private MqttPushService mqttPushService;

    @Spy
    private ChatMessageServiceImpl service;

    @BeforeEach
    void setUp() {
        ReflectionTestUtils.setField(service, "mqttPushService", mqttPushService);
        doReturn(true).when(service).save(any(ChatMessage.class));
    }

    @Test
    void publishesPrivateMessageToRecipientTopic() {
        ChatMessage message = message(10, 42, null);

        service.sendMessage(message);

        ArgumentCaptor<Map<String, Object>> data = dataCaptor();
        verify(mqttPushService).publish(eq("chat/user/42"), eq(2001), data.capture());
        assertEquals(10, data.getValue().get("fromUserId"));
        assertEquals("hello", data.getValue().get("content"));
    }

    @Test
    void publishesGroupMessageToGroupTopic() {
        ChatMessage message = message(10, null, 7);

        service.sendMessage(message);

        verify(mqttPushService).publish(eq("chat/group/7"), eq(2001), any());
    }

    private ChatMessage message(Integer fromUserId, Integer toUserId, Integer groupId) {
        ChatMessage message = new ChatMessage();
        message.setId(99);
        message.setFromUserId(fromUserId);
        message.setToUserId(toUserId);
        message.setGroupId(groupId);
        message.setType("text");
        message.setContent("hello");
        return message;
    }

    @SuppressWarnings("unchecked")
    private ArgumentCaptor<Map<String, Object>> dataCaptor() {
        return ArgumentCaptor.forClass((Class<Map<String, Object>>) (Class<?>) Map.class);
    }
}
