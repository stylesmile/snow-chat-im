package com.stylesmile.modules.chat.service.impl;

import com.stylesmile.chat.entity.ChatGroupMember;
import com.stylesmile.chat.entity.ChatMessage;
import com.stylesmile.chat.entity.ChatOfflineMessage;
import com.stylesmile.chat.mapper.ChatMessageMapper;
import com.stylesmile.chat.mapper.ChatOfflineMessageMapper;
import com.stylesmile.chat.mqtt.MqttConnectStatusListener;
import com.stylesmile.chat.mqtt.MqttPushService;
import com.stylesmile.chat.service.ChatGroupMemberService;
import com.stylesmile.chat.service.ChatSessionService;
import com.stylesmile.chat.service.impl.ChatMessageServiceImpl;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.Spy;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doReturn;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ChatMessageServiceImplTest {

    @Mock
    private ChatMessageMapper chatMessageMapper;
    @Mock
    private MqttPushService mqttPushService;
    @Mock
    private MqttConnectStatusListener mqttConnectStatusListener;
    @Mock
    private ChatOfflineMessageMapper chatOfflineMessageMapper;
    @Mock
    private ChatSessionService chatSessionService;
    @Mock
    private ChatGroupMemberService chatGroupMemberService;

    @Spy
    private ChatMessageServiceImpl service;

    @BeforeEach
    void setUp() {
        ReflectionTestUtils.setField(service, "baseMapper", chatMessageMapper);
        ReflectionTestUtils.setField(service, "mqttPushService", mqttPushService);
        ReflectionTestUtils.setField(service, "mqttConnectStatusListener", mqttConnectStatusListener);
        ReflectionTestUtils.setField(service, "chatOfflineMessageMapper", chatOfflineMessageMapper);
        ReflectionTestUtils.setField(service, "chatSessionService", chatSessionService);
        ReflectionTestUtils.setField(service, "chatGroupMemberService", chatGroupMemberService);
        doReturn(true).when(service).save(any(ChatMessage.class));
    }

    @Test
    void sendMessage_shouldSaveMessage() {
        ChatMessage message = message(10, 42, null);

        service.sendMessage(message);

        verify(service).save(message);
        assertEquals(0, message.getStatus());
    }

    @Test
    void sendMessage_shouldPublishToOnlineRecipient() {
        ChatMessage message = message(10, 42, null);
        when(mqttConnectStatusListener.isOnline("user_42")).thenReturn(true);
        when(mqttConnectStatusListener.isOnline("user_10")).thenReturn(true);

        service.sendMessage(message);

        verify(mqttPushService).publish(eq("chat/user/42"), eq(2001), any());
        verify(chatOfflineMessageMapper, never()).insert(any(ChatOfflineMessage.class));
    }

    @Test
    void sendMessage_shouldSaveOfflineMessageWhenRecipientOffline() {
        ChatMessage message = message(10, 42, null);
        // 接收方离线，发送方在线（避免 sender echo 也被存离线）
        when(mqttConnectStatusListener.isOnline("user_42")).thenReturn(false);
        when(mqttConnectStatusListener.isOnline("user_10")).thenReturn(true);

        service.sendMessage(message);

        verify(mqttPushService, never()).publish(eq("chat/user/42"), anyInt(), any());
        verify(chatOfflineMessageMapper).insert(any(ChatOfflineMessage.class));
    }

    @Test
    void sendMessage_shouldUseClientIdWithUserPrefixForOnlineCheck() {
        ChatMessage message = message(10, 42, null);
        // listener 只对带 user_ 前缀的 clientId 返回在线；旧代码传纯数字会误判为离线
        when(mqttConnectStatusListener.isOnline("user_42")).thenReturn(true);
        when(mqttConnectStatusListener.isOnline("user_10")).thenReturn(true);

        service.sendMessage(message);

        // 验证只按 user_ 前缀查询，不会用纯数字查询
        verify(mqttConnectStatusListener, never()).isOnline("42");
        verify(mqttPushService).publish(eq("chat/user/42"), eq(2001), any());
    }

    @Test
    void sendMessage_shouldPublishGroupMessageToGroupTopic() {
        ChatMessage message = message(10, null, 7);
        ChatGroupMember member = new ChatGroupMember();
        member.setUserId(42);
        when(chatGroupMemberService.getMembersByGroupId(7)).thenReturn(List.of(member));

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
}
