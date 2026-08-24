package com.stylesmile.chat.service.impl;

import com.stylesmile.chat.dto.UploadResult;
import com.stylesmile.chat.service.FileStorageService;
import com.stylesmile.chat.storage.FileStorage;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.io.InputStream;
import java.util.Set;
import java.util.UUID;

/**
 * 文件存储服务实现。
 *
 * <p>负责：
 * <ul>
 *   <li>生成对象 key（按用途区分目录：{@code avatars/}、{@code images/}、{@code videos/}、{@code files/}）；</li>
 *   <li>委托 {@link FileStorage} 完成实际上传与 URL 生成；</li>
 *   <li>返回 {@link UploadResult} 给上层。</li>
 * </ul>
 *
 * <p>URL 策略：
 * <ul>
 *   <li>公共读存储（{@code seaweedfs.public-read=true}、{@code minio.public-read-policy=true}）：
 *       直接调用 {@link FileStorage#generateUrl} 返回完整可访问 URL，数据库存储完整地址；</li>
 *   <li>私有读存储（默认）：调用 {@link FileStorage#generatePresignedUrl} 返回带签名的临时 URL（7天有效）。</li>
 * </ul>
 *
 * @author mmm
 */
@Service
public class FileStorageServiceImpl implements FileStorageService {

    /**
     * 头像对象 key 的统一前缀。
     * 后端 {@code info} 端点据此判断是否需要将 DB 中的 key 转换为 URL。
     */
    private static final String AVATAR_KEY_PREFIX = "avatars/";

    /**
     * 媒体文件对象 key 前缀映射：mediaType（images/videos/files/voices）→ 目录前缀。
     * 仅允许这四种前缀，防止任意目录写入（路径穿越攻击）。
     */
    private static final Set<String> ALLOWED_MEDIA_PREFIXES = Set.of("images/", "videos/", "files/", "voices/");

    /**
     * pre-signed URL 有效期：7 天（单位：分钟）。
     * 7 * 24 * 60 = 10080 分钟。
     */
    private static final int PRESIGN_EXPIRATION_MINUTES = 7 * 24 * 60;

    /**
     * 文件存储出站端口，由 Spring 注入具体实现（MinioFileStorage / SeaweedfsFileStorage / InMemoryFileStorage）。
     */
    private final FileStorage fileStorage;

    /**
     * 构造器注入 FileStorage（Spring 自动根据条件装配具体实现）。
     *
     * @param fileStorage 文件存储实现
     */
    public FileStorageServiceImpl(FileStorage fileStorage) {
        this.fileStorage = fileStorage; // 保存文件存储实现
    }

    /**
     * 上传文件并生成 URL（默认头像目录 {@code avatars/}）。
     *
     * <p>公共读模式：返回完整可直接访问的 URL；私有读模式：返回带签名的临时 URL。
     *
     * @param file 前端上传的 multipart 文件
     * @return UploadResult(key, url)
     */
    @Override
    public UploadResult uploadAndSign(MultipartFile file) {
        // 1. 生成对象 key：avatars/{uuid}.{ext}
        String objectKey = generateObjectKey(file.getOriginalFilename(), AVATAR_KEY_PREFIX);
        // 2. 读取文件输入流与元数据
        String contentType = file.getContentType();            // MIME 类型
        long fileSize = file.getSize();                         // 文件字节数
        // 3. 委托 FileStorage 上传二进制，返回 key 或完整 URL（公共读时直接返回）
        try (InputStream inputStream = file.getInputStream()) {
            String returnedKey = fileStorage.upload(inputStream, objectKey, contentType, fileSize);
            // 4. 生成访问 URL：公共读用 generateUrl，私有读用 generatePresignedUrl
            String url = fileStorage.generateUrl(returnedKey);
            // 5. 封装结果返回
            return new UploadResult(returnedKey, url);
        } catch (IOException e) {
            // 输入流读取失败时抛出运行时异常，由 GlobalExceptionHandler 统一处理
            throw new RuntimeException("Failed to read multipart file input stream", e);
        }
    }

    /**
     * 上传媒体/附件文件并生成 URL（按 mediaType 选目录前缀）。
     *
     * <p>与 {@link #uploadAndSign(MultipartFile)} 的区别是目录前缀由 {@code mediaType} 决定。
     *
     * @param file      前端上传的 multipart 文件
     * @param mediaType 媒体类型标识（images / videos / files），用于生成目录前缀
     * @return UploadResult(key, url)
     * @throws IllegalArgumentException 当 mediaType 不在允许集合中时抛出
     */
    @Override
    public UploadResult uploadAndSign(MultipartFile file, String mediaType) {
        // 1. 根据 mediaType 确定目录前缀（必须属于白名单，否则直接拒绝，防止路径穿越）
        String prefix = resolveMediaPrefix(mediaType);
        // 2. 生成对象 key：{prefix}{uuid}.{ext}
        String objectKey = generateObjectKey(file.getOriginalFilename(), prefix);
        // 3. 读取文件输入流与元数据
        String contentType = file.getContentType();            // MIME 类型
        long fileSize = file.getSize();                         // 文件字节数
        // 4. 委托 FileStorage 上传二进制，返回 key 或完整 URL
        try (InputStream inputStream = file.getInputStream()) {
            String returnedKey = fileStorage.upload(inputStream, objectKey, contentType, fileSize);
            // 5. 生成访问 URL
            String url = fileStorage.generateUrl(returnedKey);
            // 6. 封装结果返回
            return new UploadResult(returnedKey, url);
        } catch (IOException e) {
            // 输入流读取失败时抛出运行时异常，由 GlobalExceptionHandler 统一处理
            throw new RuntimeException("Failed to read multipart file input stream", e);
        }
    }

    /**
     * 将 mediaType 映射到目录前缀（images/、videos/、files/）。
     *
     * <p>安全约束：只允许白名单内的 mediaType，拒绝其他值以防止任意目录写入。
     *
     * @param mediaType 前端传来的媒体类型（如 "images"、"videos"、"files"）
     * @return 对应的目录前缀（如 "images/"）
     * @throws IllegalArgumentException 当 mediaType 不在白名单时抛出
     */
    private String resolveMediaPrefix(String mediaType) {
        // 安全校验：mediaType 必须是白名单之一
        if (!ALLOWED_MEDIA_PREFIXES.contains(mediaType + "/")) {
            throw new IllegalArgumentException("非法的媒体类型: " + mediaType + "，只允许 images/videos/files");
        }
        // 返回标准化前缀
        return mediaType + "/";
    }

    /**
     * 为已存储的头像 key 实时生成可访问 URL。
     *
     * <p>公共读模式：直接返回完整 URL；私有读模式：生成带签名的下载链接。
     *
     * @param avatarKey 存储 key（如 {@code avatars/uuid.jpg}）
     * @return 可直接用于 img src 的 URL
     */
    @Override
    public String generateAvatarUrl(String avatarKey) {
        // 委托 FileStorage 生成对应模式的 URL
        // SeaweedfsFileStorage：返回完整 endpoint + key URL
        // MinioFileStorage：返回 pre-signed URL 或 endpoint + key（publicRead=true）
        // InMemoryFileStorage：返回 base64 data URL
        return fileStorage.generateUrl(avatarKey);
    }

    /**
     * 根据原始文件名生成对象 key。
     *
     * <p>规则：前缀由 {@code prefix} 参数传入（如 {@code avatars/}、{@code images/}）；
     * 主体为 UUID（避免文件名冲突与信息泄漏）；保留原始文件扩展名（小写）。
     *
     * @param originalFilename 原始文件名（可能为 null）
     * @param prefix           目录前缀（如 {@code avatars/}、{@code images/}）
     * @return 对象 key，如 {@code avatars/550e8400-e29b-41d4-a716-446655440000.jpg}
     */
    private String generateObjectKey(String originalFilename, String prefix) {
        // 生成随机 UUID 作为主体
        String uuid = UUID.randomUUID().toString();
        // 提取扩展名（不含点号）
        String extension = extractExtension(originalFilename);
        // 拼接 key：有扩展名则追加 .ext，否则仅用 UUID
        return extension.isEmpty()
                ? prefix + uuid
                : prefix + uuid + "." + extension;
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
