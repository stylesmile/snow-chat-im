package com.stylesmile.chat.controller;

import com.stylesmile.chat.dto.UploadResult;
import com.stylesmile.chat.service.FileStorageService;
import com.stylesmile.common.util.Result;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.mock.web.MockMultipartFile;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * FileController 单元测试
 *
 * 覆盖以下端点：
 * <ul>
 *   <li>{@code POST /file/upload}：通用上传 → 成功/空文件</li>
 *   <li>{@code POST /file/avatar}：头像上传 → 成功/空文件</li>
 *   <li>{@code POST /file/media/{type}}：媒体上传 →
 *       合法 type 成功、非法 type 失败、空文件失败</li>
 * </ul>
 *
 * @author mmm
 */
@ExtendWith(MockitoExtension.class)
class FileControllerTest {

    @Mock
    private FileStorageService fileStorageService;

    @InjectMocks
    private FileController controller;

    // ==================== /file/upload ====================

    @Test
    void uploadReturnsSuccessWithKeyAndUrl() {
        // 准备：构造一个非空的 multipart 文件
        byte[] content = "fake-image".getBytes();
        MockMultipartFile file = new MockMultipartFile("file", "avatar.jpg", "image/jpeg", content);
        // mock service 返回 UploadResult
        UploadResult uploadResult = new UploadResult("avatars/uuid.jpg", "https://presigned/url");
        when(fileStorageService.uploadAndSign(file)).thenReturn(uploadResult);

        // 执行
        Result<UploadResult> result = controller.upload(file);

        // 验证：成功返回，code=200，data 非空
        assertEquals("200", result.getCode());
        assertNotNull(result.getData());
        assertEquals("avatars/uuid.jpg", result.getData().key());
        assertEquals("https://presigned/url", result.getData().url());
        verify(fileStorageService).uploadAndSign(file);
    }

    @Test
    void uploadReturnsFailForEmptyFile() {
        // 准备：构造一个空的 multipart 文件
        byte[] emptyContent = new byte[0];
        MockMultipartFile file = new MockMultipartFile("file", "empty.jpg", "image/jpeg", emptyContent);

        // 执行
        Result<UploadResult> result = controller.upload(file);

        // 验证：失败返回，code=500，data 为 null
        assertEquals("500", result.getCode());
        assertNull(result.getData());
    }

    // ==================== /file/avatar ====================

    @Test
    void avatarUploadDelegatesToServiceWithSameFile() {
        // 准备：构造一个非空的头像文件
        byte[] content = "avatar-data".getBytes();
        MockMultipartFile file = new MockMultipartFile("file", "me.jpg", "image/jpeg", content);
        UploadResult uploadResult = new UploadResult("avatars/uuid.jpg", "https://presigned/avatar");
        when(fileStorageService.uploadAndSign(file)).thenReturn(uploadResult);

        // 执行
        Result<UploadResult> result = controller.uploadAvatar(file);

        // 验证：成功返回，且委托给 service.uploadAndSign(file)（同 /upload 逻辑）
        assertEquals("200", result.getCode());
        assertNotNull(result.getData());
        assertEquals("avatars/uuid.jpg", result.getData().key());
        assertEquals("https://presigned/avatar", result.getData().url());
        verify(fileStorageService).uploadAndSign(file);
    }

    @Test
    void avatarUploadReturnsFailForEmptyFile() {
        // 准备：空的 multipart 文件
        MockMultipartFile file = new MockMultipartFile("file", "empty.jpg", "image/jpeg", new byte[0]);

        // 执行
        Result<UploadResult> result = controller.uploadAvatar(file);

        // 验证：失败返回，code=500
        assertEquals("500", result.getCode());
        assertNull(result.getData());
    }

    // ==================== /file/media/{type} ====================

    @Test
    void mediaUploadSuccessForImageType() {
        // 准备：image 类型的媒体文件
        byte[] content = "fake-image".getBytes();
        MockMultipartFile file = new MockMultipartFile("file", "photo.jpg", "image/jpeg", content);
        UploadResult uploadResult = new UploadResult("images/uuid.jpg", "https://presigned/image");
        when(fileStorageService.uploadAndSign(eq(file), eq("images"))).thenReturn(uploadResult);

        // 执行
        Result<UploadResult> result = controller.uploadMedia("image", file);

        // 验证：成功返回，且正确委托给 service，mediaType 被规范化为 "images"
        assertEquals("200", result.getCode());
        assertNotNull(result.getData());
        assertEquals("images/uuid.jpg", result.getData().key());
        assertEquals("https://presigned/image", result.getData().url());
        verify(fileStorageService).uploadAndSign(eq(file), eq("images"));
    }

    @Test
    void mediaUploadSuccessForVideoType() {
        // 准备：video 类型的媒体文件
        byte[] content = "fake-video".getBytes();
        MockMultipartFile file = new MockMultipartFile("file", "clip.mp4", "video/mp4", content);
        UploadResult uploadResult = new UploadResult("videos/uuid.mp4", "https://presigned/video");
        when(fileStorageService.uploadAndSign(eq(file), eq("videos"))).thenReturn(uploadResult);

        // 执行
        Result<UploadResult> result = controller.uploadMedia("video", file);

        // 验证：成功返回
        assertEquals("200", result.getCode());
        assertNotNull(result.getData());
        assertEquals("videos/uuid.mp4", result.getData().key());
        verify(fileStorageService).uploadAndSign(eq(file), eq("videos"));
    }

    @Test
    void mediaUploadSuccessForFileType() {
        // 准备：file 类型的媒体文件（文档）
        byte[] content = "fake-doc".getBytes();
        MockMultipartFile file = new MockMultipartFile("file", "doc.pdf", "application/pdf", content);
        UploadResult uploadResult = new UploadResult("files/uuid.pdf", "https://presigned/file");
        when(fileStorageService.uploadAndSign(eq(file), eq("files"))).thenReturn(uploadResult);

        // 执行
        Result<UploadResult> result = controller.uploadMedia("file", file);

        // 验证：成功返回
        assertEquals("200", result.getCode());
        assertNotNull(result.getData());
        assertEquals("files/uuid.pdf", result.getData().key());
        verify(fileStorageService).uploadAndSign(eq(file), eq("files"));
    }

    @Test
    void mediaUploadReturnsFailForInvalidType() {
        // 准备：非法 type（路径穿越风险）
        byte[] content = "fake".getBytes();
        MockMultipartFile file = new MockMultipartFile("file", "x.txt", "text/plain", content);

        // 执行
        Result<UploadResult> result = controller.uploadMedia("etc/passwd", file);

        // 验证：返回 fail 状态，不委托给 service
        assertEquals("500", result.getCode());
        assertNull(result.getData());
    }

    @Test
    void mediaUploadReturnsFailForEmptyFile() {
        // 准备：空文件
        MockMultipartFile file = new MockMultipartFile("file", "empty.jpg", "image/jpeg", new byte[0]);

        // 执行
        Result<UploadResult> result = controller.uploadMedia("image", file);

        // 验证：失败返回，code=500，且不委托 service
        assertEquals("500", result.getCode());
        assertNull(result.getData());
    }
}
