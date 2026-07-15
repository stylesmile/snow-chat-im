package com.stylesmile.chat.service.impl;

import com.stylesmile.chat.entity.ChatGroupMember;
import com.stylesmile.chat.mapper.ChatGroupMemberMapper;
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
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doReturn;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ChatGroupMemberServiceImplTest {

    @Mock
    private ChatGroupMemberMapper mapper;

    @Spy
    private ChatGroupMemberServiceImpl service;

    @BeforeEach
    void setUp() {
        ReflectionTestUtils.setField(service, "baseMapper", mapper);
    }

    @Test
    void delegatesMemberQuery() {
        List<ChatGroupMember> members = List.of(new ChatGroupMember());
        when(mapper.getMembersByGroupId(9)).thenReturn(members);

        assertEquals(members, service.getMembersByGroupId(9));
    }

    @Test
    void createsMemberWithDefaults() {
        doReturn(true).when(service).save(any(ChatGroupMember.class));

        service.addMember(9, 3);

        ArgumentCaptor<ChatGroupMember> captor = ArgumentCaptor.forClass(ChatGroupMember.class);
        verify(service).save(captor.capture());
        ChatGroupMember member = captor.getValue();
        assertEquals(9, member.getGroupId());
        assertEquals(3, member.getUserId());
        assertEquals("member", member.getRole());
        assertEquals(0, member.getMute());
        assertNotNull(member.getJoinTime());
    }

    @Test
    void checksMembershipUsingMapper() {
        when(mapper.selectCount(any())).thenReturn(1L);

        assertTrue(service.isMember(9, 3));
        verify(mapper).selectCount(any());
    }
}
