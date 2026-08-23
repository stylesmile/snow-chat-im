package com.stylesmile.chat.service.impl;

import com.stylesmile.chat.dto.UploadResult;
import com.stylesmile.chat.service.FileStorageService;
import com.stylesmile.chat.storage.FileStorage;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.Base64;
import java.util.UUID;

/**
 * 文件存储服务实现。
 *
 * <p>负责：
 * <ul>
 *   <li>生成 {@code avatars/{uuid}.{ext}} 形式的对象 key；</li>
 *   <li>委托 {@link FileStorage} 完成实际上传与 pre-signed URL 生成；</li>
 *   <li>返回 {@link UploadResult} 给上层。</li>
 * </ul>
 *
 * <p>设计要点：
 * <ul>
 *   <li>key 前缀固定为 {@code avatars/}，便于在 {@code info} 端点识别头像 key 并动态生成 URL；</li>
 *   <li>pre-signed URL 有效期 7 天（{@code 7*24*60} 分钟）；</li>
 *   <li>无扩展名的文件直接使用 UUID 作为 key，不追加 {@code .ext}。</li>
 * </ul>
 *
 * @author mmm
 */
@Service
public class FileStorageServiceImpl implements FileStorageService {

    /**
     * 头像对象 key 的统一前缀。
     * 后端 {@code info} 端点据此判断是否需要将 DB 中的 key 转换为 pre-signed URL。
     */
    private static final String AVATAR_KEY_PREFIX = "avatars/";

    /**
     * pre-signed URL 有效期：7 天（单位：分钟）。
     * 7 * 24 * 60 = 10080 分钟。
     */
    private static final int PRESIGN_EXPIRATION_MINUTES = 7 * 24 * 60;

    /**
     * 文件存储出站端口，由 Spring 注入具体实现（MinioFileStorage 或 InMemoryFileStorage）。
     */
    private final FileStorage fileStorage;

    /**
     * 构造器注入 FileStorage。
     *
     * @param fileStorage 文件存储实现
     */
    public FileStorageServiceImpl(FileStorage fileStorage) {
        this.fileStorage = fileStorage; // 保存文件存储实现
    }

    /**
     * 上传文件并生成 pre-signed URL。
     *
     * @param file 前端上传的 multipart 文件
     * @return UploadResult(key, url)
     */
    @Override
    public UploadResult uploadAndSign(MultipartFile file) {
        // 1. 生成对象 key：avatars/{uuid}.{ext}
        String objectKey = generateObjectKey(file.getOriginalFilename());
        // 2. 读取文件输入流与元数据
        String contentType = file.getContentType();            // MIME 类型
        long fileSize = file.getSize();                         // 文件字节数
        // 3. 委托 FileStorage 上传二进制，返回 key
        try (InputStream inputStream = file.getInputStream()) {
            // upload 返回值应与 objectKey 一致（私有策略契约）
            String returnedKey = fileStorage.upload(inputStream, objectKey, contentType, fileSize);
            // 4. 生成 7 天有效的 pre-signed URL
            String presignedUrl = fileStorage.generatePresignedUrl(returnedKey, PRESIGN_EXPIRATION_MINUTES);
            // 5. 封装结果返回
            return new UploadResult(returnedKey, presignedUrl);
        } catch (IOException e) {
            // 输入流读取失败时抛出运行时异常，由 GlobalExceptionHandler 统一处理
            throw new RuntimeException("Failed to read multipart file input stream", e);
        }
    }

    /**
     * 为已存储的头像 key 实时生成可访问 URL。
     *
     * <p>MinIO 模式：生成带签名的下载链接（7 天有效）。
     * <p>InMemory 模式：读取内存字节，转为 base64 data URL，无需签名。
     *
     * @param avatarKey 存储 key（如 {@code avatars/uuid.jpg}）
     * @return 可直接用于 img src 的 URL
     */
    @Override
    public String generateAvatarUrl(String avatarKey) {
        // 委托 FileStorage 实现生成对应模式的 URL
        // MinioFileStorage 会生成带签名的 HTTPS URL
        // InMemoryFileStorage 会生成 base64 data URL（内嵌图片数据，永久有效）
        return fileStorage.generatePresignedUrl(avatarKey, PRESIGN_EXPIRATION_MINUTES);
    }

    /**
     * 根据原始文件名生成对象 key。
     *
     * <p>规则：
     * <ul>
     *   <li>前缀固定为 {@code avatars/}；</li>
     *   <li>主体为 UUID（避免文件名冲突与信息泄漏）；</li>
     *   <li>保留原始文件扩展名（小写）；无扩展名时不追加。</li>
     * </ul>
     *
     * @param originalFilename 原始文件名（可能为 null）
     * @return 对象 key，如 {@code avatars/550e8400-e29b-41d4-a716-446655440000.jpg}
     */
    private String generateObjectKey(String originalFilename) {
        // 生成随机 UUID 作为主体
        String uuid = UUID.randomUUID().toString();
        // 提取扩展名（不含点号）
        String extension = extractExtension(originalFilename);
        // 拼接 key：有扩展名则追加 .ext，否则仅用 UUID
        return extension.isEmpty()
                ? AVATAR_KEY_PREFIX + uuid
                : AVATAR_KEY_PREFIX + uuid + "." + extension;
    }

    /**
     * 从文件名中提取扩展名（小写，不含点号）。
     *
     * @param filename 文件名（可能为 null 或无扩展名）
     * @return 扩展名（如 {@code jpg}），无扩展名时返回空字符串
     */
    private String extractExtension(String filename) {
        // 文件名为空直接返回空串
        if (filename == null) {
            return "";
        }
        // 查找最后一个点号
        int lastDot = filename.lastIndexOf('.');
        // 未找到点号或点号在末尾（无扩展名）
        if (lastDot < 0 || lastDot == filename.length() - 1) {
            return "";
        }
        // 截取并转小写
        return filename.substring(lastDot + 1).toLowerCase();
    }
}
