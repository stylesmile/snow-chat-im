package com.stylesmile.chat.storage;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;

/**
 * MinioProperties 配置属性类的单元测试。
 * 验证默认值与规范化逻辑（region/bucket 缺省时的兜底）。
 *
 * @author mmm
 */
class MinioPropertiesTest {

    /**
     * 当 region 为空时，应使用默认值 us-east-1。
     */
    @Test
    void defaultsRegionToUsEast1WhenBlank() {
        // 构造一个 region 为空的属性对象（模拟配置缺失场景）
        MinioProperties props = new MinioProperties(
                false,                      // enabled
                "http://localhost:9000",    // endpoint
                "minioadmin",               // accessKey
                "minioadmin",               // secretKey
                "",                         // bucket（空，触发默认）
                "",                         // publicUrl
                "",                         // region（空，触发默认）
                false                       // publicReadPolicy
        );
        // 断言 region 被规范化为 us-east-1
        assertEquals("us-east-1", props.region(), "region 为空时应默认为 us-east-1");
        // 断言 bucket 被规范化为 snow-chat
        assertEquals("snow-chat", props.bucket(), "bucket 为空时应默认为 snow-chat");
    }

    /**
     * 当显式提供 region 与 bucket 时，应保留用户配置。
     */
    @Test
    void keepsExplicitRegionAndBucket() {
        // 构造一个显式提供所有字段的属性对象
        MinioProperties props = new MinioProperties(
                true,                       // enabled
                "http://minio:9000",        // endpoint
                "ak",                       // accessKey
                "sk",                       // secretKey
                "my-bucket",                // bucket
                "https://cdn.example.com",  // publicUrl
                "ap-southeast-1",           // region
                false                       // publicReadPolicy
        );
        // 断言显式值被保留
        assertEquals("ap-southeast-1", props.region(), "应保留显式 region");
        assertEquals("my-bucket", props.bucket(), "应保留显式 bucket");
        assertEquals("http://minio:9000", props.endpoint(), "应保留 endpoint");
    }

    /**
     * 默认 enabled 应为 false（matchIfMissing 时降级到 InMemoryFileStorage）。
     */
    @Test
    void enabledDefaultsToFalseWhenNotSet() {
        // 构造 enabled=false 的属性
        MinioProperties props = new MinioProperties(
                false, "http://localhost:9000", "ak", "sk",
                "snow-chat", "", "us-east-1", false
        );
        // 断言 enabled 为 false
        assertFalse(props.enabled(), "未启用时应为 false");
    }
}
