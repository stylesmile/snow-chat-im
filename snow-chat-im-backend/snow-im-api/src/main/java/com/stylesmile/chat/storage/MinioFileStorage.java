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
 * 当 minio.enabled=true 时启用。
 *
 * <p>采用"私有 + Pre-signed URL"策略：
 * <ul>
 *   <li>bucket 不设置公共读策略，文件不可匿名访问；</li>
 *   <li>upload 返回对象 key，URL 由 generatePresignedUrl 动态生成；</li>
 *   <li>构造时自动检查并创建 bucket。</li>
 * </ul>
 *
 * @author mmm
 * @see FileStorage
 * @see InMemoryFileStorage
 * @see MinioConfig
 */
@Component
@ConditionalOnProperty(name = "minio.enabled", havingValue = "true", matchIfMissing = false)
public class MinioFileStorage implements FileStorage {

    private static final Logger log = LoggerFactory.getLogger(MinioFileStorage.class); // 日志器

    private final S3Client s3Client;       // S3 客户端
    private final S3Presigner s3Presigner; // 预签名 URL 生成器
    private final String bucketName;       // bucket 名称

    /**
     * 构造器：注入 S3Client / S3Presigner / MinioProperties，并确保 bucket 存在。
     */
    public MinioFileStorage(S3Client s3Client, S3Presigner s3Presigner, MinioProperties minioProperties) {
        this.s3Client = s3Client;                                 // 保存 S3 客户端
        this.s3Presigner = s3Presigner;                           // 保存签名器
        this.bucketName = minioProperties.bucket();               // 保存 bucket 名
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
     * 上传文件到 MinIO，返回对象 key（私有策略契约）。
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
        // 返回对象 key（不是 URL）
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
     * 生成下载用的 pre-signed URL。
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
}
