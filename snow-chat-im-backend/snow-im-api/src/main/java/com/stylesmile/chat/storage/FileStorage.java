package com.stylesmile.chat.storage;

import java.io.InputStream;

/**
 * 文件存储出站端口接口。
 * 抽象文件上传 / 删除 / 查询 / 生成预签名 URL 的能力，
 * 可由 MinioFileStorage（生产）或 InMemoryFileStorage（降级/测试）实现。
 *
 * <p>本接口采用"私有 + Pre-signed URL"策略：
 * <ul>
 *   <li>{@link #upload} 返回对象 key（如 {@code avatars/uuid.jpg}），不返回 URL；</li>
 *   <li>访问 URL 由 {@link #generatePresignedUrl} 单独生成，带签名与有效期。</li>
 * </ul>
 * 数据库的 avatar 字段存 key，对外返回时动态生成 pre-signed URL。
 *
 * @author mmm
 */
public interface FileStorage {

    /**
     * 上传文件到对象存储。
     *
     * @param inputStream 文件输入流
     * @param fileName    对象 key（如 avatars/uuid.jpg）
     * @param contentType MIME 类型（如 image/jpeg）
     * @param fileSize    文件字节数
     * @return 对象 key（与传入 fileName 一致），用于后续生成 pre-signed URL
     */
    String upload(InputStream inputStream, String fileName, String contentType, long fileSize);

    /**
     * 删除指定对象。
     *
     * @param fileName 对象 key
     */
    void delete(String fileName);

    /**
     * 判断对象是否存在。
     *
     * @param fileName 对象 key
     * @return 存在返回 true
     */
    boolean exists(String fileName);

    /**
     * 生成下载用的预签名 URL。
     *
     * @param fileName          对象 key
     * @param expirationMinutes URL 有效期（分钟）
     * @return 带签名的 URL 字符串
     */
    String generatePresignedUrl(String fileName, int expirationMinutes);

    /**
     * 生成可直接访问的完整 URL（公共读存储模式专用）。
     *
     * <p>对于公共读存储（如 SeaweedFS publicRead=true、MinIO publicRead=true），
     * 返回无需签名即可直接访问的 HTTP/HTTPS URL，数据库可直接存储此值。
     * 对于私有读存储（MinIO 私有策略、InMemory），默认回退到 generatePresignedUrl。
     *
     * @param fileName 对象 key（如 avatars/uuid.jpg）或已是完整 URL
     * @return 完整可访问的 URL 字符串
     */
    default String generateUrl(String fileName) {
        return generatePresignedUrl(fileName, Integer.MAX_VALUE);
    }
}
