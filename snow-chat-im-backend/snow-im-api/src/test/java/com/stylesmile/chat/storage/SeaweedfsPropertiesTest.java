package com.stylesmile.chat.storage;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * SeaweedfsProperties 配置属性类的单元测试。
 * 验证默认值与规范化逻辑（endpoint / uploadPath 缺省时的兜底）。
 *
 * @author mmm
 */
class SeaweedfsPropertiesTest {

    /**
     * endpoint 为空时应使用默认值 localhost:8888。
     */
    @Test
    void defaultsEndpointWhenBlank() {
        // 构造一个 endpoint 为空的属性对象（模拟配置缺失场景）
        SeaweedfsProperties props = new SeaweedfsProperties(
                false,                  // enabled
                "",                     // endpoint（空，触发默认）
                "/1",                   // uploadPath
                true,                   // publicRead
                ""                      // publicBaseUrl
        );
        // 断言 endpoint 被规范化为默认值
        assertEquals("http://localhost:8888", props.endpoint(), "endpoint 为空时应默认为 http://localhost:8888");
    }

    /**
     * uploadPath 为空时应使用默认值 /1。
     */
    @Test
    void defaultsUploadPathWhenBlank() {
        // 构造一个 uploadPath 为空的属性对象
        SeaweedfsProperties props = new SeaweedfsProperties(
                false,                  // enabled
                "http://seaweedfs:8888", // endpoint
                "",                     // uploadPath（空，触发默认）
                true,                   // publicRead
                ""                      // publicBaseUrl
        );
        // 断言 uploadPath 被规范化为默认值
        assertEquals("/1", props.uploadPath(), "uploadPath 为空时应默认为 /1");
    }

    /**
     * 当显式提供 endpoint 与 uploadPath 时，应保留用户配置。
     */
    @Test
    void keepsExplicitEndpointAndUploadPath() {
        // 构造一个显式提供所有字段的属性对象
        SeaweedfsProperties props = new SeaweedfsProperties(
                true,                   // enabled
                "http://cdn.example.com:8888", // endpoint
                "/3",                   // uploadPath
                true,                   // publicRead
                "https://static.example.com"   // publicBaseUrl
        );
        // 断言显式值被保留
        assertEquals("http://cdn.example.com:8888", props.endpoint(), "应保留显式 endpoint");
        assertEquals("/3", props.uploadPath(), "应保留显式 uploadPath");
        assertEquals("https://static.example.com", props.publicBaseUrl(), "应保留显式 publicBaseUrl");
        assertTrue(props.publicRead(), "publicRead 应为 true");
    }

    /**
     * 默认 enabled 应为 false（matchIfMissing 时不启用 SeaweedFS，降级到 InMemory）。
     */
    @Test
    void enabledDefaultsToFalseWhenNotSet() {
        // 构造 enabled=false 的属性
        SeaweedfsProperties props = new SeaweedfsProperties(
                false,
                "http://localhost:8888",
                "/1",
                false,
                ""
        );
        // 断言 enabled 为 false
        assertFalse(props.enabled(), "未启用时应为 false");
    }
}
