package com.stylesmile.chat.storage;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * SeaweedFS 配置属性。
 * 对应 application-dev.yml / application-test.yml / application-prod.yml 中的 {@code seaweedfs} 配置段。
 *
 * <p>SeaweedFS 是一个轻量级分布式文件系统，提供 REST API（/volume/{vid}/upload、/dir/ls）和 HTTP 直接访问。
 * 本实现使用 OkHttp 调用其 REST API 完成文件上传与删除，支持公共读模式（URL 直接可访问）。
 *
 * <p>字段说明：
 * <ul>
 *   <li>{@code enabled}：兼容字段，**已不再参与 Bean 装配**，实际启用与否由 {@code storage.type=seaweedfs} 决定；</li>
 *   <li>{@code endpoint}：SeaweedFS master 服务地址，如 http://localhost:8888；</li>
 *   <li>{@code uploadPath}：上传目标路径，格式为 /{volume_id}（如 /1）；</li>
 *   <li>{@code publicRead}：是否公共读（true 时文件可通过 endpoint/filename 直接访问，无需签名）；</li>
 *   <li>{@code publicBaseUrl}：公共读时的外部访问前缀（如 http://cdn.example.com）；为空时使用 endpoint。</li>
 * </ul>
 *
 * @param enabled         兼容字段：是否启用 SeaweedFS（装配由 storage.type 决定）
 * @param endpoint        SeaweedFS Master 服务地址，如 http://localhost:8888
 * @param uploadPath      上传到的 volume 路径，格式为 /{volumeId}，如 /1
 * @param publicRead      是否设置公共读（true 时 generateUrl 返回完整可直接访问的 URL）
 * @param publicBaseUrl   外部可访问的 CDN 或公网前缀；为空时使用 endpoint
 * @author mmm
 * @see StorageType
 */
@ConfigurationProperties(prefix = "seaweedfs")
public record SeaweedfsProperties(
        boolean enabled,          // 兼容字段：是否启用 SeaweedFS（装配由 storage.type 决定）
        String endpoint,          // SeaweedFS Master 端点，如 http://localhost:8888
        String uploadPath,        // 上传体积路径，如 /1
        boolean publicRead,       // 公共读策略（true 时返回完整 URL，数据库存储完整地址）
        String publicBaseUrl      // 公共访问基础 URL，用于拼接完整文件下载地址；为空时使用 endpoint
) {
    /**
     * 紧凑构造器：对缺失字段做兜底。
     * publicBaseUrl 为空时使用空字符串，由 Storage 层在运行时推断。
     */
    public SeaweedfsProperties {
        if (endpoint == null || endpoint.isBlank()) {
            endpoint = "http://localhost:8888";
        }
        if (uploadPath == null || uploadPath.isBlank()) {
            uploadPath = "/1";
        }
        // publicBaseUrl 允许为空，为空时由实现层用 endpoint 替代
    }
}
