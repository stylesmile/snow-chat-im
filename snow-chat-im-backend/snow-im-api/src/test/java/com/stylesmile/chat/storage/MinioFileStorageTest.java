package com.stylesmile.chat.storage;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.CreateBucketRequest;
import software.amazon.awssdk.services.s3.model.HeadBucketRequest;
import software.amazon.awssdk.services.s3.model.NoSuchBucketException;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;
import software.amazon.awssdk.services.s3.presigner.model.GetObjectPresignRequest;
import software.amazon.awssdk.services.s3.presigner.model.PresignedGetObjectRequest;

import java.io.ByteArrayInputStream;
import java.net.URL;
import java.nio.charset.StandardCharsets;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * MinioFileStorage 的单元测试。
 * 通过 Mockito mock S3Client 与 S3Presigner，验证：
 * 1. bucket 不存在时自动创建
 * 2. upload 调用 putObject 并返回 key（私有策略）
 * 3. generatePresignedUrl 调用 presignGetObject 并返回 URL 字符串
 *
 * @author mmm
 */
class MinioFileStorageTest {

    private S3Client s3Client;       // mocked S3 客户端
    private S3Presigner s3Presigner; // mocked S3 签名器
    private MinioProperties properties; // 测试用属性

    @BeforeEach
    void setUp() {
        // 创建 mock 对象
        s3Client = mock(S3Client.class);
        s3Presigner = mock(S3Presigner.class);
        // 构造测试属性：bucket=snow-chat，启用私有策略
        properties = new MinioProperties(
                true, "http://localhost:9000", "ak", "sk",
                "snow-chat", "", "us-east-1", false
        );
    }

    /**
     * 构造 MinioFileStorage 时，若 bucket 不存在应调用 createBucket。
     */
    @Test
    void createsBucketWhenNotExists() {
        // 模拟 headBucket 抛出 NoSuchBucketException（bucket 不存在）
        when(s3Client.headBucket(any(HeadBucketRequest.class)))
                .thenThrow(NoSuchBucketException.builder().message("not found").build());

        // 构造 MinioFileStorage（触发 ensureBucketExists）
        new MinioFileStorage(s3Client, s3Presigner, properties);

        // 捕获 createBucket 请求参数，断言 bucket 名称为 snow-chat
        ArgumentCaptor<CreateBucketRequest> captor = ArgumentCaptor.forClass(CreateBucketRequest.class);
        verify(s3Client).createBucket(captor.capture());
        assertEquals("snow-chat", captor.getValue().bucket(), "应创建名为 snow-chat 的 bucket");
    }

    /**
     * 构造 MinioFileStorage 时，若 bucket 已存在不应调用 createBucket。
     */
    @Test
    void doesNotCreateBucketWhenExists() {
        // 模拟 headBucket 正常返回（bucket 已存在）
        when(s3Client.headBucket(any(HeadBucketRequest.class))).thenReturn(null);

        new MinioFileStorage(s3Client, s3Presigner, properties);

        // 验证 createBucket 从未被调用
        verify(s3Client, org.mockito.Mockito.never()).createBucket(any(CreateBucketRequest.class));
    }

    /**
     * upload 应调用 putObject 并返回传入的 fileName（即对象 key）。
     * 私有策略下不返回 URL，URL 由 generatePresignedUrl 单独获取。
     */
    @Test
    void uploadCallsPutObjectAndReturnsKey() {
        // bucket 已存在，避免构造期 createBucket 干扰
        when(s3Client.headBucket(any(HeadBucketRequest.class))).thenReturn(null);
        MinioFileStorage storage = new MinioFileStorage(s3Client, s3Presigner, properties);

        // 准备文件内容
        byte[] data = "avatar".getBytes(StandardCharsets.UTF_8);
        ByteArrayInputStream input = new ByteArrayInputStream(data);

        // 调用上传
        String result = storage.upload(input, "avatars/uuid.jpg", "image/jpeg", data.length);

        // 断言返回值为 key
        assertEquals("avatars/uuid.jpg", result, "upload 应返回对象 key");

        // 验证 putObject 被调用，并捕获请求参数
        ArgumentCaptor<PutObjectRequest> putCaptor = ArgumentCaptor.forClass(PutObjectRequest.class);
        verify(s3Client).putObject(putCaptor.capture(), any(RequestBody.class));
        // 断言 bucket 与 key 正确
        assertEquals("snow-chat", putCaptor.getValue().bucket(), "putObject 应使用正确 bucket");
        assertEquals("avatars/uuid.jpg", putCaptor.getValue().key(), "putObject 应使用正确 key");
        assertEquals("image/jpeg", putCaptor.getValue().contentType(), "putObject 应设置 contentType");
    }

    /**
     * generatePresignedUrl 应调用 presignGetObject 并返回其 URL 字符串。
     */
    @Test
    void generatePresignedUrlReturnsPresignedUrl() throws Exception {
        // bucket 已存在
        when(s3Client.headBucket(any(HeadBucketRequest.class))).thenReturn(null);
        MinioFileStorage storage = new MinioFileStorage(s3Client, s3Presigner, properties);

        // mock presignGetObject 返回一个 PresignedGetObjectRequest，其 url() 返回固定 URL
        PresignedGetObjectRequest presignedRequest = mock(PresignedGetObjectRequest.class);
        when(presignedRequest.url()).thenReturn(new URL("https://minio.example.com/snow-chat/avatars/x.jpg?signature=abc"));
        when(s3Presigner.presignGetObject(any(GetObjectPresignRequest.class))).thenReturn(presignedRequest);

        // 调用生成 pre-signed URL，有效期 60 分钟
        String url = storage.generatePresignedUrl("avatars/x.jpg", 60);

        // 断言返回的 URL 与 mock 一致
        assertEquals("https://minio.example.com/snow-chat/avatars/x.jpg?signature=abc", url,
                "应返回 presigner 生成的 URL");
        // 验证 presignGetObject 被调用
        verify(s3Presigner).presignGetObject(any(GetObjectPresignRequest.class));
    }
}
