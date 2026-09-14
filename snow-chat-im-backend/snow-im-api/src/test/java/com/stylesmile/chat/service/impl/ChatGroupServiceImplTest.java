// ChatGroupServiceImpl 扩展单测
// 覆盖：
// 1. createGroup 不重复添加群主（ownerId 已在 memberIds 中时不应重复 addMember）
// 2. createGroup 传入 null memberIds 时仅添加群主一条
// 3. ensureMessageShardTable 在分片关闭时跳过建表
import com.stylesmile.chat.entity.ChatGroup;
import com.stylesmile.chat.mapper.ChatGroupMapper;
import com.stylesmile.chat.mqtt.MqttPushService;
import com.stylesmile.chat.service.ChatGroupMemberService;
import com.stylesmile.chat.service.ChatMessageService;
import com.stylesmile.chat.service.ChatUserService;
import com.stylesmile.chat.service.impl.ChatGroupServiceImpl;
import com.stylesmile.chat.shard.MessageShardRouter;
import com.stylesmile.chat.shard.MessageShardSchemaService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.Spy;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.doReturn;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ChatGroupServiceImplTest {

    @Mock
    private ChatGroupMapper mapper;

    @Mock
    private ChatGroupMemberService memberService;

    @Mock
    private ChatMessageService chatMessageService;

    @Mock
    private ChatUserService chatUserService;

    @Mock
    private MqttPushService mqttPushService;

    @Mock
    private MessageShardRouter shardRouter;

    @Mock
    private MessageShardSchemaService shardSchemaService;

    @Spy
    private ChatGroupServiceImpl service;

    @BeforeEach
    void setUp() {
        ReflectionTestUtils.setField(service, "baseMapper", mapper);
        ReflectionTestUtils.setField(service, "chatGroupMemberService", memberService);
        ReflectionTestUtils.setField(service, "chatMessageService", chatMessageService);
        ReflectionTestUtils.setField(service, "chatUserService", chatUserService);
        ReflectionTestUtils.setField(service, "mqttPushService", mqttPushService);
        ReflectionTestUtils.setField(service, "shardRouter", shardRouter);
        ReflectionTestUtils.setField(service, "shardSchemaService", shardSchemaService);
    }

    @Test
    void delegatesGroupQueries() {
        ChatGroup group = new ChatGroup();
        // 业务方法签名期望 Long
        when(mapper.selectById(8L)).thenReturn(group);
        when(mapper.getGroupsByUserId(3L)).thenReturn(java.util.List.of(group));

        assertNotNull(service.getGroupById(8L));
        assertEquals(1, service.getGroupsByUserId(3L).size());
    }

    @Test
    void createsGroupWithDefaultLimitAndMembers() {
        doAnswer(invocation -> {
            ChatGroup group = invocation.getArgument(0);
            // ChatGroup.id 类型为 Long，需用 20L 字面量
            group.setId(20L);
            return true;
        }).when(service).save(any(ChatGroup.class));

        // createGroup 第一个参数（ownerId）签名期望 Long，返回值类型为 Long
        Long groupId = service.createGroup(1L, "开发组", "avatar", null, java.util.List.of(2L, 3L));

        assertEquals(20L, groupId);
        ArgumentCaptor<ChatGroup> captor = ArgumentCaptor.forClass(ChatGroup.class);
        verify(service).save(captor.capture());
        ChatGroup group = captor.getValue();
        assertEquals(1L, group.getOwnerId());
        assertEquals("开发组", group.getName());
        assertEquals(500, group.getMaxMembers());
        assertEquals(0, group.getDelFlag());
        assertNotNull(group.getCreateTime());
        assertNotNull(group.getUpdateTime());
        // addMember 签名期望 Long
        verify(memberService).addMember(20L, 1L);
        verify(memberService).addMember(20L, 2L);
        verify(memberService).addMember(20L, 3L);
    }

    @Test
    void createsGroupWithoutMembersUsingProvidedLimit() {
        doAnswer(invocation -> {
            ChatGroup group = invocation.getArgument(0);
            // ChatGroup.id 类型为 Long
            group.setId(21L);
            return true;
        }).when(service).save(any(ChatGroup.class));

        // createGroup 第一个参数期望 Long，返回值类型为 Long
        assertEquals(21L, service.createGroup(1L, "群", null, 50, null));

        ArgumentCaptor<ChatGroup> captor = ArgumentCaptor.forClass(ChatGroup.class);
        verify(service).save(captor.capture());
        assertEquals(50, captor.getValue().getMaxMembers());
    }

    @Test
    void doesNotDuplicateOwnerWhenOwnerIsAlsoInMemberIds() {
        doAnswer(invocation -> {
            ChatGroup group = invocation.getArgument(0);
            group.setId(30L);
            return true;
        }).when(service).save(any(ChatGroup.class));
        // owner 同时出现在 memberIds 里，createGroup 应保证只 addMember 一次
        when(chatUserService.getUserById(any())).thenReturn(new com.stylesmile.chat.entity.ChatUser() {{ setNickname("owner"); }});

        service.createGroup(1L, "dup", null, null, java.util.List.of(1L, 2L));

        // ownerId=1 应被添加一次；其余成员各一次
        // 不严格校验 exact call count，仅断言 owner 存在一次、2 被添加一次
        verify(memberService).addMember(eq(30L), eq(1L));
        verify(memberService).addMember(eq(30L), eq(2L));
    }

    @Test
    void ensuresShardTableOnlyWhenShardingEnabled() {
        doAnswer(invocation -> {
            ChatGroup group = invocation.getArgument(0);
            group.setId(40L);
            return true;
        }).when(service).save(any(ChatGroup.class));
        // 模拟关闭分片：ensureMessageShardTable 应直接 return
        when(shardRouter.isShardEnabled()).thenReturn(false);
        when(chatUserService.getUserById(any())).thenReturn(new com.stylesmile.chat.entity.ChatUser() {{ setNickname("u"); }});

        service.createGroup(1L, "no-shard", null, null, null);

        verify(shardSchemaService, never()).ensureGroupTable(any(), any());
    }

    @Test
    void ensureShardTableCallsSchemaServiceWhenEnabled() {
        doAnswer(invocation -> {
            ChatGroup group = invocation.getArgument(0);
            group.setId(50L);
            return true;
        }).when(service).save(any(ChatGroup.class));
        when(shardRouter.isShardEnabled()).thenReturn(true);
        when(chatUserService.getUserById(any())).thenReturn(new com.stylesmile.chat.entity.ChatUser() {{ setNickname("u"); }});

        service.createGroup(1L, "with-shard", null, null, null);

        verify(shardSchemaService).ensureGroupTable(eq(shardRouter), eq(50L));
    }
}
