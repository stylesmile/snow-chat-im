package com.stylesmile.chat.service.impl;

import com.stylesmile.chat.entity.ChatFriendRequest;
import com.stylesmile.chat.mapper.ChatFriendRequestMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.Spy;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.when;

/**
 * ChatFriendRequestServiceImpl 单元测试
 *
 * 注意：sendRequest / handleRequest 内部使用 MyBatisPlus 的 lambdaQuery()，
 * 需要框架上下文（lambda cache），无法在纯 Mockito 单元测试中覆盖。
 * 此处仅测试 getPendingRequests（直接调用 baseMapper 命名方法）。
 * sendRequest / handleRequest 的行为应由集成测试覆盖。
 */
@ExtendWith(MockitoExtension.class)
class ChatFriendRequestServiceImplTest {

    @Mock
    private ChatFriendRequestMapper mapper;

    @Spy
    private ChatFriendRequestServiceImpl service;

    @BeforeEach
    void setUp() {
        // 注入 baseMapper（BaseServiceImpl 依赖）
        ReflectionTestUtils.setField(service, "baseMapper", mapper);
        // 注入 chatFriendRequestMapper（sendRequest 等方法直接引用此字段）
        ReflectionTestUtils.setField(service, "chatFriendRequestMapper", mapper);
    }

    @Test
    void delegatesPendingRequests() {
        // 准备：getPendingRequests 直接调用 baseMapper.getPendingRequests
        List<ChatFriendRequest> requests = List.of(new ChatFriendRequest());
        // 业务方法签名期望 Long，传入 Long 字面量
        when(mapper.getPendingRequests(2L)).thenReturn(requests);

        // 执行 + 验证
        assertEquals(requests, service.getPendingRequests(2L));
    }
}
