package com.stylesmile.chat.service;

import com.stylesmile.chat.dto.UploadResult;
import org.springframework.web.multipart.MultipartFile;

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
     * 上传文件并生成 pre-signed URL。
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
}
