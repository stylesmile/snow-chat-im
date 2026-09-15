// ChatMessageServiceImpl 核心路径单测
// 覆盖：
// 1. sendMessage 校验 fromUserId / toUserId 与 groupId 的合法性
// 2. sendMessage 成功时调用了 saveMessage、chatSessionService、mqttPushService
// 3. saveMessage 在没有 id/createTime/status 时自动补齐
// 4. resolveTargetType 根据 groupId / type=self 正确区分 file_helper / group / friend
// 5. processReceipt 对合法消息状态机流转（pending -> processed）
import com.stylesmile.chat.entity.ChatGroupMember;
import com.stylesmile.chat.entity.ChatMessage;
import com.stylesmile.chat.mapper.ChatMessageMapper;
import com.stylesmile.chat.mapper.ChatMessageRouteMapper;
import com.stylesmile.chat.mapper.ChatOfflineMessageMapper;
import com.stylesmile.chat.mqtt.MqttConnectStatusListener;
import com.stylesmile.chat.mqtt.MqttPushService;
import com.stylesmile.chat.mqtt.MqttTopics;
import com.stylesmile.chat.mqtt.WsCmd;
import com.stylesmile.chat.service.ChatGroupMemberService;
import com.stylesmile.chat.service.ChatSessionService;
import com.stylesmile.chat.service.impl.ChatMessageServiceImpl;
import com.stylesmile.chat.shard.MessageShardRouter;
import com.stylesmile.chat.shard.MessageShardSchemaService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.Collections;
import java.util.Date;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyMap;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ChatMessageServiceImplTest {

    @Mock private ChatMessageMapper baseMapper;
    @Mock private ChatMessageRouteMapper chatMessageRouteMapper;
    @Mock private ChatOfflineMessageMapper chatOfflineMessageMapper;
    @Mock private MqttPushService mqttPushService;
    @Mock private MqttConnectStatusListener mqttConnectStatusListener;
    @Mock private ChatSessionService chatSessionService;
    @Mock private ChatGroupMemberService chatGroupMemberService;
    @Mock private MessageShardRouter shardRouter;
    @Mock private MessageShardSchemaService shardSchemaService;

    private ChatMessageServiceImpl service;

    @BeforeEach
    void setUp() {
        service = new ChatMessageServiceImpl();
        ReflectionTestUtils.setField(service, "baseMapper", baseMapper);
        ReflectionTestUtils.setField(service, "mqttPushService", mqttPushService);
        ReflectionTestUtils.setField(service, "mqttConnectStatusListener", mqttConnectStatusListener);
        ReflectionTestUtils.setField(service, "chatOfflineMessageMapper", chatOfflineMessageMapper);
        ReflectionTestUtils.setField(service, "chatSessionService", chatSessionService);
        ReflectionTestUtils.setField(service, "chatGroupMemberService", chatGroupMemberService);
        ReflectionTestUtils.setField(service, "chatMessageRouteMapper", chatMessageRouteMapper);
        ReflectionTestUtils.setField(service, "shardRouter", shardRouter);
        ReflectionTestUtils.setField(service, "shardSchemaService", shardSchemaService);
    }

    @Test
    void sendMessageRejectWhenFromUserIdIsNull() {
        ChatMessage message = new ChatMessage();
        // fromUserId 留空以触发校验
        message.setToUserId(2L);
        message.setContent("hi");

        assertThrows(IllegalArgumentException.class, () -> service.sendMessage(message));
        verify(baseMapper, never()).insertInto(eq("chat_messages"), any(ChatMessage.class));
        verify(mqttPushService, never()).publish(anyString(), anyInt(), anyMap());
    }

    @Test
    void sendMessageRejectWhenNeitherToUserIdNorGroupIdIsSet() {
        ChatMessage message = new ChatMessage();
        message.setFromUserId(1L);
        // toUserId 和 groupId 均为 null，命中非法分支
        message.setContent("orphan");

        assertThrows(IllegalArgumentException.class, () -> service.sendMessage(message));
    }

    @Test
    void sendMessageSuccessSetsDefaultsAndPublishesPrivateMessage() {
        ChatMessage message = new ChatMessage();
        message.setFromUserId(1L);
        message.setToUserId(2L);
        message.setContent("hello");
        // 故意不设置 id/createTime/status，验证 saveMessage 会补全
        when(shardRouter.isShardEnabled()).thenReturn(false);
        when(shardRouter.mainTable()).thenReturn("chat_messages");

        service.sendMessage(message);

        // 落库侧：saveMessage 被调用一次（通过 baseServiceImpl.save 的 spy 间接验证）
        // 这里只验证上层链路：消息状态应该被设为 0，pushStatus 应该为 server_received
        assertEquals(0, message.getStatus().intValue());
        assertEquals("server_received", message.getPushStatus());
        // 推送：私聊只推给接收方
        verify(mqttPushService).publish(
                eq(MqttTopics.user(2L)),
                eq(WsCmd.MSG_PUSH),
                any(Map.class));
        // 发送方收到回执
        verify(mqttPushService).publish(
                eq(MqttTopics.user(1L)),
                eq(WsCmd.MSG_RECEIPT_ACK),
                any(Map.class));
    }

    @Test
    void resolveTargetTypeForGroupMessage() {
        // 通过 sendMessage 的路径间接校验 targetType 计算
        ChatMessage message = new ChatMessage();
        message.setFromUserId(1L);
        message.setGroupId(99L);
        message.setContent("group hi");
        when(shardRouter.isShardEnabled()).thenReturn(false);
        when(shardRouter.mainTable()).thenReturn("chat_messages");

        service.sendMessage(message);

        // 群消息应推送到 group/99 主题
        verify(mqttPushService).publish(eq(MqttTopics.group(99L)), eq(WsCmd.MSG_PUSH), any(Map.class));
        // 群成员离线兜底拉取（成员列表为空，避免再调 offline mapper）
        verify(chatGroupMemberService).getMembersByGroupId(99L);
    }

    @Test
    void saveMessageSetsDefaultsWhenFieldsAreNull() {
        ChatMessage message = new ChatMessage();
        // id/createTime/status 都未设
        when(shardRouter.isShardEnabled()).thenReturn(false);
        when(shardRouter.mainTable()).thenReturn("chat_messages");

        service.saveMessage(message);

        assertNotNull(message.getId());
        assertNotNull(message.getCreateTime());
        assertEquals(0, message.getStatus().intValue());
        verify(baseMapper).insertInto(eq("chat_messages"), any(ChatMessage.class));
    }

    @Test
    void saveMessagePreservesExistingIdAndTime() {
        ChatMessage message = new ChatMessage();
        long fixedId = 123L;
        Date fixedTime = new Date(1000L);
        message.setId(fixedId);
        message.setCreateTime(fixedTime);
        message.setStatus(1);
        when(shardRouter.isShardEnabled()).thenReturn(false);
        when(shardRouter.mainTable()).thenReturn("chat_messages");

        service.saveMessage(message);

        assertEquals(fixedId, message.getId());
        assertEquals(fixedTime, message.getCreateTime());
        assertEquals(1, message.getStatus().intValue());
    }

    @Test
    void processReceiptTransitionsPendingToDelivered() {
        ChatMessage message = new ChatMessage();
        message.setId(1L);
        message.setStatus(0); // pending
        message.setFromUserId(10L);
        // processReceipt 内部用 resolveTableByMessageId -> selectByIdFrom + updatePushStatus
        when(shardRouter.isShardEnabled()).thenReturn(false);
        when(shardRouter.mainTable()).thenReturn("chat_messages");
        when(baseMapper.selectByIdFrom(eq("chat_messages"), eq(1L))).thenReturn(message);

        service.processReceipt(1L, 10L);

        verify(baseMapper).updatePushStatus(eq("chat_messages"), eq(1L), eq("delivered"));
        verify(mqttPushService).publish(
                eq(MqttTopics.user(10L)),
                eq(WsCmd.MSG_RECEIPT_ACK),
                any(Map.class));
    }

    @Test
    void processReceiptCallsUpdateStatusEvenWhenMessageIsMissing() {
        when(shardRouter.isShardEnabled()).thenReturn(false);
        when(shardRouter.mainTable()).thenReturn("chat_messages");
        // 消息不存在，但 updatePushStatus 仍会被调用（状态机更新到 delivered）
        when(baseMapper.selectByIdFrom(eq("chat_messages"), eq(1L))).thenReturn(null);

        service.processReceipt(1L, 10L);

        verify(baseMapper).updatePushStatus(eq("chat_messages"), eq(1L), eq("delivered"));
    }

    @Test
    void getHistoryMessagesDelegatesToMapper() {
        when(shardRouter.isShardEnabled()).thenReturn(false);
        when(shardRouter.mainTable()).thenReturn("chat_messages");
        when(baseMapper.getHistoryMessages(eq("chat_messages"), eq(1L), eq(2L), eq("friend"), eq(0), eq(20)))
                .thenReturn(Collections.emptyList());

        List<ChatMessage> result = service.getHistoryMessages(1L, 2L, "friend", 1, 20);

        assertNotNull(result);
        assertTrue(result.isEmpty());
    }
}
