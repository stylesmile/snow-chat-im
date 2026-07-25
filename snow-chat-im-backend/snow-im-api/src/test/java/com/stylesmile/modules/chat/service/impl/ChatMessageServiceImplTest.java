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

import com.baomidou.mybatisplus.core.conditions.Wrapper;
import com.baomidou.mybatisplus.core.conditions.update.UpdateWrapper;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doReturn;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import org.mockito.ArgumentCaptor;

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
        // save stub 用 lenient：sendMessage 测试需要，processReceipt 测试不需要
        lenient().doReturn(true).when(service).save(any(ChatMessage.class));
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
     * 小需求2：processReceipt 应将 pushStatus 推进到 delivered 并通知发送方
     *
     * 验证流程：
     * 1. 调用 update 将 pushStatus 设为 "delivered"（接收方确认收到，终端状态）
     * 2. 查询消息获取发送方 ID
     * 3. 向发送方推送 MSG_RECEIPT_ACK(2007) 通知"消息已送达"
     *
     * 使用 UpdateWrapper（非 lambda）使单元测试可断言具体 SET 值
     */
    @Test
    void processReceipt_shouldMarkAsDeliveredAndNotifySender() {
        // 准备：构造已入库消息，发送方 10L，接收方 42L，当前状态 server_received
        ChatMessage message = message(10L, 42L, null);
        message.setId(99L);
        message.setPushStatus("server_received");
        // stub getById：processReceipt 需查询消息获取发送方 ID 才能回推
        doReturn(message).when(service).getById(99L);
        // stub update：单元测试无法执行真实 SQL，返回 true 模拟成功
        doReturn(true).when(service).update(any(Wrapper.class));

        // 执行：接收方 42L 发送回执，确认收到 messageId=99 的消息
        service.processReceipt(99L, 42L);

        // 验证：update 被调用，捕获 wrapper 检查 SET 值
        ArgumentCaptor<Wrapper> captor = ArgumentCaptor.forClass(Wrapper.class);
        verify(service).update(captor.capture());
        // UpdateWrapper 将 set 值存储在 paramNameValuePairs 中
        UpdateWrapper<?> captured = (UpdateWrapper<?>) captor.getValue();
        // 验证 SET 子句包含 push_status 列
        assertTrue(captured.getSqlSet().contains("push_status"),
                "SET 子句应包含 push_status 列");
        // 验证 set 值为 delivered（接收方已确认收到，终端状态）
        assertTrue(captured.getParamNameValuePairs().containsValue("delivered"),
                "pushStatus 应被设为 delivered");

        // 验证：向发送方 10L 推送 MSG_RECEIPT_ACK(2007)，通知"消息已送达"
        verify(mqttPushService).publish(eq("chat/user/10"), eq(2007), any());
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
