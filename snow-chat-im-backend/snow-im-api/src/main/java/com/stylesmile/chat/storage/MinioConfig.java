package com.stylesmile.chat.storage;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;

import java.net.URI;

/**
 * MinIO Spring 配置类。
 * 仅当 minio.enabled=true 时生效，注册 S3Client 与 S3Presigner Bean。
 *
 * <p>MinIO 要求 path-style 访问，故 S3Client 强制设置 forcePathStyle(true)。
 *
 * @author mmm
 * @see MinioFileStorage
 */
@Configuration
@ConditionalOnProperty(name = "minio.enabled", havingValue = "true", matchIfMissing = false)
public class MinioConfig {

    /**
     * 创建 S3Client Bean，连接到 MinIO 服务。
     *
     * @param props MinIO 配置属性
     * @return S3Client 实例
     */
    @Bean
    public S3Client s3Client(MinioProperties props) {
        // 构造基本凭证
        AwsBasicCredentials creds = AwsBasicCredentials.create(props.accessKey(), props.secretKey());
        // 构建 S3Client：端点覆盖 + region + 凭证 + path-style
        return S3Client.builder()
                .endpointOverride(URI.create(props.endpoint()))   // MinIO 端点
                .region(Region.of(props.region()))                // 区域
                .credentialsProvider(StaticCredentialsProvider.create(creds)) // 凭证
                .forcePathStyle(true)                             // MinIO 必须使用 path-style
                .build();
    }

    /**
     * 创建 S3Presigner Bean，用于生成 pre-signed URL。
     *
     * @param props MinIO 配置属性
     * @return S3Presigner 实例
     */
    @Bean
    public S3Presigner s3Presigner(MinioProperties props) {
        // 构造基本凭证
        AwsBasicCredentials creds = AwsBasicCredentials.create(props.accessKey(), props.secretKey());
        // 构建 S3Presigner：端点覆盖 + region + 凭证
        return S3Presigner.builder()
                .endpointOverride(URI.create(props.endpoint()))
                .region(Region.of(props.region()))
                .credentialsProvider(StaticCredentialsProvider.create(creds))
                .build();
    }
}
