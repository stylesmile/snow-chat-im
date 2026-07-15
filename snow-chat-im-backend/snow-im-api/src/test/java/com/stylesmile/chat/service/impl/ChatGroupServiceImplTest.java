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
        when(mapper.selectById(8)).thenReturn(group);
        when(mapper.getGroupsByUserId(3)).thenReturn(groups);

        assertEquals(group, service.getGroupById(8));
        assertEquals(groups, service.getGroupsByUserId(3));
    }

    @Test
    void createsGroupWithDefaultLimitAndMembers() {
        doAnswer(invocation -> {
            ChatGroup group = invocation.getArgument(0);
            group.setId(20);
            return true;
        }).when(service).save(any(ChatGroup.class));

        Integer groupId = service.createGroup(1, "开发组", "avatar", null, List.of(2, 3));

        assertEquals(20, groupId);
        ArgumentCaptor<ChatGroup> captor = ArgumentCaptor.forClass(ChatGroup.class);
        verify(service).save(captor.capture());
        ChatGroup group = captor.getValue();
        assertEquals(1, group.getOwnerId());
        assertEquals("开发组", group.getName());
        assertEquals(500, group.getMaxMembers());
        assertEquals(0, group.getDelFlag());
        assertNotNull(group.getCreateTime());
        assertNotNull(group.getUpdateTime());
        verify(memberService).addMember(20, 2);
        verify(memberService).addMember(20, 3);
    }

    @Test
    void createsGroupWithoutMembersUsingProvidedLimit() {
        doAnswer(invocation -> {
            ChatGroup group = invocation.getArgument(0);
            group.setId(21);
            return true;
        }).when(service).save(any(ChatGroup.class));

        assertEquals(21, service.createGroup(1, "群", null, 50, null));

        ArgumentCaptor<ChatGroup> captor = ArgumentCaptor.forClass(ChatGroup.class);
        verify(service).save(captor.capture());
        assertEquals(50, captor.getValue().getMaxMembers());
    }
}
