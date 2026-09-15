package com.stylesmile.chat.storage;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.io.ByteArrayInputStream;
import java.nio.charset.StandardCharsets;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * InMemoryFileStorage（降级实现）的单元测试。
 * 覆盖 upload / exists / delete / generatePresignedUrl 四个方法。
 *
 * @author mmm
 */
class InMemoryFileStorageTest {

    private InMemoryFileStorage storage; // 被测对象

    @BeforeEach
    void setUp() {
        // 每个测试前创建一个全新的内存存储实例，避免测试间状态污染
        storage = new InMemoryFileStorage();
    }

    /**
     * upload 应返回传入的 fileName（即对象 key），而非 URL。
     * 这与"私有 + Pre-signed URL"策略一致：DB 存 key，URL 单独获取。
     */
    @Test
    void uploadReturnsObjectKeyNotUrl() {
        // 准备一个简单的字节流作为文件内容
        byte[] data = "hello".getBytes(StandardCharsets.UTF_8);
        ByteArrayInputStream input = new ByteArrayInputStream(data);

        // 调用上传，文件名为 avatars/test.jpg
        String result = storage.upload(input, "avatars/test.jpg", "image/jpeg", data.length);

        // 断言返回值就是传入的 fileName（key）
        assertEquals("avatars/test.jpg", result, "upload 应返回对象 key 而非 URL");
    }

    /**
     * upload 后 exists 应返回 true。
     */
    @Test
    void existsReturnsTrueAfterUpload() {
        byte[] data = "hello".getBytes(StandardCharsets.UTF_8);
        storage.upload(new ByteArrayInputStream(data), "avatars/a.png", "image/png", data.length);

        // 断言文件存在
        assertTrue(storage.exists("avatars/a.png"), "上传后 exists 应为 true");
    }

    /**
     * 未上传的文件 exists 应返回 false。
     */
    @Test
    void existsReturnsFalseForMissingFile() {
        // 断言从未上传的文件不存在
        assertFalse(storage.exists("avatars/missing.jpg"), "未上传的文件 exists 应为 false");
    }

    /**
     * delete 后 exists 应返回 false。
     */
    @Test
    void deleteRemovesFile() {
        byte[] data = "hello".getBytes(StandardCharsets.UTF_8);
        storage.upload(new ByteArrayInputStream(data), "avatars/del.jpg", "image/jpeg", data.length);
        // 确认上传成功
        assertTrue(storage.exists("avatars/del.jpg"));

        // 执行删除
        storage.delete("avatars/del.jpg");

        // 断言删除后不再存在
        assertFalse(storage.exists("avatars/del.jpg"), "删除后 exists 应为 false");
    }

    /**
     * generatePresignedUrl 返回 base64 data URL（InMemory 降级策略）。
     *
     * <p>内存实现不生成真正的 pre-signed URL，而是把文件字节编码为
     * {@code data:image/xxx;base64,...} 格式的 data URL，前端可直接用于 img/video/src。
     * 因此断言重点：
     * <ul>
     *   <li>data URL 非空（文件存在才能生成）；</li>
     *   <li>格式符合 {@code data:<contentType>;base64,...} 标准；</li>
     *   <li>base64 段非空（必须包含实际文件内容编码）。</li>
     * </ul>
     *
     * @author mmm
     */
    @Test
    void generatePresignedUrlReturnsDataUrl() {
        // 准备：上传一个图片文件到内存
        byte[] data = "hello".getBytes(StandardCharsets.UTF_8);
        storage.upload(new ByteArrayInputStream(data), "avatars/test.jpg", "image/jpeg", data.length);

        // 调用生成"预签名"URL，有效期 60 分钟（本实现忽略该参数）
        String url = storage.generatePresignedUrl("avatars/test.jpg", 60);

        // 断言 1：data URL 必须非空（文件存在才能生成）
        assertFalse(url.isEmpty(), "data URL 不应为空");
        // 断言 2：格式为 data:image/jpeg;base64,...（JPEG 类型）
        assertTrue(url.startsWith("data:image/jpeg;base64,"),
                "URL 应为 data:image/jpeg;base64 格式");
        // 断言 3：base64 段必须包含实际文件内容编码（"hello" 编码后的 base64 不为空）
        String base64Part = url.substring("data:image/jpeg;base64,".length());
        assertFalse(base64Part.isEmpty(), "base64 段不应为空（必须编码文件数据）");
    }
}
