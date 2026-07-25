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
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * FileController 单元测试
 *
 * 验证 POST /file/upload：
 * 1. 正常文件 → Result.success(UploadResult)，code=200，data.key 和 data.url 非空
 * 2. 空文件 → Result.fail，code=500
 */
@ExtendWith(MockitoExtension.class)
class FileControllerTest {

    @Mock
    private FileStorageService fileStorageService;

    @InjectMocks
    private FileController controller;

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
}
