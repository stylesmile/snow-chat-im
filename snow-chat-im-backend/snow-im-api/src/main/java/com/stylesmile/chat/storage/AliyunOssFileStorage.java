package com.stylesmile.chat.storage;

import com.aliyun.oss.OSS;
import com.aliyun.oss.model.ObjectMetadata;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

import java.io.InputStream;
import java.util.Date;

/**
 * 阿里云 OSS 文件存储实现（基于阿里云官方 SDK aliyun-sdk-oss）。
 * 当 {@code storage.type=aliyun-oss} 时启用。
 *
 * <p>与 {@link MinioFileStorage} 保持一致的契约：{@link #upload} 始终返回对象 key
 * （数据库存 key，不存 URL），访问地址由 {@link #generateUrl} 按访问策略动态生成。
 * 这样即便日后更换 bucket 域名、接入 CDN 或迁移存储后端，历史数据也无需刷库。
 *
 * <p>两种访问策略：
 * <ul>
 *   <li>公共读（{@code aliyun-oss.public-read=true}）：
 *       {@link #generateUrl} 返回 {@code 自定义域名或推导域名 + / + key} 的直链，无需签名；</li>
 *   <li>私有读（默认 false）：
 *       {@link #generateUrl} 返回带签名与有效期的临时 URL（有效期见配置，默认 7 天）。</li>
 * </ul>
 *
 * @author mmm
 * @see FileStorage
 * @see AliyunOssProperties
 * @see AliyunOssConfig
 */
@Component
@ConditionalOnProperty(prefix = "storage", name = "type", havingValue = "aliyun-oss")
public class AliyunOssFileStorage implements FileStorage {

    /** 日志器 */
    private static final Logger log = LoggerFactory.getLogger(AliyunOssFileStorage.class);

    /** 阿里云 OSS 客户端（由 AliyunOssConfig 创建并托管生命周期） */
    private final OSS ossClient;

    /** OSS 配置属性 */
    private final AliyunOssProperties props;

    /**
     * 构造器：注入 OSS 客户端与配置。
     *
     * @param ossClient OSS 客户端
     * @param props     OSS 配置属性
     */
    public AliyunOssFileStorage(OSS ossClient, AliyunOssProperties props) {
        this.ossClient = ossClient; // 保存 OSS 客户端
        this.props = props;         // 保存配置
        // 启动时打印生效的存储信息，便于线上排障（不打印 ak/sk 等敏感信息）
        log.info("Aliyun OSS storage enabled: bucket={}, publicRead={}, presignExpirationMinutes={}",
                props.bucket(), props.publicRead(), props.presignExpirationMinutes());
    }

    /**
     * 上传文件到阿里云 OSS，返回对象 key。
     *
     * <p>元数据里显式写入 contentLength 与 contentType：
     * 前者保证 SDK 不做分块传输（避免部分网关对 chunked 编码的兼容问题），
     * 后者保证浏览器拿到正确 MIME 类型（图片/视频可直接内联预览）。
     *
     * @param inputStream 文件输入流
     * @param fileName    对象 key（如 avatars/uuid.jpg）
     * @param contentType MIME 类型（如 image/jpeg），可为空
     * @param fileSize    文件字节数
     * @return 对象 key（与传入 fileName 一致）
     */
    @Override
    public String upload(InputStream inputStream, String fileName, String contentType, long fileSize) {
        // 构造对象元数据
        ObjectMetadata metadata = new ObjectMetadata();
        // 设置长度：避免 SDK 走 chunked 编码
        metadata.setContentLength(fileSize);
        // 设置 MIME 类型：仅当调用方提供了有效值时才设置
        if (contentType != null && !contentType.isBlank()) {
            metadata.setContentType(contentType);
        }
        // 显式设置 Content-Disposition: inline，覆盖 bucket 级别的「强制下载」设置。
        // 若不设置，OSS 会返回 Content-Disposition: attachment，导致部分移动端
        // 图片加载库（如 cached_network_image）无法内联展示图片，出现 broken_image。
        metadata.setContentDisposition("inline");
        // 执行上传（SDK 内部会消费 inputStream，由调用方负责关闭）
        ossClient.putObject(props.bucket(), fileName, inputStream, metadata);
        // 记录成功日志（只记 key，不记 URL 与凭证）
        log.info("Aliyun OSS upload success: {}", fileName);
        // 返回对象 key（不是 URL），与 FileStorage 契约一致
        return fileName;
    }

    /**
     * 删除 OSS 上的对象。
     *
     * <p>OSS 的 deleteObject 对不存在的对象不报错（幂等），
     * 因此这里不做存在性预检查，避免多一次网络往返。
     *
     * @param fileName 对象 key
     */
    @Override
    public void delete(String fileName) {
        // 执行删除
        ossClient.deleteObject(props.bucket(), fileName);
        // 记录日志
        log.info("Aliyun OSS delete success: {}", fileName);
    }

    /**
     * 判断对象是否存在。
     *
     * @param fileName 对象 key
     * @return 存在返回 true
     */
    @Override
    public boolean exists(String fileName) {
        // 委托 SDK 发起 HEAD 探测
        return ossClient.doesObjectExist(props.bucket(), fileName);
    }

    /**
     * 生成预签名下载 URL（私有读模式使用）。
     *
     * @param fileName          对象 key
     * @param expirationMinutes URL 有效期（分钟）
     * @return 带签名的 URL 字符串
     */
    @Override
    public String generatePresignedUrl(String fileName, int expirationMinutes) {
        // 把"分钟"换算为绝对过期时刻（SDK 要求传 Date）
        Date expiration = new Date(System.currentTimeMillis() + expirationMinutes * 60L * 1000L);
        // 生成签名 URL 并转为字符串
        return ossClient.generatePresignedUrl(props.bucket(), fileName, expiration).toString();
    }

    /**
     * 生成可直接访问的完整 URL。
     *
     * <p>公共读模式返回直链（不调用 OSS，零网络开销）；
     * 私有读模式回退到带签名的临时 URL；已是完整 URL 的历史数据原样返回。
     *
     * @param fileName 对象 key（如 avatars/uuid.jpg）或已是完整 URL
     * @return 完整可访问的 URL 字符串
     */
    @Override
    public String generateUrl(String fileName) {
        // 空值保护：返回空串而非抛异常，避免影响列表接口整体可用性
        if (fileName == null || fileName.isBlank()) {
            return "";
        }
        // 历史数据里可能已存完整 URL，直接返回避免重复拼接
        if (fileName.startsWith("http://") || fileName.startsWith("https://")) {
            return fileName;
        }
        // 公共读：拼接域名直链（去掉 key 可能带的头部斜杠，避免双斜杠）
        if (props.publicRead()) {
            return props.resolvePublicBaseUrl() + "/" + fileName.replaceAll("^/+", "");
        }
        // 私有读：生成带签名的临时 URL
        return generatePresignedUrl(fileName, props.presignExpirationMinutes());
    }
}
