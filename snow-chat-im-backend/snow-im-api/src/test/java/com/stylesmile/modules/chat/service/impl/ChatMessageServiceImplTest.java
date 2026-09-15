package com.stylesmile.modules.chat.service.impl;

import com.stylesmile.chat.entity.ChatGroupMember;
import com.stylesmile.chat.entity.ChatMessage;
import com.stylesmile.chat.entity.ChatMessageRoute;
import com.stylesmile.chat.entity.ChatOfflineMessage;
import com.stylesmile.chat.mapper.ChatMessageMapper;
import com.stylesmile.chat.mapper.ChatMessageRouteMapper;
import com.stylesmile.chat.mapper.ChatOfflineMessageMapper;
import com.stylesmile.chat.mqtt.MqttConnectStatusListener;
import com.stylesmile.chat.mqtt.MqttPushService;
import com.stylesmile.chat.service.ChatGroupMemberService;
import com.stylesmile.chat.service.ChatSessionService;
import com.stylesmile.chat.service.impl.ChatMessageServiceImpl;
import com.stylesmile.chat.shard.MessageShardProperties;
import com.stylesmile.chat.shard.MessageShardRouter;
import com.stylesmile.chat.shard.MessageShardSchemaService;
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
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.atLeastOnce;
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
    @Mock
    private ChatMessageRouteMapper chatMessageRouteMapper;
    @Mock
    private MessageShardSchemaService shardSchemaService;

    /** 真实路由组件（默认粒度 1000 用户 / 100 群一表），表名可预期 */
    private MessageShardRouter shardRouter;

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
        ReflectionTestUtils.setField(service, "chatMessageRouteMapper", chatMessageRouteMapper);
        ReflectionTestUtils.setField(service, "shardSchemaService", shardSchemaService);
        shardRouter = new MessageShardRouter(new MessageShardProperties());
        ReflectionTestUtils.setField(service, "shardRouter", shardRouter);
        // 建表桩：收到什么表名就返回什么表名
        lenient().when(shardSchemaService.ensureTableByName(anyString()))
                .thenAnswer(invocation -> invocation.getArgument(0));
    }

    @Test
    void sendMessage_shouldSaveMessage() {
        ChatMessage message = message(10L, 42L, null);

        service.sendMessage(message);

        // 分表：min(10,42)=10 → chat_message_friend_0
        verify(chatMessageMapper).insertInto(eq("chat_message_friend_0"), eq(message));
        assertEquals(0, message.getStatus());
    }

    @Test
    void sendMessage_shouldWriteShardRoute() {
        ChatMessage message = message(10L, 42L, null);
        message.setId(99L);

        service.sendMessage(message);

        // 只知 messageId 的撤回/回执要靠这条路由定位分表
        ArgumentCaptor<ChatMessageRoute> captor = ArgumentCaptor.forClass(ChatMessageRoute.class);
        verify(chatMessageRouteMapper).insert(captor.capture());
        assertEquals(99L, captor.getValue().getId());
        assertEquals("friend", captor.getValue().getTargetType());
        assertEquals(10L, captor.getValue().getShardKey());
    }

    @Test
    void sendMessage_groupMessage_shouldGoToGroupTable() {
        ChatMessage message = message(10L, null, 7L);

        service.sendMessage(message);

        // 群 7 / 100 = 0
        verify(chatMessageMapper).insertInto(eq("chat_message_group_0"), eq(message));
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
        // 分片路由：messageId 99 → friend 会话，分片键 min(10,42)=10 → chat_message_friend_0
        ChatMessageRoute route = new ChatMessageRoute();
        route.setId(99L);
        route.setTargetType("friend");
        route.setShardKey(10L);
        when(chatMessageRouteMapper.selectById(99L)).thenReturn(route);
        // stub 按主键查询：processReceipt 需查询消息获取发送方 ID 才能回推
        when(chatMessageMapper.selectByIdFrom("chat_message_friend_0", 99L)).thenReturn(message);

        // 执行：接收方 42L 发送回执，确认收到 messageId=99 的消息
        service.processReceipt(99L, 42L);

        // 验证：分表上的 push_status 被推进到 delivered
        verify(chatMessageMapper).updatePushStatus("chat_message_friend_0", 99L, "delivered");

        // 验证：向发送方 10L 推送 MSG_RECEIPT_ACK(2007)，通知"消息已送达"
        verify(mqttPushService).publish(eq("chat/user/10"), eq(2007), any());
    }

    @Test
    void processReceipt_withoutRoute_shouldDoNothing() {
        // 没有分片路由（历史数据未迁移）时不能瞎猜表，直接跳过
        when(chatMessageRouteMapper.selectById(99L)).thenReturn(null);

        service.processReceipt(99L, 42L);

        verify(chatMessageMapper, never()).updatePushStatus(anyString(), anyLong(), anyString());
        verify(mqttPushService, never()).publish(anyString(), anyInt(), any());
    }

    /**
     * 文件传输助手（type=self）：发送给自己，接收人=自己
     *
     * 验证：
     * 1. 发送方的会话应归类为 file_helper（而不是 friend）
     * 2. 消息推送到自己的 topic（同步到自己的其他登录端）
     *
     * 该测试当前处于 RED：现有代码靠 toUserId==0 识别文件助手，
     * 改为接收人=自己后，还没有按 type='self' 归类/推送的能力。
     */
    @Test
    void sendMessage_selfMessage_shouldCreateFileHelperSessionAndPushToSelf() {
        // 准备：文件传输助手消息，type=self，from=to=10（发送给自己）
        ChatMessage selfMsg = new ChatMessage();
        selfMsg.setId(99L);
        selfMsg.setFromUserId(10L);
        selfMsg.setToUserId(10L);
        selfMsg.setType("self");
        selfMsg.setContent("note");
        // 自己在线：实时推送，不额外存离线消息
        when(mqttConnectStatusListener.isOnline("user_10")).thenReturn(true);

        // 执行：发送文件传输助手消息
        service.sendMessage(selfMsg);

        // 验证：发送方会话 targetType 必须是 file_helper（而非 friend）
        verify(chatSessionService, atLeastOnce()).getOrCreateSession(10L, 10L, "file_helper");
        // 验证：推送到自己的 topic（chat/user/10），让其他设备也能收到
        verify(mqttPushService).publish(eq("chat/user/10"), eq(2001), any());
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
