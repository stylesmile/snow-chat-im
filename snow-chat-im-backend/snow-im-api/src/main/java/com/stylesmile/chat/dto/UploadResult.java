package com.stylesmile.chat.dto;

import io.swagger.v3.oas.annotations.media.Schema;

/**
 * 文件上传结果DTO
 *
 * <p>采用"私有 + Pre-signed URL"策略：
 * <ul>
 *   <li>{@code key}：对象存储中的 key（如 {@code avatars/uuid.jpg}），用于持久化到数据库；</li>
 *   <li>{@code url}：访问该对象用的 pre-signed URL（带有效期），前端可直接用于展示。</li>
 * </ul>
 *
 * <p>使用 Java 17 record 简化不可变数据载体定义，自动生成构造器、访问器、equals/hashCode/toString。
 *
 * @author mmm
 */
@Schema(description = "文件上传结果")
public record UploadResult(
        @Schema(description = "对象存储key", example = "avatars/abc123.jpg")
        String key,
        @Schema(description = "访问URL（pre-signed或永久）", example = "https://cdn.example.com/avatars/abc123.jpg")
        String url
) {}
