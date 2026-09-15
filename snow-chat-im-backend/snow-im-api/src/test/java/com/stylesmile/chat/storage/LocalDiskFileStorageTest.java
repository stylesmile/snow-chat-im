package com.stylesmile.chat.storage;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * LocalDiskFileStorage（{@code storage.type=disk}）单元测试。
 *
 * <p>重点守住三件事：
 * <ol>
 *   <li>上传生成的访问地址是真实 HTTP URL（{@code {publicUrl}/file/raw/{key}}），
 *       而不是 base64 data URL —— 这是「消息体里塞 base64」问题的回归防护；</li>
 *   <li>文件确实落盘且可被 {@link FileStorage#load} 读回；</li>
 *   <li>路径穿越的 key 必须被拒绝。</li>
 * </ol>
 *
 * @author mmm
 */
class LocalDiskFileStorageTest {

    @TempDir
    Path tempDir;

    private LocalDiskFileStorage storage;

    @BeforeEach
    void setUp() throws Exception {
        // 用临时目录作为落盘根目录，避免测试污染真实 ~/snow-file
        storage = new LocalDiskFileStorage(
                new DiskProperties(tempDir.toString(), "http://192.168.0.100:8091"));
    }

    /**
     * upload 应把字节真正写入磁盘，并返回原始 key。
     */
    @Test
    void uploadWritesFileToDisk() {
        // 上传一段图片内容到 images/ 目录
        String key = storage.upload(
                new ByteArrayInputStream("image-bytes".getBytes(StandardCharsets.UTF_8)),
                "images/uuid.jpg", "image/jpeg", 11);

        assertEquals("images/uuid.jpg", key, "upload 应原样返回对象 key");
        assertTrue(Files.isRegularFile(tempDir.resolve("images/uuid.jpg")),
                "文件应真实落盘到 images/uuid.jpg");
    }

    /**
     * 生成的访问地址必须是 HTTP URL，不能是 base64 data URL。
     */
    @Test
    void generateUrlReturnsHttpUrlNotBase64() {
        storage.upload(new ByteArrayInputStream("x".getBytes(StandardCharsets.UTF_8)),
                "images/uuid.jpg", "image/jpeg", 1);

        String url = storage.generatePresignedUrl("images/uuid.jpg", 60);

        assertEquals("http://192.168.0.100:8091/file/raw/images/uuid.jpg", url,
                "访问地址应为可直接在浏览器/手机上打开的 HTTP URL");
        assertFalse(url.startsWith("data:"), "不应再返回内嵌 base64 的 data URL");
    }

    /**
     * load 应能读回已上传的内容，未上传过则返回 null。
     */
    @Test
    void loadReadsBackContentAndReturnsNullWhenMissing() throws Exception {
        storage.upload(new ByteArrayInputStream("hello".getBytes(StandardCharsets.UTF_8)),
                "voices/uuid.m4a", "audio/mp4", 5);

        try (InputStream in = storage.load("voices/uuid.m4a")) {
            assertNotNull(in, "已上传的文件应能读到输入流");
            assertEquals("hello", new String(in.readAllBytes(), StandardCharsets.UTF_8),
                    "读回的字节应与上传内容一致");
        }
        assertNull(storage.load("images/not-exist.jpg"), "不存在的 key 应返回 null");
    }

    /**
     * exists / delete 的语义。
     */
    @Test
    void existsAndDeleteBehaveAsExpected() {
        storage.upload(new ByteArrayInputStream("x".getBytes(StandardCharsets.UTF_8)),
                "files/uuid.pdf", "application/pdf", 1);
        assertTrue(storage.exists("files/uuid.pdf"), "刚上传的文件应存在");

        storage.delete("files/uuid.pdf");
        assertFalse(storage.exists("files/uuid.pdf"), "删除后应不存在");
    }

    /**
     * 路径穿越的 key 必须被拒绝，防止读写落盘目录之外的任意文件。
     */
    @Test
    void rejectsPathTraversalKey() {
        assertThrows(IllegalArgumentException.class,
                () -> storage.exists("images/../../etc/passwd"),
                "含 .. 的 key 必须被拒绝");
        assertThrows(IllegalArgumentException.class,
                () -> storage.exists(""),
                "空 key 必须被拒绝");
    }
}
