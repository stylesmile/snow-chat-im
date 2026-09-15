package com.stylesmile.chat.storage;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * SeaweedfsFileStorage 的单元测试（仅测试 generateUrl 方法，避免网络依赖）。
 * upload / delete / exists 需要真实 SeaweedFS 实例，由集成测试覆盖。
 *
 * <p>generateUrl 测试要点：
 * <ul>
 *   <li>公共读模式：返回 endpoint + fileName 完整 URL；</li>
 *   <li>publicBaseUrl 有值时，优先使用 publicBaseUrl；</li>
 *   <li>fileName 已是完整 URL 时，直接返回；</li>
 *   <li>正确处理首尾斜杠（避免双斜杠或丢失斜杠）。</li>
 * </ul>
 *
 * @author mmm
 */
class SeaweedfsFileStorageTest {

    /**
     * 公共读模式下，generateUrl 应返回 endpoint + fileName 的完整 URL。
     */
    @Test
    void generateUrlReturnsFullUrlInPublicReadMode() {
        // 构造公共读模式的 SeaweedFS 属性
        SeaweedfsProperties props = new SeaweedfsProperties(
                true,                                       // enabled
                "http://127.0.0.1:8888",                   // endpoint
                "/1",                                       // uploadPath
                true,                                       // publicRead
                ""                                          // publicBaseUrl（空，使用 endpoint）
        );
        // 构造 SeaweedfsFileStorage（需要 SeaweedfsProperties 即可，upload/delete/exists 不在此测试范围）
        SeaweedfsFileStorage storage = new SeaweedfsFileStorage(props);

        // 调用 generateUrl，传入相对 key
        String url = storage.generateUrl("avatars/550e8400-e29b-41d4-a716-446655440000.jpg");

        // 断言返回完整 URL，且以 endpoint 开头、包含 fileName
        assertTrue(url.startsWith("http://127.0.0.1:8888/"), "URL 应以 endpoint 开头");
        assertTrue(url.contains("avatars/"), "URL 应包含目录前缀 avatars/");
        assertTrue(url.endsWith(".jpg"), "URL 应以 .jpg 结尾");
    }

    /**
     * publicBaseUrl 有值时，generateUrl 应优先使用 publicBaseUrl 而非 endpoint。
     */
    @Test
    void generateUrlUsesPublicBaseUrlWhenSet() {
        // 构造带有 publicBaseUrl 的 SeaweedFS 属性
        SeaweedfsProperties props = new SeaweedfsProperties(
                true,                                       // enabled
                "http://localhost:8888",                   // endpoint（内部地址）
                "/1",                                       // uploadPath
                true,                                       // publicRead
                "https://cdn.example.com"                  // publicBaseUrl（外部 CDN）
        );
        SeaweedfsFileStorage storage = new SeaweedfsFileStorage(props);

        // 调用 generateUrl
        String url = storage.generateUrl("images/abc123.png");

        // 断言使用 publicBaseUrl，不使用 endpoint
        assertTrue(url.startsWith("https://cdn.example.com/"), "URL 应以 publicBaseUrl 开头");
        assertNotEquals(url.startsWith("http://localhost:8888"), true, "不应使用内部 endpoint");
        assertTrue(url.contains("images/"), "URL 应包含目录前缀 images/");
    }

    /**
     * fileName 已是完整 HTTP URL 时，generateUrl 应原样返回（避免重复拼接）。
     */
    @Test
    void generateUrlReturnsOriginalUrlWhenAlreadyFull() {
        SeaweedfsProperties props = new SeaweedfsProperties(
                true, "http://localhost:8888", "/1", true, ""
        );
        SeaweedfsFileStorage storage = new SeaweedfsFileStorage(props);

        // 传入已是完整 URL 的 fileName
        String original = "https://cdn.example.com/avatars/old.jpg";
        String result = storage.generateUrl(original);

        // 断言原样返回
        assertEquals(original, result, "已是完整 URL 时应原样返回");
    }

    /**
     * 处理 endpoint 尾斜杠与 fileName 首斜杠，避免生成双斜杠 URL。
     */
    @Test
    void generateUrlTrimsRedundantSlashes() {
        // endpoint 带尾斜杠，fileName 带首斜杠
        SeaweedfsProperties props = new SeaweedfsProperties(
                true, "http://localhost:8888/", "/1/", true, ""
        );
        SeaweedfsFileStorage storage = new SeaweedfsFileStorage(props);

        String url = storage.generateUrl("/avatars/test.jpg");

        // 断言不含双斜杠（除协议部分 // 外）
        assertTrue(!url.contains(":///") && !url.substring(7).contains("//"),
                "URL 不应含有冗余双斜杠，实际: " + url);
        // 断言格式正确
        assertTrue(url.startsWith("http://localhost:8888/"), "URL 格式应正确");
    }
}
