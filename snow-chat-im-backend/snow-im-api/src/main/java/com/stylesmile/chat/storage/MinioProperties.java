package com.stylesmile.chat.storage;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * MinIO 配置属性。
 * 对应 application-dev.yml 中的 {@code minio} 配置段。
 *
 * <p>使用 record 不可变对象，构造时对缺失字段做兜底：
 * <ul>
 *   <li>region 为空 → {@code us-east-1}</li>
 *   <li>bucket 为空 → {@code snow-chat}</li>
 * </ul>
 *
 * @param enabled          是否启用 MinIO（false 时降级到 InMemoryFileStorage）
 * @param endpoint         MinIO 服务端点 URL，如 http://localhost:9000
 * @param accessKey        访问密钥
 * @param secretKey        秘密密钥
 * @param bucket           bucket 名称
 * @param publicUrl        外部访问 URL 前缀（私有策略下未使用，保留兼容）
 * @param region           区域
 * @param publicReadPolicy 是否设置 bucket 公共读策略（私有策略下应为 false）
 * @author mmm
 */
@ConfigurationProperties(prefix = "minio")
public record MinioProperties(
        boolean enabled,          // 是否启用 MinIO
        String endpoint,          // MinIO 端点 URL
        String accessKey,         // 访问密钥
        String secretKey,         // 秘密密钥
        String bucket,            // bucket 名称
        String publicUrl,         // 外部访问 URL 前缀（保留字段）
        String region,            // 区域
        boolean publicReadPolicy  // 公共读策略（私有策略下为 false）
) {
    /**
     * 紧凑构造器：对缺失字段做兜底。
     */
    public MinioProperties {
        // region 为空或空白时默认 us-east-1
        if (region == null || region.isBlank()) {
            region = "us-east-1";
        }
        // bucket 为空或空白时默认 snow-chat
        if (bucket == null || bucket.isBlank()) {
            bucket = "snow-chat";
        }
    }
}
