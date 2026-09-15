package com.stylesmile.chat.controller;

import com.stylesmile.chat.entity.ChatAppVersion;
import com.stylesmile.chat.service.ChatAppVersionService;
import com.stylesmile.common.util.Result;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * ChatAppVersionController 单元测试。
 *
 * <p>说明：ChatAppVersionServiceImpl 内部使用 MyBatisPlus 的 LambdaQueryWrapper
 * （需要 MyBatisPlus lambda cache 上下文），无法在纯 Mockito 中初始化，
 * 其「取最新 / isNotify 过滤」逻辑由集成测试与启动时 Flyway 迁移验证，
 * 此处聚焦 controller 正确的参数透传与 Result 包裹。
 */
@ExtendWith(MockitoExtension.class)
class ChatAppVersionControllerTest {

    @Mock
    private ChatAppVersionService chatAppVersionService;

    @InjectMocks
    private ChatAppVersionController controller;

    @Test
    void returnsLatestNotifyVersionWhenQueriedWithoutAppType() {
        // 准备 - 服务端返回一条提示更新的版本记录
        ChatAppVersion version = new ChatAppVersion();
        version.setVersion("2.1.0");
        version.setDownloadUrl("https://download.example.com/app.apk");
        when(chatAppVersionService.getNotifyVersion(null)).thenReturn(version);

        // 执行 - 不带 appType 查询
        Result<ChatAppVersion> result = controller.version(null);

        // 验证 - 成功包裹且透传服务端返回的实体
        assertEquals("200", result.getCode());
        assertEquals(version, result.getData());
    }

    @Test
    void passesAppTypeThroughToService() {
        // 准备 - 按平台查
        when(chatAppVersionService.getNotifyVersion("android")).thenReturn(new ChatAppVersion());

        // 执行
        controller.version("android");

        // 验证 - appType 正确下发到 service 层
        verify(chatAppVersionService).getNotifyVersion("android");
    }

    @Test
    void returnsNullDataWhenServiceHasNoMatch() {
        // 准备 - 无匹配（当前已是最新，或未开启提示）
        when(chatAppVersionService.getNotifyVersion(null)).thenReturn(null);

        // 执行
        Result<ChatAppVersion> result = controller.version(null);

        // 验证 - code 仍成功，data 为 null（前端据此判断无需更新）
        assertEquals("200", result.getCode());
        assertNull(result.getData());
    }
}