package com.stylesmile.chat.storage;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * AliyunOssProperties 配置属性类的单元测试。
 *
 * <p>验证要点：
 * <ul>
 *   <li>缺失字段的兜底（endpoint / bucket / 签名有效期），保证只填 ak/sk 也能启动；</li>
 *   <li>显式配置必须原样保留（不能被兜底逻辑覆盖）；</li>
 *   <li>resolvePublicBaseUrl() 在"自定义域名"与"未配置域名"两种场景下的推导正确性。</li>
 * </ul>
 *
 * @author mmm
 */
class AliyunOssPropertiesTest {

    /**
     * endpoint 为空时应兜底为杭州区域的公共端点。
     */
    @Test
    void defaultsEndpointWhenBlank() {
        // 构造 endpoint 为空的配置（模拟只填了 ak/sk 的粗心配置）
        AliyunOssProperties props = new AliyunOssProperties(
                "",                 // endpoint（空，触发兜底）
                "ak",               // accessKeyId
                "sk",               // accessKeySecret
                "snow-chat",        // bucket
                "",                 // publicBaseUrl
                false,              // publicRead
                0                   // presignExpirationMinutes（0，触发兜底）
        );

        // 断言 endpoint 被兜底为非空且是 https
        assertFalse(props.endpoint().isBlank(), "endpoint 为空时应兜底为非空值");
        assertTrue(props.endpoint().startsWith("https://"), "兜底 endpoint 应为 https 协议");
        // 断言签名有效期被兜底为 7 天（10080 分钟）
        assertEquals(7 * 24 * 60, props.presignExpirationMinutes(),
                "签名有效期未配置时应兜底为 7 天");
    }

    /**
     * bucket 为空时应兜底为 snow-chat（与 MinIO 配置保持一致的命名）。
     */
    @Test
    void defaultsBucketWhenBlank() {
        AliyunOssProperties props = new AliyunOssProperties(
                "https://oss-cn-hangzhou.aliyuncs.com",
                "ak", "sk",
                "",                 // bucket（空，触发兜底）
                "", false, 60
        );

        // 断言 bucket 被兜底
        assertEquals("snow-chat", props.bucket(), "bucket 为空时应默认为 snow-chat");
    }

    /**
     * 显式配置的值必须原样保留。
     */
    @Test
    void keepsExplicitValues() {
        AliyunOssProperties props = new AliyunOssProperties(
                "https://oss-cn-shenzhen.aliyuncs.com",  // endpoint
                "LTAI5tExampleAccessKeyId",              // accessKeyId
                "ExampleAccessKeySecret",                // accessKeySecret
                "win-chat",                              // bucket
                "https://cdn.winchat.club",              // publicBaseUrl
                true,                                    // publicRead
                120                                      // presignExpirationMinutes
        );

        // 断言所有显式值被保留
        assertEquals("https://oss-cn-shenzhen.aliyuncs.com", props.endpoint(), "应保留显式 endpoint");
        assertEquals("LTAI5tExampleAccessKeyId", props.accessKeyId(), "应保留 accessKeyId");
        assertEquals("win-chat", props.bucket(), "应保留显式 bucket");
        assertEquals("https://cdn.winchat.club", props.publicBaseUrl(), "应保留 publicBaseUrl");
        assertTrue(props.publicRead(), "应保留 publicRead=true");
        assertEquals(120, props.presignExpirationMinutes(), "应保留显式签名有效期");
    }

    /**
     * 配置了自定义域名（CDN）时，resolvePublicBaseUrl 应返回该域名并去掉尾部斜杠。
     */
    @Test
    void resolvePublicBaseUrlUsesCustomDomainWhenSet() {
        AliyunOssProperties props = new AliyunOssProperties(
                "https://oss-cn-hangzhou.aliyuncs.com", "ak", "sk",
                "snow-chat",
                "https://cdn.winchat.club/",   // 自定义域名（带尾斜杠）
                true, 60
        );

        // 断言使用自定义域名且尾斜杠被清理（避免拼出双斜杠 URL）
        assertEquals("https://cdn.winchat.club", props.resolvePublicBaseUrl(),
                "应使用自定义域名并去掉尾部斜杠");
    }

    /**
     * 未配置自定义域名时，resolvePublicBaseUrl 应按 OSS 规则推导为
     * {@code https://{bucket}.{endpoint主机名}}（virtual-hosted style）。
     */
    @Test
    void resolvePublicBaseUrlDerivesFromEndpointWhenBlank() {
        AliyunOssProperties props = new AliyunOssProperties(
                "https://oss-cn-hangzhou.aliyuncs.com", "ak", "sk",
                "snow-chat",
                "",                            // 未配置自定义域名
                true, 60
        );

        // 断言推导出 virtual-hosted 形式的 bucket 域名
        assertEquals("https://snow-chat.oss-cn-hangzhou.aliyuncs.com",
                props.resolvePublicBaseUrl(),
                "未配置域名时应按 bucket + endpoint 主机名推导");
    }
}
