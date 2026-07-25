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
        ChatMessage message = message(10L, 42L, null);

        service.sendMessage(message);

        verify(service).save(message);
        assertEquals(0, message.getStatus());
    }

    @Test
    void sendMessage_shouldPublishToOnlineRecipient() {
        ChatMessage message = message(10L, 42L, null);
        // pushToUser 会检查接收方 user_42 是否在线；发送方回执直接 publish，不检查在线状态
        when(mqttConnectStatusListener.isOnline("user_42")).thenReturn(true);

        service.sendMessage(message);

        verify(mqttPushService).publish(eq("chat/user/42"), eq(2001), any());
        verify(chatOfflineMessageMapper, never()).insert(any(ChatOfflineMessage.class));
    }

    @Test
    void sendMessage_shouldSaveOfflineMessageWhenRecipientOffline() {
        ChatMessage message = message(10L, 42L, null);
        // 接收方离线：服务始终尝试 MQTT 推送，并额外保存离线消息兜底
        when(mqttConnectStatusListener.isOnline("user_42")).thenReturn(false);

        service.sendMessage(message);

        // 始终推送（实时推送 + 离线兜底策略）
        verify(mqttPushService).publish(eq("chat/user/42"), eq(2001), any());
        verify(chatOfflineMessageMapper).insert(any(ChatOfflineMessage.class));
    }

    @Test
    void sendMessage_shouldUseClientIdWithUserPrefixForOnlineCheck() {
        ChatMessage message = message(10L, 42L, null);
        // listener 只对带 user_ 前缀的 clientId 返回在线；旧代码传纯数字会误判为离线
        when(mqttConnectStatusListener.isOnline("user_42")).thenReturn(true);

        service.sendMessage(message);

        // 验证只按 user_ 前缀查询，不会用纯数字查询
        verify(mqttConnectStatusListener, never()).isOnline("42");
        verify(mqttPushService).publish(eq("chat/user/42"), eq(2001), any());
    }

    @Test
    void sendMessage_shouldPublishGroupMessageToGroupTopic() {
        ChatMessage message = message(10L, null, 7L);
        ChatGroupMember member = new ChatGroupMember();
        // ChatGroupMember.setUserId 签名期望 Long
        member.setUserId(42L);
        // getMembersByGroupId 签名期望 Long
        when(chatGroupMemberService.getMembersByGroupId(7L)).thenReturn(List.of(member));

        service.sendMessage(message);

        verify(mqttPushService).publish(eq("chat/group/7"), eq(2001), any());
    }

    /**
     * 构造测试用 ChatMessage。
     * 参数类型为 Long，对齐 ChatMessage setter 的签名。
     */
    private ChatMessage message(Long fromUserId, Long toUserId, Long groupId) {
        ChatMessage message = new ChatMessage();
        // ChatMessage.id 类型为 Long，需用 99L 字面量
        message.setId(99L);
        message.setFromUserId(fromUserId);
        message.setToUserId(toUserId);
        message.setGroupId(groupId);
        message.setType("text");
        message.setContent("hello");
        return message;
    }
}
