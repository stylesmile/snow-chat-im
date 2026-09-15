package com.stylesmile.chat.service;

import com.stylesmile.chat.dto.UploadResult;
import org.springframework.web.multipart.MultipartFile;

import java.io.InputStream;

/**
 * 文件存储服务接口。
 *
 * <p>应用层通过此接口完成文件上传与签名 URL 生成，
 * 具体存储细节（MinIO / 内存降级）由实现类依赖 {@link com.stylesmile.chat.storage.FileStorage} 完成。
 *
 * @author mmm
 * @see com.stylesmile.chat.service.impl.FileStorageServiceImpl
 * @see com.stylesmile.chat.storage.FileStorage
 */
public interface FileStorageService {

    /**
     * 上传文件并生成 pre-signed URL（默认目录前缀 {@code avatars/}）。
     *
     * <p>流程：
     * <ol>
     *   <li>根据原始文件名生成 {@code avatars/{uuid}.{ext}} 形式的对象 key；</li>
     *   <li>调用 {@link com.stylesmile.chat.storage.FileStorage#upload} 上传二进制；</li>
     *   <li>调用 {@link com.stylesmile.chat.storage.FileStorage#generatePresignedUrl} 生成 7 天有效的访问 URL；</li>
     *   <li>返回 {@link UploadResult}（key + url）。</li>
     * </ol>
     *
     * @param file 前端上传的 multipart 文件
     * @return 包含 key 与 pre-signed URL 的结果对象
     */
    UploadResult uploadAndSign(MultipartFile file);

    /**
     * 上传媒体/附件文件并生成 pre-signed URL（按 mediaType 选择目录前缀）。
     *
     * <p>与 {@link #uploadAndSign(MultipartFile)} 的区别：
     * <ul>
     *   <li>{@code mediaType=images} → {@code images/{uuid}.{ext}}；</li>
     *   <li>{@code mediaType=videos} → {@code videos/{uuid}.{ext}}；</li>
     *   <li>{@code mediaType=files} → {@code files/{uuid}.{ext}}。</li>
     * </ul>
     * 供消息附件上传使用：前端上传成功后将返回的 URL 存入消息 {@code content} 字段，
     * 并用 {@code type}（image/video/file）标识消息类型，前端消息气泡据此渲染。
     *
     * @param file      前端上传的 multipart 文件
     * @param mediaType 媒体类型标识（images / videos / files），用于生成目录前缀
     * @return 包含 key 与 pre-signed URL 的结果对象
     * @throws IllegalArgumentException 当 mediaType 不在允许集合中时抛出
     */
    UploadResult uploadAndSign(MultipartFile file, String mediaType);

    /**
     * 读取已存储对象的字节流，供本地磁盘存储对外提供下载端点。
     *
     * <p>对象存储（MinIO / SeaweedFS / OSS）走 generatePresignedUrl 直链，
     * 不需要经本服务中转，因此只有 {@code storage.type=disk} 的实现会真正返回内容。
     *
     * @param key 对象 key，如 {@code images/uuid.jpg}
     * @return 文件输入流；不存在或实现不支持时返回 null
     */
    InputStream load(String key);

    /**
     * 为已存储的头像 key 实时生成可访问 URL。
     *
     * <p>用于 {@code GET /chat/user/info} 接口：将 DB 中存储的 avatar key（如 {@code avatars/uuid.jpg}）
     * 动态转换为当前有效的访问地址。MinIO 模式下生成带签名的下载链接，InMemory 模式下
     * 返回内嵌 base64 的 data URL（确保前端可直接展示）。
     *
     * @param avatarKey 存储 key（以 {@code avatars/} 开头）
     * @return 可直接用于 img src 的 URL 字符串
     */
    String generateAvatarUrl(String avatarKey);
}
