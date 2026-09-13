package com.stylesmile.chat.storage;

import com.aliyun.oss.OSS;
import com.aliyun.oss.model.ObjectMetadata;
import com.aliyun.oss.model.PutObjectResult;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.net.URI;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.Date;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * AliyunOssFileStorage 的单元测试。
 *
 * <p>通过 Mockito mock 阿里云 OSS 客户端，验证：
 * <ul>
 *   <li>upload：调用 putObject 并写入正确的 contentType / contentLength，返回对象 key（非 URL）；</li>
 *   <li>delete / exists：正确转发到 OSS 客户端；</li>
 *   <li>generatePresignedUrl：把"分钟"正确换算为过期时刻并返回 OSS 生成的签名 URL；</li>
 *   <li>generateUrl：公共读走直链且不调用签名；私有读回退到签名 URL；已是完整 URL 时原样返回。</li>
 * </ul>
 *
 * @author mmm
 */
class AliyunOssFileStorageTest {

    /** mocked 阿里云 OSS 客户端 */
    private OSS ossClient;

    /** 公共读 + 自定义 CDN 域名的配置（默认测试配置） */
    private AliyunOssProperties publicReadProps;

    /** 私有读配置（用于验证签名 URL 回退） */
    private AliyunOssProperties privateProps;

    @BeforeEach
    void setUp() {
        // 创建 OSS 客户端 mock
        ossClient = mock(OSS.class);
        // 公共读 + 自定义域名配置
        publicReadProps = new AliyunOssProperties(
                "https://oss-cn-hangzhou.aliyuncs.com", // endpoint
                "ak",                                   // accessKeyId
                "sk",                                   // accessKeySecret
                "snow-chat",                            // bucket
                "https://cdn.winchat.club",             // publicBaseUrl（自定义 CDN 域名）
                true,                                   // publicRead
                120                                     // 签名有效期 120 分钟
        );
        // 私有读配置（无自定义域名）
        privateProps = new AliyunOssProperties(
                "https://oss-cn-hangzhou.aliyuncs.com", "ak", "sk",
                "snow-chat",
                "",                                     // 无自定义域名
                false,                                  // 私有读
                120
        );
    }

    /**
     * upload 应调用 putObject 并携带正确的元数据，返回值必须是对象 key 而非 URL。
     * 数据库存 key、访问地址动态生成，便于后续切换域名或更换存储后端。
     */
    @Test
    void uploadCallsPutObjectAndReturnsKey() {
        // 构造被测对象（公共读配置）
        AliyunOssFileStorage storage = new AliyunOssFileStorage(ossClient, publicReadProps);
        // 准备文件内容
        byte[] data = "avatar-bytes".getBytes(StandardCharsets.UTF_8);
        // mock putObject 返回结果对象
        when(ossClient.putObject(eq("snow-chat"), eq("avatars/uuid.jpg"),
                any(InputStream.class), any(ObjectMetadata.class)))
                .thenReturn(new PutObjectResult());

        // 执行上传
        String key = storage.upload(new ByteArrayInputStream(data), "avatars/uuid.jpg",
                "image/jpeg", data.length);

        // 断言返回对象 key（不是 URL）
        assertEquals("avatars/uuid.jpg", key, "upload 应返回对象 key");

        // 捕获传给 OSS 的元数据，验证 contentLength 与 contentType 被正确设置
        ArgumentCaptor<ObjectMetadata> metadataCaptor = ArgumentCaptor.forClass(ObjectMetadata.class);
        verify(ossClient).putObject(eq("snow-chat"), eq("avatars/uuid.jpg"),
                any(InputStream.class), metadataCaptor.capture());
        assertEquals(data.length, metadataCaptor.getValue().getContentLength(),
                "putObject 应设置正确的 contentLength");
        assertEquals("image/jpeg", metadataCaptor.getValue().getContentType(),
                "putObject 应设置正确的 contentType");
    }

    /**
     * delete 应转发为 OSS 的 deleteObject 调用，参数为 bucket + key。
     */
    @Test
    void deleteForwardsToOssClient() {
        AliyunOssFileStorage storage = new AliyunOssFileStorage(ossClient, publicReadProps);

        // 执行删除
        storage.delete("avatars/old.jpg");

        // 断言 OSS 客户端收到正确的 bucket 与 key
        verify(ossClient).deleteObject("snow-chat", "avatars/old.jpg");
    }

    /**
     * exists 应转发为 OSS 的 doesObjectExist 调用并返回其结果。
     */
    @Test
    void existsForwardsToOssClient() {
        AliyunOssFileStorage storage = new AliyunOssFileStorage(ossClient, publicReadProps);
        // mock 对象存在
        when(ossClient.doesObjectExist("snow-chat", "avatars/exist.jpg")).thenReturn(true);

        // 断言返回 true
        assertTrue(storage.exists("avatars/exist.jpg"), "对象存在时应返回 true");

        // mock 对象不存在
        when(ossClient.doesObjectExist("snow-chat", "avatars/missing.jpg")).thenReturn(false);
        // 断言返回 false
        assertFalse(storage.exists("avatars/missing.jpg"), "对象不存在时应返回 false");
    }

    /**
     * generatePresignedUrl 应把"分钟"换算为绝对过期时刻传给 OSS，并返回其 URL。
     */
    @Test
    void generatePresignedUrlConvertsMinutesToExpiration() throws Exception {
        AliyunOssFileStorage storage = new AliyunOssFileStorage(ossClient, privateProps);
        // OSS 生成的签名 URL
        URL signedUrl = URI.create("https://snow-chat.oss-cn-hangzhou.aliyuncs.com/avatars/x.jpg"
                + "?Expires=1&Signature=abc").toURL();
        // mock 签名结果
        when(ossClient.generatePresignedUrl(eq("snow-chat"), eq("avatars/x.jpg"), any(Date.class)))
                .thenReturn(signedUrl);

        // 记录调用前后的时间，用于校验过期时刻
        long before = System.currentTimeMillis();
        // 执行生成，有效期 60 分钟
        String result = storage.generatePresignedUrl("avatars/x.jpg", 60);
        long after = System.currentTimeMillis();

        // 断言返回签名 URL 字符串
        assertEquals(signedUrl.toString(), result, "应返回 OSS 生成的签名 URL");

        // 捕获过期时刻，断言约为 now + 60 分钟（允许 ±10 秒误差）
        ArgumentCaptor<Date> expirationCaptor = ArgumentCaptor.forClass(Date.class);
        verify(ossClient).generatePresignedUrl(eq("snow-chat"), eq("avatars/x.jpg"),
                expirationCaptor.capture());
        long expected = before + 60L * 60 * 1000;
        long tolerance = 10_000L;
        long actual = expirationCaptor.getValue().getTime();
        assertTrue(Math.abs(actual - expected) <= tolerance,
                "过期时刻应约为 now + 60 分钟，实际差值=" + (actual - expected) + "ms");
        // 过期时刻必须晚于调用结束时间
        assertTrue(actual > after, "过期时刻应晚于当前时间");
    }

    /**
     * 公共读模式：generateUrl 应返回 自定义域名 + key 的直链，且不产生任何 OSS 调用。
     */
    @Test
    void generateUrlReturnsDirectUrlInPublicReadMode() {
        AliyunOssFileStorage storage = new AliyunOssFileStorage(ossClient, publicReadProps);

        // 执行生成
        String url = storage.generateUrl("avatars/550e8400.jpg");

        // 断言直链格式正确
        assertEquals("https://cdn.winchat.club/avatars/550e8400.jpg", url,
                "公共读应返回自定义域名直链");
        // 断言不调用签名接口（公共读无需签名）
        verify(ossClient, never()).generatePresignedUrl(any(), any(), any(Date.class));
    }

    /**
     * 公共读但未配置自定义域名：应按 bucket + endpoint 主机名推导直链。
     */
    @Test
    void generateUrlDerivesHostWhenNoCustomDomain() {
        // 公共读 + 无自定义域名
        AliyunOssProperties props = new AliyunOssProperties(
                "https://oss-cn-hangzhou.aliyuncs.com", "ak", "sk",
                "snow-chat", "", true, 120
        );
        AliyunOssFileStorage storage = new AliyunOssFileStorage(ossClient, props);

        // 执行生成
        String url = storage.generateUrl("images/a.png");

        // 断言推导出 virtual-hosted 直链
        assertEquals("https://snow-chat.oss-cn-hangzhou.aliyuncs.com/images/a.png", url,
                "无自定义域名时应按 bucket + endpoint 推导直链");
    }

    /**
     * 私有读模式：generateUrl 应回退到带签名与有效期的 pre-signed URL。
     */
    @Test
    void generateUrlFallsBackToPresignedUrlInPrivateMode() throws Exception {
        AliyunOssFileStorage storage = new AliyunOssFileStorage(ossClient, privateProps);
        // 签名 URL
        URL signedUrl = URI.create("https://snow-chat.oss-cn-hangzhou.aliyuncs.com/avatars/y.jpg"
                + "?Expires=2&Signature=xyz").toURL();
        when(ossClient.generatePresignedUrl(eq("snow-chat"), eq("avatars/y.jpg"), any(Date.class)))
                .thenReturn(signedUrl);

        // 执行生成
        String url = storage.generateUrl("avatars/y.jpg");

        // 断言返回签名 URL
        assertEquals(signedUrl.toString(), url, "私有读应返回签名 URL");
        // 断言确实调用了签名接口
        verify(ossClient).generatePresignedUrl(eq("snow-chat"), eq("avatars/y.jpg"), any(Date.class));
    }

    /**
     * 传入的 fileName 已是完整 URL（历史数据）时应原样返回，避免重复拼接。
     */
    @Test
    void generateUrlReturnsOriginalWhenAlreadyFullUrl() {
        AliyunOssFileStorage storage = new AliyunOssFileStorage(ossClient, publicReadProps);
        // 历史数据：数据库里存的是完整 URL
        String original = "https://cdn.winchat.club/avatars/legacy.jpg";

        // 断言原样返回
        assertEquals(original, storage.generateUrl(original), "已是完整 URL 时应原样返回");
        // 断言未触发任何 OSS 调用
        verify(ossClient, never()).generatePresignedUrl(any(), any(), any(Date.class));
    }
}
