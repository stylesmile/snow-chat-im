package com.stylesmile.chat.service.impl;

import com.stylesmile.chat.entity.ChatGroup;
import com.stylesmile.chat.mapper.ChatGroupMapper;
import com.stylesmile.chat.service.ChatGroupMemberService;
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
class ChatGroupServiceImplTest {

    @Mock
    private ChatGroupMapper mapper;

    @Mock
    private ChatGroupMemberService memberService;

    @Spy
    private ChatGroupServiceImpl service;

    @BeforeEach
    void setUp() {
        ReflectionTestUtils.setField(service, "baseMapper", mapper);
        ReflectionTestUtils.setField(service, "chatGroupMemberService", memberService);
    }

    @Test
    void delegatesGroupQueries() {
        ChatGroup group = new ChatGroup();
        List<ChatGroup> groups = List.of(group);
        // 业务方法签名期望 Long
        when(mapper.selectById(8L)).thenReturn(group);
        when(mapper.getGroupsByUserId(3L)).thenReturn(groups);

        assertEquals(group, service.getGroupById(8L));
        assertEquals(groups, service.getGroupsByUserId(3L));
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
        Long groupId = service.createGroup(1L, "开发组", "avatar", null, List.of(2L, 3L));

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
}
