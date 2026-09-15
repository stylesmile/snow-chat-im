package com.stylesmile.chat.storage;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.Optional;

/**
 * 本地磁盘文件存储实现（{@code storage.type=disk}）。
 *
 * <p>与 {@link InMemoryFileStorage} 的区别：文件真正落到磁盘（默认 {@code ~/snow-file}），
 * 因此**后端重启后文件仍在**；生成的访问地址是真实 HTTP URL
 * （{@code {disk.public-url}/file/raw/{key}}），而不是内嵌 base64 的 data URL。
 *
 * <p>之所以要新增这套实现：消息体（图片/视频）的 content 会持久化到数据库并被
 * 对方拉取，若写入 base64 data URL，一条普通图片消息动辄几百 KB～数 MB，
 * 既撑爆消息表也让聊天列表摘要无法渲染。改为 URL 后消息体只有几十字节。
 *
 * <p>安全：key 一律先经 {@link #resolve} 归一化，拒绝 {@code ..} 之类的路径穿越。
 *
 * @author mmm
 * @see FileStorage
 * @see DiskProperties
 * @see StorageType
 */
@Component
@ConditionalOnProperty(prefix = "storage", name = "type", havingValue = "disk")
public class LocalDiskFileStorage implements FileStorage {

    /** 落盘根目录（构造时创建） */
    private final Path root;

    /** 外部访问前缀，用于拼接完整 URL */
    private final String publicUrl;

    /**
     * 构造器注入磁盘配置。
     *
     * @param properties 磁盘存储配置（路径 + 外部访问前缀）
     * @throws IOException 根目录无法创建时抛出（配置错误应当快速失败）
     */
    public LocalDiskFileStorage(DiskProperties properties) throws IOException {
        this.root = Path.of(properties.resolvedPath()).toAbsolutePath().normalize();
        this.publicUrl = properties.publicUrl();
        // 启动时即创建根目录，避免首次上传才暴露权限问题
        Files.createDirectories(this.root);
    }

    /**
     * 上传文件到磁盘，返回对象 key。
     */
    @Override
    public String upload(InputStream inputStream, String fileName, String contentType, long fileSize) {
        Path target = resolve(fileName);
        try {
            // 父目录可能不存在（如 avatars/、images/），先创建
            Path parent = target.getParent();
            if (parent != null) {
                Files.createDirectories(parent);
            }
            // 覆盖写入：key 已含 UUID，正常情况下不会冲突
            try (InputStream in = inputStream) {
                Files.copy(in, target, StandardCopyOption.REPLACE_EXISTING);
            }
            return fileName;
        } catch (IOException e) {
            throw new RuntimeException("Failed to write file to disk", e);
        }
    }

    /**
     * 从磁盘删除文件。
     */
    @Override
    public void delete(String fileName) {
        try {
            Files.deleteIfExists(resolve(fileName));
        } catch (IOException e) {
            throw new RuntimeException("Failed to delete file from disk", e);
        }
    }

    /**
     * 判断文件是否存在。
     */
    @Override
    public boolean exists(String fileName) {
        return Files.isRegularFile(resolve(fileName));
    }

    /**
     * 生成可直接访问的 HTTP URL（disk 模式为公共读，无需签名）。
     *
     * @param fileName          对象 key
     * @param expirationMinutes 有效期（本实现忽略：本地磁盘文件不做过期）
     * @return {@code {publicUrl}/file/raw/{key}}
     */
    @Override
    public String generatePresignedUrl(String fileName, int expirationMinutes) {
        if (fileName == null || fileName.isBlank()) {
            return "";
        }
        return publicUrl + "/file/raw/" + fileName;
    }

    /**
     * 读取文件内容（供 {@code GET /file/raw/**} 下载端点使用）。
     *
     * @param fileName 对象 key
     * @return 文件输入流；文件不存在时返回 null
     */
    @Override
    public InputStream load(String fileName) {
        Path target = resolve(fileName);
        if (!Files.isRegularFile(target)) {
            return null;
        }
        try {
            return Files.newInputStream(target);
        } catch (IOException e) {
            throw new RuntimeException("Failed to read file from disk", e);
        }
    }

    /**
     * 把对象 key 解析为磁盘绝对路径，并阻断路径穿越。
     *
     * <p>归一化后必须仍在根目录之内，否则直接拒绝 —— 防止形如
     * {@code images/../../etc/passwd} 的 key 读写任意文件。
     *
     * @param fileName 对象 key，如 {@code images/uuid.jpg}
     * @return 归一化后的绝对路径
     * @throws IllegalArgumentException key 非法或超出根目录时抛出
     */
    private Path resolve(String fileName) {
        if (fileName == null || fileName.isBlank()) {
            throw new IllegalArgumentException("对象 key 不能为空");
        }
        Path resolved = root.resolve(fileName).normalize();
        if (!resolved.startsWith(root)) {
            throw new IllegalArgumentException("非法的对象 key: " + fileName);
        }
        return resolved;
    }

    /**
     * 暴露根目录，便于测试与运维核对落盘位置。
     *
     * @return 落盘根目录绝对路径
     */
    public Optional<Path> rootPath() {
        return Optional.of(root);
    }
}
