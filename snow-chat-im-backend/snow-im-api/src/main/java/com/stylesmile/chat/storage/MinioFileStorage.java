package com.stylesmile.chat.storage;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.CreateBucketRequest;
import software.amazon.awssdk.services.s3.model.DeleteObjectRequest;
import software.amazon.awssdk.services.s3.model.HeadBucketRequest;
import software.amazon.awssdk.services.s3.model.HeadObjectRequest;
import software.amazon.awssdk.services.s3.model.NoSuchBucketException;
import software.amazon.awssdk.services.s3.model.NoSuchKeyException;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;
import software.amazon.awssdk.services.s3.presigner.model.GetObjectPresignRequest;

import java.io.InputStream;
import java.time.Duration;

/**
 * MinIO 文件存储实现（基于 AWS S3 SDK v2）。
 * 当 {@code storage.type=minio} 时启用（装配条件统一由 {@link StorageType} 驱动，
 * {@code minio.enabled} 已不再参与 Bean 装配，仅作为兼容字段保留）。
 *
 * <p>支持两种访问策略：
 * <ul>
 *   <li>公共读（publicReadPolicy=true）：上传返回对象 key，generateUrl 直接拼接 endpoint/fileName 返回完整可访问 URL；</li>
 *   <li>私有读（publicReadPolicy=false，默认）：upload 返回对象 key，generateUrl 生成带签名的临时 URL（7天有效）。</li>
 * </ul>
 *
 * @author mmm
 * @see FileStorage
 * @see InMemoryFileStorage
 * @see MinioConfig
 * @see StorageType
 */
@Component
@ConditionalOnProperty(prefix = "storage", name = "type", havingValue = "minio")
public class MinioFileStorage implements FileStorage {

    private static final Logger log = LoggerFactory.getLogger(MinioFileStorage.class); // 日志器

    /** pre-signed URL 有效期（分钟），私有读模式使用 */
    private static final int PRESIGN_EXPIRATION_MINUTES_DEFAULT = 7 * 24 * 60; // 7天

    private final S3Client s3Client;       // S3 客户端
    private final S3Presigner s3Presigner; // 预签名 URL 生成器
    private final String bucketName;       // bucket 名称
    private final String publicBaseUrl;    // 外部访问基础 URL（公共读模式下使用，来自 minio.public-url）
    private final boolean publicReadPolicy; // 是否公共读策略（来自 minio.public-read-policy）

    /**
     * 构造器：注入 S3Client / S3Presigner / MinioProperties，并确保 bucket 存在。
     */
    public MinioFileStorage(S3Client s3Client, S3Presigner s3Presigner, MinioProperties minioProperties) {
        this.s3Client = s3Client;                                 // 保存 S3 客户端
        this.s3Presigner = s3Presigner;                           // 保存签名器
        this.bucketName = minioProperties.bucket();               // 保存 bucket 名
        this.publicBaseUrl = minioProperties.publicUrl();         // 保存外部访问基础 URL
        this.publicReadPolicy = minioProperties.publicReadPolicy(); // 保存公共读策略标志
        // 构造时确保 bucket 存在（失败不阻断启动）
        try {
            ensureBucketExists();
        } catch (Exception e) {
            // 记录警告，应用继续启动（上传时才会真正失败）
            log.warn("MinIO bucket check failed. App will start but file upload may fail: {}", e.getMessage());
        }
    }

    /**
     * 检查 bucket 是否存在，不存在则创建。
     * 私有策略下不设置公共读策略。
     */
    private void ensureBucketExists() {
        try {
            // 探测 bucket 是否存在
            s3Client.headBucket(HeadBucketRequest.builder().bucket(bucketName).build());
            log.info("Bucket '{}' already exists", bucketName);
        } catch (NoSuchBucketException e) {
            // bucket 不存在，创建
            log.info("Creating bucket '{}'", bucketName);
            s3Client.createBucket(CreateBucketRequest.builder().bucket(bucketName).build());
        }
    }

    /**
     * 上传文件到 MinIO，返回对象 key（无论公共读/私有读均返回 key，由 generateUrl 决定如何获取访问地址）。
     */
    @Override
    public String upload(InputStream inputStream, String fileName, String contentType, long fileSize) {
        // 构造 PUT 请求
        PutObjectRequest putRequest = PutObjectRequest.builder()
                .bucket(bucketName)                 // bucket 名称
                .key(fileName)                      // 对象 key
                .contentType(contentType)           // MIME 类型
                .contentLength(fileSize)            // 文件大小
                .build();
        // 执行上传，使用输入流构造请求体
        s3Client.putObject(putRequest, RequestBody.fromInputStream(inputStream, fileSize));
        log.info("File uploaded successfully: {}", fileName);
        // 返回对象 key（不是 URL，由 generateUrl 决定访问方式）
        return fileName;
    }

    /**
     * 删除 MinIO 上的对象。
     */
    @Override
    public void delete(String fileName) {
        // 构造 DELETE 请求
        DeleteObjectRequest deleteRequest = DeleteObjectRequest.builder()
                .bucket(bucketName)
                .key(fileName)
                .build();
        // 执行删除
        s3Client.deleteObject(deleteRequest);
        log.info("File deleted successfully: {}", fileName);
    }

    /**
     * 判断对象是否存在（通过 headObject 探测）。
     */
    @Override
    public boolean exists(String fileName) {
        try {
            // 构造 HEAD 请求
            HeadObjectRequest headRequest = HeadObjectRequest.builder()
                    .bucket(bucketName)
                    .key(fileName)
                    .build();
            // 探测对象元数据（存在则无异常）
            s3Client.headObject(headRequest);
            return true;
        } catch (NoSuchKeyException e) {
            // 对象不存在
            return false;
        }
    }

    /**
     * 生成预签名下载 URL（私有读模式使用，带签名与有效期）。
     *
     * @param fileName          对象 key
     * @param expirationMinutes URL 有效期（分钟）
     * @return 带签名的 URL 字符串
     */
    @Override
    public String generatePresignedUrl(String fileName, int expirationMinutes) {
        // 构造预签名请求
        GetObjectPresignRequest presignRequest = GetObjectPresignRequest.builder()
                .signatureDuration(Duration.ofMinutes(expirationMinutes)) // 有效期
                .getObjectRequest(b -> b.bucket(bucketName).key(fileName)) // GET 请求
                .build();
        // 调用签名器生成 URL，返回字符串形式
        return s3Presigner.presignGetObject(presignRequest).url().toString();
    }

    /**
     * 生成可直接访问的完整 URL。
     *
     * <p>公共读策略（publicReadPolicy=true）时，返回 {@code publicBaseUrl/fileName} 直接可访问；
     * 私有策略时回退到带签名的 pre-signed URL（7天有效）。
     *
     * @param fileName 对象 key（如 avatars/uuid.jpg）或已是完整 URL
     * @return 完整可访问 URL 或带签名 URL
     */
    @Override
    public String generateUrl(String fileName) {
        // 若 fileName 本身已是完整 URL（如历史数据），直接返回
        if (fileName.startsWith("http://") || fileName.startsWith("https://")) {
            return fileName;
        }
        // 公共读模式：直接拼接 endpoint/fileName，无需签名
        if (publicReadPolicy) {
            String base = publicBaseUrl != null && !publicBaseUrl.isBlank()
                    ? publicBaseUrl.replaceAll("/+$", "")
                    : s3Client.getClass().toString(); // fallback（理论上不会触发，因为 publicBaseUrl 已配置）
            return base + "/" + fileName.replaceAll("^/+", "");
        }
        // 私有模式：返回带签名的临时 URL（7天有效）
        return generatePresignedUrl(fileName, PRESIGN_EXPIRATION_MINUTES_DEFAULT);
    }
}
