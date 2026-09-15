package com.stylesmile.chat.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.stylesmile.chat.entity.ChatAppVersion;
import com.stylesmile.chat.mapper.ChatAppVersionMapper;
import com.stylesmile.common.service.BaseServiceImpl;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * ChatAppVersionServiceImpl 单元测试。
 *
 * getNotifyVersion 使用字符串列名的 {@link QueryWrapper}，不依赖 MyBatis-Plus
 * 的 lambda cache，因此可在纯 Mockito 中 mock baseMapper.selectOne 验证查询行为。
 */
@ExtendWith(MockitoExtension.class)
class ChatAppVersionServiceImplTest {

    @Mock
    private ChatAppVersionMapper mapper;

    @InjectMocks
    private ChatAppVersionServiceImpl service;

    @BeforeEach
    void setUp() {
        // 注入 baseMapper（BaseServiceImpl 依赖），供 selectOne 调用
        ReflectionTestUtils.setField(service, "baseMapper", mapper);
    }

    @Test
    void returnsRowAndFiltersByNotifyAndAppType() {
        // 准备 - 服务层 mock 返回一条 android 记录
        ChatAppVersion row = new ChatAppVersion();
        row.setId(1L);
        row.setAppType("android");
        row.setVersion("2.1.0");
        when(mapper.selectOne(any())).thenReturn(row);

        // 执行
        ChatAppVersion result = service.getNotifyVersion("android");

        // 验证 - 返回 mock 的记录
        assertEquals(row, result);

        // 捕获传入 selectOne 的 wrapper，确认过滤条件正确
        ArgumentCaptor<QueryWrapper<ChatAppVersion>> captor =
                ArgumentCaptor.forClass(QueryWrapper.class);
        verify(mapper).selectOne(captor.capture());
        QueryWrapper<ChatAppVersion> wrapper = captor.getValue();

        // is_notify=1（只取开启提示的平台记录）
        assertTrue(wrapper.getSqlSegment().contains("is_notify"),
                "应只查询开启了提示的记录（is_notify=1）");
        // 平台等于 android
        assertTrue(wrapper.getSqlSegment().contains("app_type"),
                "应限定平台为 android");
    }

    @Test
    void noAppTypeQueryDoesNotRestrictPlatform() {
        // 准备 - 不传平台时 mock 返回任意一条
        when(mapper.selectOne(any())).thenReturn(new ChatAppVersion());

        // 执行
        service.getNotifyVersion(null);

        // 捕获 wrapper，确认没有平台过滤值
        ArgumentCaptor<QueryWrapper<ChatAppVersion>> captor =
                ArgumentCaptor.forClass(QueryWrapper.class);
        verify(mapper).selectOne(captor.capture());
        QueryWrapper<ChatAppVersion> wrapper = captor.getValue();

        // 仅过滤 is_notify，不应添加平台条件
        String sql = wrapper.getSqlSegment();
        assertTrue(sql.contains("is_notify"), "无论是否传平台，都应过滤 is_notify=1");
        assertFalse(sql.contains("app_type"),
                "不传平台时不应添加 app_type 过滤");
    }

    @Test
    void returnsNullWhenNoNotifyRecord() {
        // 准备 - 服务层 mock 返回 null（没有任何开启提示的记录）
        when(mapper.selectOne(any())).thenReturn(null);

        // 执行
        ChatAppVersion result = service.getNotifyVersion("desktop");

        // 验证 - 返回 null，前端据此不弹窗
        assertNull(result);
    }
}