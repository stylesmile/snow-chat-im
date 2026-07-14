package com.stylesmile.chat.controller;

import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.stylesmile.chat.entity.ChatUser;
import com.stylesmile.chat.service.ChatUserService;
import com.stylesmile.common.util.Result;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doReturn;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ChatUserControllerTest {

    @Mock
    private ChatUserService chatUserService;

    @InjectMocks
    private ChatUserController controller;

    @Test
    void delegatesLoginAndRegister() {
        Result<?> loginResult = Result.success("token");
        Result<?> registerResult = Result.success();
        ChatUserController.CredentialsDTO credentials = new ChatUserController.CredentialsDTO();
        credentials.setUsername("alice");
        credentials.setPassword("secret");
        ChatUserController.RegisterDTO register = new ChatUserController.RegisterDTO();
        register.setUsername("alice");
        register.setPassword("secret");
        register.setNickname("Alice");
        register.setEmail("alice@example.com");
        when(chatUserService.login("alice", "secret")).thenReturn(loginResult);
        when(chatUserService.register("alice", "secret", "Alice", "alice@example.com"))
                .thenReturn(registerResult);

        assertEquals(loginResult, controller.login(credentials));
        assertEquals(registerResult, controller.register(register));
        verify(chatUserService).login("alice", "secret");
        verify(chatUserService).register("alice", "secret", "Alice", "alice@example.com");
    }

    @Test
    void returnsUserInfo() {
        ChatUser user = new ChatUser();
        when(chatUserService.getUserById(4)).thenReturn(user);

        Result<ChatUser> result = controller.info(4);

        assertSuccess(result);
        assertEquals(user, result.getData());
    }

    @Test
    void searchesWithRequestedPageAndSize() {
        Page<ChatUser> page = new Page<>(2, 5);
        ChatUser user = new ChatUser();
        page.setRecords(List.of(user));
        doReturn(page).when(chatUserService).page(any(Page.class), any());

        Result<List<ChatUser>> result = controller.search("ali", 2, 5);

        assertSuccess(result);
        assertEquals(List.of(user), result.getData());
        ArgumentCaptor<Page<ChatUser>> pageCaptor = ArgumentCaptor.forClass(Page.class);
        verify(chatUserService).page(pageCaptor.capture(), any());
        assertEquals(2, pageCaptor.getValue().getCurrent());
        assertEquals(5, pageCaptor.getValue().getSize());
    }

    @Test
    void updatesOnlyProvidedProfileFields() {
        ChatUser user = new ChatUser();
        user.setNickname("old");
        user.setAvatar("old.png");
        user.setSignature("old signature");
        when(chatUserService.getUserById(4)).thenReturn(user);

        Result<Void> result = controller.updateProfile(4, "new", null, "new signature");

        assertSuccess(result);
        assertEquals("new", user.getNickname());
        assertEquals("old.png", user.getAvatar());
        assertEquals("new signature", user.getSignature());
        verify(chatUserService).updateById(user);
    }

    @Test
    void doesNotUpdateMissingUser() {
        when(chatUserService.getUserById(404)).thenReturn(null);

        assertSuccess(controller.updateProfile(404, "name", "avatar", "signature"));

        org.mockito.Mockito.verify(chatUserService, org.mockito.Mockito.never()).updateById(any());
    }

    private void assertSuccess(Result<?> result) {
        assertEquals("200", result.getCode());
    }
}
