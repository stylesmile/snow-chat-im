package com.stylesmile.chat.storage;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

import java.io.InputStream;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * 内存文件存储降级实现。
 * 当 minio.enabled=false 或未配置时启用，用于本地开发与单元测试。
 *
 * <p>注意：应用重启后所有文件丢失；upload 返回对象 key（与接口契约一致），
 * generatePresignedUrl 返回带 expires 参数的占位 URL（不真正签名）。
 *
 * @author mmm
 * @see FileStorage
 * @see MinioFileStorage
 */
@Component
@ConditionalOnProperty(name = "minio.enabled", havingValue = "false", matchIfMissing = true)
public class InMemoryFileStorage implements FileStorage {

    // 内存存储：key → 文件字节
    private final Map<String, byte[]> storage = new ConcurrentHashMap<>();
    // 占位 URL 前缀
    private final String baseUrl;

    /**
     * 默认构造器，使用固定占位 URL 前缀。
     */
    public InMemoryFileStorage() {
        // 设置占位 URL 前缀（仅供测试）
        this.baseUrl = "http://localhost:8080/files";
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
     * 生成占位的 pre-signed URL（带 expires 参数）。
     */
    @Override
    public String generatePresignedUrl(String fileName, int expirationMinutes) {
        // 拼接占位 URL，包含 key 与过期时间
        return baseUrl + "/" + fileName + "?expires=" + expirationMinutes;
    }
}
