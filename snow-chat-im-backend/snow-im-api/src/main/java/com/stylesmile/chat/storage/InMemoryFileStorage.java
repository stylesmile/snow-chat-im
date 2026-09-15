package com.stylesmile.chat.storage;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

import java.io.InputStream;
import java.util.Base64;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * 内存文件存储降级实现。
 * 当 {@code storage.type} 未配置或配置为 {@code local} 时启用，用于本地开发与单元测试。
 *
 * <p>装配条件使用 {@code matchIfMissing = true}：即使完全没写 {@code storage.type}
 * 也能把应用拉起来（避免因漏配导致启动失败）。但 {@code storage.type} 一旦配成
 * {@code minio}/{@code seaweedfs}/{@code aliyun-oss}，本实现就不会被装配，
 * 因此不会与其它实现产生"同一接口多个 Bean"的冲突。
 *
 * <p>注意：应用重启后所有文件丢失；upload 返回对象 key（与接口契约一致），
 * generatePresignedUrl 返回 base64 data URL（内嵌图片数据，永久有效，无需签名）。
 *
 * @author mmm
 * @see FileStorage
 * @see MinioFileStorage
 * @see AliyunOssFileStorage
 * @see StorageType
 */
@Component
@ConditionalOnProperty(prefix = "storage", name = "type", havingValue = "local", matchIfMissing = true)
public class InMemoryFileStorage implements FileStorage {

    // 内存存储：key → 文件字节
    private final Map<String, byte[]> storage = new ConcurrentHashMap<>();
    // 默认 MIME 类型（未知扩展名时使用）
    private static final String DEFAULT_CONTENT_TYPE = "application/octet-stream";

    /**
     * 根据文件名扩展名推断 MIME 类型。
     */
    private static String inferContentType(String key) {
        int dot = key.lastIndexOf('.');
        if (dot < 0) return DEFAULT_CONTENT_TYPE;
        String ext = key.substring(dot + 1).toLowerCase();
        return switch (ext) {
            case "jpg", "jpeg" -> "image/jpeg";
            case "png" -> "image/png";
            case "gif" -> "image/gif";
            case "webp" -> "image/webp";
            default -> DEFAULT_CONTENT_TYPE;
        };
    }

    /**
     * 上传文件到内存，返回对象 key。
     */
    @Override
    public String upload(InputStream inputStream, String fileName, String contentType, long fileSize) {
        try {
            // 读取全部字节到内存
            byte[] data = inputStream.readAllBytes();
            // 存入 Map
            storage.put(fileName, data);
            // 返回对象 key（私有策略契约）
            return fileName;
        } catch (Exception e) {
            // 抛出运行时异常，保持与 MinIO 实现一致的失败语义
            throw new RuntimeException("Failed to read file", e);
        }
    }

    /**
     * 从内存删除文件。
     */
    @Override
    public void delete(String fileName) {
        // 直接从 Map 移除
        storage.remove(fileName);
    }

    /**
     * 判断文件是否存在。
     */
    @Override
    public boolean exists(String fileName) {
        // 查 Map 是否包含 key
        return storage.containsKey(fileName);
    }

    /**
     * 生成 base64 data URL（内嵌图片数据，永久有效）。
     *
     * <p>与 MinIO 不同：InMemory 模式不生成外部可访问 URL，而是将文件字节
     * 直接编码为 {@code data:image/xxx;base64,...} 格式，前端可直接用于 img src。
     *
     * @param fileName              对象 key
     * @param expirationMinutes     有效期（本实现忽略，data URL 永久有效）
     * @return base64 data URL 字符串
     */
    @Override
    public String generatePresignedUrl(String fileName, int expirationMinutes) {
        byte[] data = storage.get(fileName);
        if (data == null || data.length == 0) {
            return ""; // 文件不存在时返回空串
        }
        // 推断 MIME 类型并拼接 data URL
        String contentType = inferContentType(fileName);
        String base64 = Base64.getEncoder().encodeToString(data);
        return "data:" + contentType + ";base64," + base64;
    }
}
