package com.stylesmile.chat.service.impl;

import com.stylesmile.chat.entity.ChatFriendRequest;
import com.stylesmile.chat.mapper.ChatFriendRequestMapper;
import com.stylesmile.chat.service.ChatFriendService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.Spy;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.Date;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doReturn;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ChatFriendRequestServiceImplTest {

    @Mock
    private ChatFriendRequestMapper mapper;

    @Mock
    private ChatFriendService friendService;

    @Spy
    private ChatFriendRequestServiceImpl service;

    @BeforeEach
    void setUp() {
        ReflectionTestUtils.setField(service, "baseMapper", mapper);
        ReflectionTestUtils.setField(service, "chatFriendRequestMapper", mapper);
        ReflectionTestUtils.setField(service, "chatFriendService", friendService);
    }

    @Test
    void delegatesPendingRequests() {
        List<ChatFriendRequest> requests = List.of(new ChatFriendRequest());
        when(mapper.getPendingRequests(2)).thenReturn(requests);

        assertEquals(requests, service.getPendingRequests(2));
    }

    @Test
    void savesPendingRequest() {
        doReturn(true).when(service).save(any(ChatFriendRequest.class));

        service.sendRequest(1, 2, "hello");

        ArgumentCaptor<ChatFriendRequest> captor = ArgumentCaptor.forClass(ChatFriendRequest.class);
        verify(service).save(captor.capture());
        ChatFriendRequest request = captor.getValue();
        assertEquals(1, request.getFromUserId());
        assertEquals(2, request.getToUserId());
        assertEquals("pending", request.getStatus());
        assertEquals("hello", request.getRemark());
        assertNotNull(request.getCreateTime());
    }

    @Test
    void acceptsRequestAndAddsFriend() {
        ChatFriendRequest request = request();
        when(mapper.selectOne(any())).thenReturn(request);
        doReturn(true).when(service).updateById(request);

        service.handleRequest(1, 2, true);

        assertEquals("accepted", request.getStatus());
        verify(service).updateById(request);
        verify(friendService).addFriend(1, 2);
    }

    @Test
    void rejectsRequestWithoutAddingFriend() {
        ChatFriendRequest request = request();
        when(mapper.selectOne(any())).thenReturn(request);
        doReturn(true).when(service).updateById(request);

        service.handleRequest(1, 2, false);

        assertEquals("rejected", request.getStatus());
        verify(service).updateById(request);
        verify(friendService, never()).addFriend(any(), any());
    }

    private ChatFriendRequest request() {
        ChatFriendRequest request = new ChatFriendRequest();
        request.setFromUserId(1);
        request.setToUserId(2);
        request.setStatus("pending");
        request.setCreateTime(new Date());
        return request;
    }
}
