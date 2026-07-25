package com.stylesmile.chat.dto;

/**
 * 文件上传结果 DTO。
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
public record UploadResult(String key, String url) {
    // record 自动提供：
    // - 全参构造器 UploadResult(String key, String url)
    // - 访问器方法 key() / url()
    // - equals / hashCode / toString
}
