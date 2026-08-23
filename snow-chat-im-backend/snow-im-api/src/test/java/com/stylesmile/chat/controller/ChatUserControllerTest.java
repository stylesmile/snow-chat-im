package com.stylesmile.chat.controller;

import com.stylesmile.chat.entity.ChatUser;
import com.stylesmile.chat.service.ChatUserService;
import com.stylesmile.chat.service.FileStorageService;
import com.stylesmile.common.util.Result;
import jakarta.servlet.http.HttpServletRequest;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * ChatUserController 单元测试
 *
 * 对齐当前控制器 API：
 * - 当前登录用户 ID 从 HttpServletRequest 的 currentUserId 属性获取（由 AuthFilter 设置）
 * - login / register 返回 Result&lt;Map&gt;，data 包含 token 和 user
 * - search 改为 searchUsers(keyword)（非分页）
 * - updateProfile 入参 UpdateProfileDTO（无 userId 字段），userId 取自 request
 */
@ExtendWith(MockitoExtension.class)
class ChatUserControllerTest {

    @Mock
    private ChatUserService chatUserService;

    @Mock
    private FileStorageService fileStorageService;

    @Mock
    private HttpServletRequest request;

    @InjectMocks
    private ChatUserController controller;

    @Test
    void delegatesLoginAndRegister() {
        // 准备：登录/注册后返回的已注册用户
        ChatUser user = new ChatUser();
        user.setId(1);
        user.setUsername("alice");
        when(chatUserService.login("alice", "secret")).thenReturn(Result.success(user));
        when(chatUserService.register("alice", "secret", "Alice", "alice@example.com", "123456"))
                .thenReturn(Result.success(user));

        // 执行：登录
        ChatUserController.CredentialsDTO credentials = new ChatUserController.CredentialsDTO();
        credentials.setUsername("alice");
        credentials.setPassword("secret");
        Result<Map<String, Object>> loginResult = controller.login(credentials, request);
        // 验证：成功且 data 包含 user 与 token
        assertSuccess(loginResult);
        assertEquals(user, loginResult.getData().get("user"));
        assertNotNull(loginResult.getData().get("token"));
        // token 同时写入 request 属性（兼容旧接口）
        verify(request).setAttribute(eq("currentToken"), any());
        verify(chatUserService).login("alice", "secret");

        // 执行：注册
        ChatUserController.RegisterDTO register = new ChatUserController.RegisterDTO();
        register.setUsername("alice");
        register.setPassword("secret");
        register.setNickname("Alice");
        register.setEmail("alice@example.com");
        register.setCode("123456");
        Result<Map<String, Object>> registerResult = controller.register(register);
        // 验证：成功且 data 包含 user 与 token
        assertSuccess(registerResult);
        assertEquals(user, registerResult.getData().get("user"));
        verify(chatUserService).register("alice", "secret", "Alice", "alice@example.com", "123456");
    }

    private static void loginAs(HttpServletRequest mockRequest, Integer userId) {
        when(mockRequest.getAttribute("currentUserId")).thenReturn(userId);
    }

    @Test
    void returnsUserInfo() {
        // 准备：请求属性携带当前用户 ID
        loginAs(request, 4);
        ChatUser user = new ChatUser();
        when(chatUserService.getUserById(eq(4))).thenReturn(user);

        // 执行
        Result<ChatUser> result = controller.info(request);

        // 验证
        assertSuccess(result);
        assertEquals(user, result.getData());
    }

    /**
     * avatar 为 avatars/ 前缀的 key 时，info 返回前应转换为可访问 URL。
     */
    @Test
    void convertsAvatarKeyToUrl() {
        // 准备：DB 中 avatar 存的是对象 key
        loginAs(request, 4);
        ChatUser user = new ChatUser();
        user.setAvatar("avatars/uuid.jpg");
        when(chatUserService.getUserById(eq(4))).thenReturn(user);
        when(fileStorageService.generateAvatarUrl("avatars/uuid.jpg"))
                .thenReturn("https://img.example.com/avatars/uuid.jpg");

        // 执行
        Result<ChatUser> result = controller.info(request);

        // 验证：返回的 avatar 已转换为可访问 URL
        assertEquals("https://img.example.com/avatars/uuid.jpg", result.getData().getAvatar());
    }

    /**
     * avatar 为非 avatars/ 前缀的旧字符串（如历史 URL）时，原样返回。
     */
    @Test
    void passesThroughLegacyAvatar() {
        loginAs(request, 4);
        ChatUser user = new ChatUser();
        user.setAvatar("https://legacy.example.com/old.png");
        when(chatUserService.getUserById(eq(4))).thenReturn(user);

        Result<ChatUser> result = controller.info(request);

        assertEquals("https://legacy.example.com/old.png", result.getData().getAvatar());
        verify(fileStorageService, never()).generateAvatarUrl(any());
    }

    @Test
    void passesThroughNullAvatar() {
        loginAs(request, 4);
        ChatUser user = new ChatUser();
        user.setAvatar(null);
        when(chatUserService.getUserById(eq(4))).thenReturn(user);

        Result<ChatUser> result = controller.info(request);

        assertEquals(null, result.getData().getAvatar());
        verify(fileStorageService, never()).generateAvatarUrl(any());
    }

    @Test
    void searchesByKeyword() {
        // 准备：模糊搜索结果
        ChatUser user = new ChatUser();
        when(chatUserService.searchUsers("ali")).thenReturn(List.of(user));

        // 执行：searchUsers(keyword)
        Result<List<ChatUser>> result = controller.searchUsers("ali");

        // 验证：返回匹配列表
        assertSuccess(result);
        assertEquals(List.of(user), result.getData());
    }

    /**
     * updateProfile：userId 取自 request，只更新 DTO 中非 null 的字段。
     */
    @Test
    void updatesOnlyProvidedProfileFields() {
        // 准备：DB 中已有用户
        loginAs(request, 4);
        ChatUser user = new ChatUser();
        user.setNickname("old");
        user.setAvatar("old.png");
        user.setSignature("old signature");
        when(chatUserService.getUserById(eq(4))).thenReturn(user);
        // 构造 DTO：只传昵称、签名（avatar 为 null 表示不更新）
        ChatUserController.UpdateProfileDTO dto = new ChatUserController.UpdateProfileDTO();
        dto.setNickname("new");
        dto.setAvatar(null);
        dto.setSignature("new signature");

        // 执行
        Result<Void> result = controller.updateProfile(dto, request);

        // 验证：nickname / signature 更新，avatar 保持原值
        assertSuccess(result);
        assertEquals("new", user.getNickname());
        assertEquals("old.png", user.getAvatar());
        assertEquals("new signature", user.getSignature());
        verify(chatUserService).updateById(user);
    }

    /**
     * 用户不存在时 updateProfile 返回失败，不调用 updateById。
     */
    @Test
    void doesNotUpdateMissingUser() {
        // 准备：request 携带的当前用户不存在
        loginAs(request, 404);
        when(chatUserService.getUserById(eq(404))).thenReturn(null);
        ChatUserController.UpdateProfileDTO dto = new ChatUserController.UpdateProfileDTO();
        dto.setNickname("name");
        dto.setAvatar("avatar");
        dto.setSignature("signature");

        // 执行：返回"用户不存在"（非成功）
        Result<Void> result = controller.updateProfile(dto, request);

        // 验证：失败且未调用 updateById
        assertEquals("500", result.getCode());
        verify(chatUserService, never()).updateById(any());
    }

    private void assertSuccess(Result<?> result) {
        assertEquals("200", result.getCode());
    }
}