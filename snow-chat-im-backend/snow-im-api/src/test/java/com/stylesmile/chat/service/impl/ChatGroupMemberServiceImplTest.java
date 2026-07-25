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
        // 业务方法签名期望 Long
        when(mapper.getMembersByGroupId(9L)).thenReturn(members);

        assertEquals(members, service.getMembersByGroupId(9L));
    }

    @Test
    void createsMemberWithDefaults() {
        doReturn(true).when(service).save(any(ChatGroupMember.class));

        // addMember 签名期望 Long
        service.addMember(9L, 3L);

        ArgumentCaptor<ChatGroupMember> captor = ArgumentCaptor.forClass(ChatGroupMember.class);
        verify(service).save(captor.capture());
        ChatGroupMember member = captor.getValue();
        assertEquals(9L, member.getGroupId());
        assertEquals(3L, member.getUserId());
        assertEquals("member", member.getRole());
        assertEquals(0, member.getMute());
        assertNotNull(member.getJoinTime());
    }

    // 注意：isMember 内部使用 MyBatisPlus 的 lambdaQuery().exists()，
    // 需要框架上下文（lambda cache / mapperInterface），无法在纯 Mockito 单元测试中覆盖。
    // isMember 的行为应由集成测试覆盖。
}
