package com.stylesmile.chat.controller;

import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.stylesmile.chat.entity.ChatUser;
import com.stylesmile.chat.service.ChatUserService;
import com.stylesmile.chat.storage.FileStorage;
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
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doReturn;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * ChatUserController 单元测试
 *
 * 覆盖：
 * 1. login / register 委托
 * 2. info 返回用户信息（avatar key → pre-signed URL 转换 / 旧 URL 原样返回）
 * 3. search 分页
 * 4. updateProfile（@RequestBody UpdateProfileDTO）只更新提供的字段
 */
@ExtendWith(MockitoExtension.class)
class ChatUserControllerTest {

    @Mock
    private ChatUserService chatUserService;

    /**
     * FileStorage mock：用于 info 端点将 avatars/ 前缀的 key 转换为 pre-signed URL。
     */
    @Mock
    private FileStorage fileStorage;

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

    /**
     * avatar 为 avatars/ 前缀的 key 时，info 返回前应转换为 pre-signed URL。
     */
    @Test
    void convertsAvatarKeyToPresignedUrl() {
        // 准备：DB 中 avatar 存的是对象 key
        ChatUser user = new ChatUser();
        user.setAvatar("avatars/uuid.jpg");
        when(chatUserService.getUserById(4)).thenReturn(user);
        // mock：生成 7 天有效的 pre-signed URL
        when(fileStorage.generatePresignedUrl(eq("avatars/uuid.jpg"), eq(7 * 24 * 60)))
                .thenReturn("https://presigned.example.com/avatars/uuid.jpg");

        // 执行
        Result<ChatUser> result = controller.info(4);

        // 验证：返回的 avatar 已转换为 pre-signed URL
        assertSuccess(result);
        assertEquals("https://presigned.example.com/avatars/uuid.jpg", result.getData().getAvatar());
    }

    /**
     * avatar 为非 avatars/ 前缀的旧字符串（如历史 URL）时，原样返回。
     */
    @Test
    void passesThroughLegacyAvatar() {
        // 准备：旧数据 avatar 是一个完整 URL（非 avatars/ 前缀）
        ChatUser user = new ChatUser();
        user.setAvatar("https://legacy.example.com/old.png");
        when(chatUserService.getUserById(4)).thenReturn(user);

        // 执行
        Result<ChatUser> result = controller.info(4);

        // 验证：avatar 原样返回，不调用 FileStorage
        assertSuccess(result);
        assertEquals("https://legacy.example.com/old.png", result.getData().getAvatar());
        verify(fileStorage, never()).generatePresignedUrl(any(), org.mockito.ArgumentMatchers.anyInt());
    }

    /**
     * avatar 为 null 时原样返回（不调用 FileStorage）。
     */
    @Test
    void passesThroughNullAvatar() {
        ChatUser user = new ChatUser();
        user.setAvatar(null);
        when(chatUserService.getUserById(4)).thenReturn(user);

        Result<ChatUser> result = controller.info(4);

        assertSuccess(result);
        assertEquals(null, result.getData().getAvatar());
        verify(fileStorage, never()).generatePresignedUrl(any(), org.mockito.ArgumentMatchers.anyInt());
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

    /**
     * updateProfile 改用 @RequestBody UpdateProfileDTO 入参。
     * 只更新 DTO 中非 null 的字段。
     */
    @Test
    void updatesOnlyProvidedProfileFields() {
        // 准备：DB 中已有用户
        ChatUser user = new ChatUser();
        user.setNickname("old");
        user.setAvatar("old.png");
        user.setSignature("old signature");
        when(chatUserService.getUserById(4)).thenReturn(user);
        // 构造 DTO：只传 userId、nickname、signature，avatar 为 null（不更新）
        ChatUserController.UpdateProfileDTO dto = new ChatUserController.UpdateProfileDTO();
        dto.setUserId(4);
        dto.setNickname("new");
        dto.setAvatar(null);
        dto.setSignature("new signature");

        // 执行
        Result<Void> result = controller.updateProfile(dto);

        // 验证：nickname 和 signature 更新，avatar 保持原值
        assertSuccess(result);
        assertEquals("new", user.getNickname());
        assertEquals("old.png", user.getAvatar());
        assertEquals("new signature", user.getSignature());
        verify(chatUserService).updateById(user);
    }

    /**
     * 用户不存在时 updateProfile 不调用 updateById，仍返回成功。
     */
    @Test
    void doesNotUpdateMissingUser() {
        when(chatUserService.getUserById(404)).thenReturn(null);
        ChatUserController.UpdateProfileDTO dto = new ChatUserController.UpdateProfileDTO();
        dto.setUserId(404);
        dto.setNickname("name");
        dto.setAvatar("avatar");
        dto.setSignature("signature");

        assertSuccess(controller.updateProfile(dto));

        verify(chatUserService, never()).updateById(any());
    }

    private void assertSuccess(Result<?> result) {
        assertEquals("200", result.getCode());
    }
}
