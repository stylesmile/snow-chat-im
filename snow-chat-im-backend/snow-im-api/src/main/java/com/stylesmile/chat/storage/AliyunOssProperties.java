package com.stylesmile.chat.storage;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * 阿里云 OSS 配置属性。
 * 对应 application-dev.yml / application-prod.yml 中的 {@code aliyun-oss} 配置段，
 * 仅当 {@code storage.type=aliyun-oss} 时才会被真正使用。
 *
 * <p>字段说明：
 * <ul>
 *   <li>{@code endpoint}：OSS 区域端点，如 {@code https://oss-cn-hangzhou.aliyuncs.com}；</li>
 *   <li>{@code accessKeyId} / {@code accessKeySecret}：RAM 子账号的 AccessKey（遵循最小权限原则）；</li>
 *   <li>{@code bucket}：Bucket 名称；</li>
 *   <li>{@code publicBaseUrl}：自定义域名 / CDN 前缀；留空时按 {@code https://{bucket}.{endpoint主机名}} 推导；</li>
 *   <li>{@code publicRead}：true=公共读（generateUrl 返回直链，DB 存 key）；false=私有读（返回签名 URL）；</li>
 *   <li>{@code presignExpirationMinutes}：私有读签名 URL 有效期（分钟），默认 7 天。</li>
 * </ul>
 *
 * <p>兜底策略与 {@link MinioProperties} 保持一致：缺失字段给默认值而非抛异常，
 * 保证"只填了 ak/sk"这类不完整配置也能把应用拉起来，问题留到实际上传时暴露。
 *
 * @param endpoint                OSS 区域端点
 * @param accessKeyId             AccessKey ID
 * @param accessKeySecret         AccessKey Secret
 * @param bucket                  Bucket 名称
 * @param publicBaseUrl           自定义域名 / CDN 前缀（可为空）
 * @param publicRead              是否公共读
 * @param presignExpirationMinutes 签名 URL 有效期（分钟）
 * @author mmm
 * @see AliyunOssFileStorage
 * @see AliyunOssConfig
 */
@ConfigurationProperties(prefix = "aliyun-oss")
public record AliyunOssProperties(
        String endpoint,                // OSS 区域端点
        String accessKeyId,             // 访问密钥 ID
        String accessKeySecret,         // 访问密钥 Secret
        String bucket,                  // bucket 名称
        String publicBaseUrl,           // 自定义域名 / CDN 前缀
        boolean publicRead,             // 是否公共读
        int presignExpirationMinutes    // 签名 URL 有效期（分钟）
) {

    /** 默认端点：华东1（杭州）。用于 endpoint 未配置时的兜底 */
    private static final String DEFAULT_ENDPOINT = "https://oss-cn-hangzhou.aliyuncs.com";

    /** 默认 bucket 名称，与 MinIO 配置保持一致，减少迁移成本 */
    private static final String DEFAULT_BUCKET = "snow-chat";

    /** 默认签名有效期：7 天（7 * 24 * 60 分钟） */
    private static final int DEFAULT_PRESIGN_MINUTES = 7 * 24 * 60;

    /**
     * 紧凑构造器：对缺失字段做兜底，避免"配置不全 → 启动期 NPE"。
     */
    public AliyunOssProperties {
        // endpoint 为空时使用默认区域端点
        if (endpoint == null || endpoint.isBlank()) {
            endpoint = DEFAULT_ENDPOINT;
        }
        // bucket 为空时使用默认名称
        if (bucket == null || bucket.isBlank()) {
            bucket = DEFAULT_BUCKET;
        }
        // 签名有效期非正数时使用默认 7 天（防止配置成 0 导致签名立即失效）
        if (presignExpirationMinutes <= 0) {
            presignExpirationMinutes = DEFAULT_PRESIGN_MINUTES;
        }
    }

    /**
     * 解析公共读模式下的访问基础地址（不含对象 key）。
     *
     * <p>规则：
     * <ol>
     *   <li>配置了 {@code publicBaseUrl}（自定义域名 / CDN）→ 直接使用，并去掉尾部斜杠；</li>
     *   <li>未配置 → 按 OSS virtual-hosted style 推导为 {@code {协议}://{bucket}.{endpoint主机名}}。</li>
     * </ol>
     * 之所以要推导而不是直接拼 endpoint，是因为 OSS 默认访问地址必须带上 bucket 子域名，
     * 直接 {endpoint}/{key} 会 404。
     *
     * @return 形如 {@code https://snow-chat.oss-cn-hangzhou.aliyuncs.com} 或 {@code https://cdn.example.com}
     */
    public String resolvePublicBaseUrl() {
        // 优先使用显式配置的自定义域名（通常已接入 CDN，访问更快）
        if (publicBaseUrl != null && !publicBaseUrl.isBlank()) {
            return stripTrailingSlashes(publicBaseUrl);
        }
        // 未配置域名：从 endpoint 拆出协议与主机名
        String cleanedEndpoint = stripTrailingSlashes(endpoint);
        int schemeSeparator = cleanedEndpoint.indexOf("://");
        // 有协议前缀时拆分，无协议前缀时默认 https
        String scheme = schemeSeparator >= 0 ? cleanedEndpoint.substring(0, schemeSeparator) : "https";
        String host = schemeSeparator >= 0
                ? cleanedEndpoint.substring(schemeSeparator + "://".length())
                : cleanedEndpoint;
        // 按 virtual-hosted style 拼出 bucket 子域名
        return scheme + "://" + bucket + "." + host;
    }

    /**
     * 去掉字符串尾部的所有斜杠，避免与 key 拼接时产生双斜杠。
     *
     * @param value 原始字符串
     * @return 去掉尾部斜杠后的字符串
     */
    private static String stripTrailingSlashes(String value) {
        return value.replaceAll("/+$", "");
    }
}
