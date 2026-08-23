package com.stylesmile.chat.service.impl;

import com.stylesmile.chat.dto.UploadResult;
import com.stylesmile.chat.storage.FileStorage;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.web.multipart.MultipartFile;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * FileStorageServiceImpl 单元测试
 *
 * 验证 uploadAndSign 两个重载方法：
 * <ol>
 *   <li>{@code uploadAndSign(MultipartFile)}：默认 avatars/ 前缀；</li>
 *   <li>{@code uploadAndSign(MultipartFile, String)}：按 mediaType 动态前缀。</li>
 * </ol>
 *
 * @author mmm
 */
@ExtendWith(MockitoExtension.class)
class FileStorageServiceImplTest {

    @Mock
    private FileStorage fileStorage;

    // 被测对象
    private FileStorageServiceImpl service;

    @BeforeEach
    void setUp() {
        // 手动构造 service，注入 mock 的 FileStorage
        service = new FileStorageServiceImpl(fileStorage);
    }

    // ==================== uploadAndSign(MultipartFile) ====================

    @Test
    void uploadAndSignReturnsKeyAndUrl() {
        // 准备：模拟一个图片文件
        byte[] content = "fake-image".getBytes();
        MultipartFile file = new MockMultipartFile("file", "avatar.jpg", "image/jpeg", content);
        // mock upload 返回固定的 key（UUID 随机，无法预测具体值）
        when(fileStorage.upload(any(), any(), eq("image/jpeg"), anyLong()))
                .thenReturn("avatars/uuid.jpg");
        // mock generatePresignedUrl 返回一个 URL
        when(fileStorage.generatePresignedUrl(eq("avatars/uuid.jpg"), anyInt()))
                .thenReturn("https://presigned.example.com/avatar.jpg");

        // 执行
        UploadResult result = service.uploadAndSign(file);

        // 验证：key 和 url 均非空，且与 mock 返回值一致
        assertNotNull(result);
        assertEquals("avatars/uuid.jpg", result.key());
        assertEquals("https://presigned.example.com/avatar.jpg", result.url());
    }

    @Test
    void uploadAndSignGeneratesAvatarPrefixKey() {
        // 准备
        byte[] content = "fake-image".getBytes();
        MultipartFile file = new MockMultipartFile("file", "photo.png", "image/png", content);
        // mock upload 时用 ArgumentCaptor 捕获 key 参数
        when(fileStorage.upload(any(), any(), eq("image/png"), anyLong()))
                .thenAnswer(invocation -> invocation.getArgument(1)); // 返回传入的 key
        when(fileStorage.generatePresignedUrl(any(), anyInt())).thenReturn("https://presigned/url");

        // 执行
        UploadResult result = service.uploadAndSign(file);

        // 验证：key 以 avatars/ 开头，且以 .png 结尾（保留原始扩展名）
        assertNotNull(result.key());
        assertTrue(result.key().startsWith("avatars/"), "key 应以 avatars/ 开头");
        assertTrue(result.key().endsWith(".png"), "key 应保留原始扩展名 .png");
    }

    @Test
    void uploadAndSignCallsUploadThenGeneratePresignedUrl() {
        // 准备
        byte[] content = "data".getBytes();
        MultipartFile file = new MockMultipartFile("file", "a.jpg", "image/jpeg", content);
        when(fileStorage.upload(any(), any(), any(), anyLong()))
                .thenReturn("avatars/uuid.jpg");
        when(fileStorage.generatePresignedUrl(eq("avatars/uuid.jpg"), anyInt()))
                .thenReturn("https://presigned");

        // 执行
        service.uploadAndSign(file);

        // 验证：upload 被调用，contentType 正确传递
        verify(fileStorage).upload(any(), any(), eq("image/jpeg"), eq((long) content.length));
        // generatePresignedUrl 被调用，有效期 7 天 = 7*24*60 分钟
        verify(fileStorage).generatePresignedUrl(eq("avatars/uuid.jpg"), eq(7 * 24 * 60));
    }

    @Test
    void uploadAndSignHandlesFileWithoutExtension() {
        // 准备：文件名无扩展名
        byte[] content = "data".getBytes();
        MultipartFile file = new MockMultipartFile("file", "noext", "application/octet-stream", content);
        when(fileStorage.upload(any(), any(), any(), anyLong()))
                .thenAnswer(invocation -> invocation.getArgument(1));
        when(fileStorage.generatePresignedUrl(any(), anyInt())).thenReturn("https://presigned");

        // 执行
        UploadResult result = service.uploadAndSign(file);

        // 验证：key 以 avatars/ 开头（无扩展名时不需要追加 .ext）
        assertNotNull(result.key());
        assertTrue(result.key().startsWith("avatars/"));
    }

    // ==================== uploadAndSign(MultipartFile, String) ====================

    @Test
    void uploadAndSignWithMediaTypeUsesCorrectPrefix() {
        // 准备：images 类型文件
        byte[] content = "fake-image".getBytes();
        MultipartFile file = new MockMultipartFile("file", "pic.jpg", "image/jpeg", content);
        when(fileStorage.upload(any(), any(), eq("image/jpeg"), anyLong()))
                .thenAnswer(invocation -> invocation.getArgument(1)); // 返回传入的 key
        when(fileStorage.generatePresignedUrl(any(), anyInt())).thenReturn("https://presigned/image");

        // 执行
        UploadResult result = service.uploadAndSign(file, "images");

        // 验证：key 前缀为 images/
        assertNotNull(result.key());
        assertTrue(result.key().startsWith("images/"), "key 应以 images/ 开头");
        assertTrue(result.key().endsWith(".jpg"), "key 应保留原始扩展名");
    }

    @Test
    void uploadAndSignWithMediaTypeVideos() {
        // 准备
        byte[] content = "fake-video".getBytes();
        MultipartFile file = new MockMultipartFile("file", "clip.mp4", "video/mp4", content);
        when(fileStorage.upload(any(), any(), eq("video/mp4"), anyLong()))
                .thenAnswer(invocation -> invocation.getArgument(1));
        when(fileStorage.generatePresignedUrl(any(), anyInt())).thenReturn("https://presigned/video");

        // 执行
        UploadResult result = service.uploadAndSign(file, "videos");

        // 验证：key 前缀为 videos/
        assertNotNull(result.key());
        assertTrue(result.key().startsWith("videos/"), "key 应以 videos/ 开头");
    }

    @Test
    void uploadAndSignWithMediaTypeFiles() {
        // 准备
        byte[] content = "fake-doc".getBytes();
        MultipartFile file = new MockMultipartFile("file", "doc.pdf", "application/pdf", content);
        when(fileStorage.upload(any(), any(), eq("application/pdf"), anyLong()))
                .thenAnswer(invocation -> invocation.getArgument(1));
        when(fileStorage.generatePresignedUrl(any(), anyInt())).thenReturn("https://presigned/file");

        // 执行
        UploadResult result = service.uploadAndSign(file, "files");

        // 验证：key 前缀为 files/
        assertNotNull(result.key());
        assertTrue(result.key().startsWith("files/"), "key 应以 files/ 开头");
    }

    @Test
    void uploadAndSignWithMediaTypeThrowsOnInvalidType() {
        // 准备：非法 mediaType（路径穿越风险）
        byte[] content = "evil".getBytes();
        MultipartFile file = new MockMultipartFile("file", "x.txt", "text/plain", content);

        // 执行+验证：应抛出 IllegalArgumentException，阻止任意目录写入
        IllegalArgumentException ex = assertThrows(
                IllegalArgumentException.class,
                () -> service.uploadAndSign(file, "etc_passwd")
        );
        // 验证异常信息包含非法类型，便于排查
        assertTrue(ex.getMessage().contains("etc_passwd"), "异常信息应包含非法类型");
    }

    @Test
    void uploadAndSignWithMediaTypeCallsStorageWithCorrectArgs() {
        // 准备
        byte[] content = "data".getBytes();
        MultipartFile file = new MockMultipartFile("file", "a.mp4", "video/mp4", content);
        when(fileStorage.upload(any(), any(), any(), anyLong()))
                .thenAnswer(invocation -> invocation.getArgument(1));
        when(fileStorage.generatePresignedUrl(any(), anyInt())).thenReturn("https://presigned");

        // 执行
        service.uploadAndSign(file, "videos");

        // 验证：upload 被调用，contentType="video/mp4"，size 正确
        ArgumentCaptor<String> keyCaptor = ArgumentCaptor.forClass(String.class);
        verify(fileStorage).upload(any(), keyCaptor.capture(), eq("video/mp4"), eq((long) content.length));
        // key 必须以 videos/ 开头
        assertTrue(keyCaptor.getValue().startsWith("videos/"), "key 应以 videos/ 开头");
        // generatePresignedUrl 被调用，有效期 7 天
        verify(fileStorage).generatePresignedUrl(keyCaptor.getValue(), eq(7 * 24 * 60));
    }
}
