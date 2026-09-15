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
 * 验证：
 * 1. version 接口把客户端传入的 appType 透传给服务层
 * 2. 服务层返回的记录被包进 Result 返回给前端
 * 3. 服务层返回 null（无提示记录）时,Result 的 data 为 null
 */
@ExtendWith(MockitoExtension.class)
class ChatAppVersionControllerTest {

    @Mock
    private ChatAppVersionService chatAppVersionService;

    @InjectMocks
    private ChatAppVersionController controller;

    @Test
    void versionReturnsLatestNotifyRecordAndForwardsAppType() {
        // 准备 - 服务层返回一条 android 平台的可提示版本
        ChatAppVersion version = new ChatAppVersion();
        version.setAppType("android");
        version.setVersion("2.1.0");
        version.setDownloadUrl("https://dl.test/app.apk");
        version.setIsNotify(1);
        when(chatAppVersionService.getNotifyVersion("android")).thenReturn(version);

        // 执行 - 携带 appType=android 调用接口
        Result<ChatAppVersion> result = controller.version("android");

        // 验证 - 透传 appType，且记录被包进 Result.data
        verify(chatAppVersionService).getNotifyVersion("android");
        assertEquals("200", result.getCode());
        assertEquals("2.1.0", result.getData().getVersion());
        assertEquals("https://dl.test/app.apk", result.getData().getDownloadUrl());
    }

    @Test
    void versionReturnsNullDataWhenNoNotifyRecord() {
        // 准备 - 服务层返回 null（该平台未开启提示或有记录但无可提示的）
        when(chatAppVersionService.getNotifyVersion("ios")).thenReturn(null);

        // 执行
        Result<ChatAppVersion> result = controller.version("ios");

        // 验证 - data 为 null，前端据此判断"无需弹窗"
        assertEquals("200", result.getCode());
        assertNull(result.getData());
    }

    @Test
    void versionForwardsNullAppTypeWhenNotProvided() {
        // 准备 - appType 为空时服务层取任意平台最新一条
        when(chatAppVersionService.getNotifyVersion(null)).thenReturn(null);

        // 执行 - 不传 appType
        Result<ChatAppVersion> result = controller.version(null);

        // 验证 - 以 null 传递，不报参数错误
        verify(chatAppVersionService).getNotifyVersion(null);
        assertEquals("200", result.getCode());
        assertNull(result.getData());
    }
}