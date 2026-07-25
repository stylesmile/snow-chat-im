package com.stylesmile.chat.controller;

import com.stylesmile.chat.entity.ChatFriend;
import com.stylesmile.chat.entity.ChatFriendRequest;
import com.stylesmile.chat.service.ChatFriendRequestService;
import com.stylesmile.chat.service.ChatFriendService;
import com.stylesmile.common.util.Result;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ChatFriendControllerTest {

    @Mock
    private ChatFriendService chatFriendService;

    @Mock
    private ChatFriendRequestService chatFriendRequestService;

    @InjectMocks
    private ChatFriendController controller;

    @Test
    void listsFriendsForUser() {
        List<ChatFriend> friends = List.of(new ChatFriend());
        when(chatFriendService.getFriendsByUserId(7L)).thenReturn(friends);

        Result<List<ChatFriend>> result = controller.list(7L);

        assertSuccess(result);
        assertEquals(friends, result.getData());
        verify(chatFriendService).getFriendsByUserId(7L);
    }

    @Test
    void sendsFriendRequestFromDto() {
        ChatFriendController.FriendRequestDTO dto = new ChatFriendController.FriendRequestDTO();
        dto.setFromUserId(1L);
        dto.setToUserId(2L);
        dto.setRemark("朋友");

        Result<Void> result = controller.request(dto);

        assertSuccess(result);
        verify(chatFriendRequestService).sendRequest(1L, 2L, "朋友");
    }

    @Test
    void handlesFriendRequestFromDto() {
        ChatFriendController.FriendHandleDTO dto = new ChatFriendController.FriendHandleDTO();
        dto.setFromUserId(1L);
        dto.setToUserId(2L);
        dto.setAccept(true);

        Result<Void> result = controller.handle(dto);

        assertSuccess(result);
        verify(chatFriendRequestService).handleRequest(1L, 2L, true);
    }

    @Test
    void listsPendingRequests() {
        List<ChatFriendRequest> requests = List.of(new ChatFriendRequest());
        when(chatFriendRequestService.getPendingRequests(2L)).thenReturn(requests);

        Result<List<ChatFriendRequest>> result = controller.pending(2L);

        assertSuccess(result);
        assertEquals(requests, result.getData());
    }

    @Test
    void deletesBothDirectionsOfFriendship() {
        // 控制器调用 service.removeFriend(userId, friendId)，由 service 内部负责双向删除
        Result<Void> result = controller.delete(1L, 2L);

        // 删除成功返回 200
        assertSuccess(result);
        // 验证 controller 委托给 service.removeFriend 一次（双向删除在 service 实现内部完成）
        verify(chatFriendService).removeFriend(1L, 2L);
    }

    private void assertSuccess(Result<?> result) {
        assertEquals("200", result.getCode());
    }
}
