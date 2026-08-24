package com.stylesmile.chat.storage;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import okhttp3.MediaType;
import okhttp3.MultipartBody;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.RequestBody;
import okhttp3.Response;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.UUID;
import java.util.concurrent.TimeUnit;

/**
 * SeaweedFS 文件存储实现。
 * 当 seaweedfs.enabled=true 时启用，优先级高于 minio.enabled。
 *
 * <p>工作原理：
 * <ul>
 *   <li>上传：向 Master 发起 /volume/{vid}/upload POST 请求，获取返回的 fid（file id）；</li>
 *   <li>公共读（publicRead=true）：直接返回 {@code endpoint/filename} 完整 URL 存入数据库；</li>
 *   <li>私有读（publicRead=false）：返回 fid，调用方通过 generatePresignedUrl 间接访问（暂不支持）。</li>
 * </ul>
 *
 * <p>SeaweedFS REST API 参考：
 * <ul>
 *   <li>上传：{@code POST http://master:8888/volume/{vid}/upload?filename={name}}</li>
 *   <li>访问：{@code GET http://master:8888/{fid}}</li>
 *   <li>删除：{@code DELETE http://master:8888/{fid}}</li>
 * </ul>
 *
 * @author mmm
 * @see FileStorage
 * @see SeaweedfsProperties
 */
@Component
@ConditionalOnProperty(name = "seaweedfs.enabled", havingValue = "true", matchIfMissing = false)
public class SeaweedfsFileStorage implements FileStorage {

    private static final Logger log = LoggerFactory.getLogger(SeaweedfsFileStorage.class); // 日志器

    /** OkHttp 客户端，超时 30 秒，公共读模式无需鉴权 */
    private static final OkHttpClient HTTP_CLIENT = new OkHttpClient.Builder()
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(60, TimeUnit.SECONDS)
            .writeTimeout(30, TimeUnit.SECONDS)
            .build();

    /** JSON 反序列化器，用于解析 SeaweedFS 返回的 JSON 响应 */
    private static final ObjectMapper MAPPER = new ObjectMapper();

    /** 文件 MIME 类型，上传时作为 multipart form-data 的 content-type */
    private static final MediaType MEDIA_TYPE_OCTET = MediaType.parse("application/octet-stream");

    /** SeaweedFS 配置属性 */
    private final SeaweedfsProperties props;

    /**
     * 构造器：注入 SeaweedFS 配置属性。
     *
     * @param props SeaweedFS 配置
     */
    public SeaweedfsFileStorage(SeaweedfsProperties props) {
        this.props = props; // 保存配置属性
    }

    /**
     * 上传文件到 SeaweedFS，返回对象 key（存储到数据库的值）。
     *
     * <p>若 {@code publicRead=true}，返回完整可访问的 URL（如 {@code http://host:8888/avatars/xxx.jpg}）；
     * 否则返回内部 fid 或 key，供后续访问使用。
     *
     * @param inputStream 文件输入流
     * @param fileName    对象 key（如 avatars/uuid.jpg），作为 filename 参数传给 SeaweedFS
     * @param contentType MIME 类型
     * @param fileSize    文件字节数
     * @return 若公共读则为完整 URL，否则为文件名 key
     */
    @Override
    public String upload(InputStream inputStream, String fileName, String contentType, long fileSize) {
        // 公共读模式下，filename 直接用传入的 fileName（保留目录前缀），方便构建访问 URL
        String uploadFilename = fileName;
        // 先读取全部字节（readAllBytes 抛出 IOException，需在 try 内处理）
        byte[] fileBytes;
        try {
            fileBytes = inputStream.readAllBytes();
        } catch (java.io.IOException e) {
            throw new RuntimeException("Failed to read file bytes for SeaweedFS upload", e);
        }
        // 构造上传 URL：http://endpoint/volume/{vid}/upload?filename={name}
        String uploadUrl = props.endpoint().replaceAll("/+$", "")
                + props.uploadPath()
                + "/upload?filename=" + java.net.URLEncoder.encode(uploadFilename, StandardCharsets.UTF_8);
        // 构造 multipart 请求体，字段名固定为 "file"（SeaweedFS 约定）
        RequestBody requestBody = new MultipartBody.Builder()
                .setType(MultipartBody.FORM)
                .addFormDataPart("file", uploadFilename,
                        RequestBody.create(fileBytes, MEDIA_TYPE_OCTET))
                .build();
        // 发送上传请求
        try (Response response = HTTP_CLIENT.newCall(new Request.Builder()
                .url(uploadUrl)
                .post(requestBody)
                .build())
                .execute()) {
            // 检查响应状态码，非 2xx 抛出异常
            if (!response.isSuccessful()) {
                String body = response.body() != null ? response.body().string() : "";
                throw new RuntimeException("SeaweedFS upload failed: HTTP " + response.code() + " body=" + body);
            }
            // 解析响应 JSON，提取 fid 和 publicUrl
            // 公共读模式下响应包含 "publicUrl" 字段，可直接存入数据库
            String responseBody = response.body() != null ? response.body().string() : "";
            JsonNode json = MAPPER.readTree(responseBody);
            // 若响应包含 publicUrl 字段（公共读模式），直接返回完整 URL
            if (json.has("publicUrl") && !json.get("publicUrl").asText().isEmpty()) {
                String fullUrl = json.get("publicUrl").asText();
                log.info("SeaweedFS upload success, publicUrl: {}", fullUrl);
                return fullUrl;
            }
            // 公共读未启用时，返回 fileName 作为 key（generateUrl 会根据 endpoint 拼接）
            log.info("SeaweedFS upload success, fid={}, fileName={}", json.has("fid") ? json.get("fid").asText() : "unknown", fileName);
            return fileName;
        } catch (Exception e) {
            // 上传失败时抛出运行时异常，由上层统一处理
            throw new RuntimeException("Failed to upload file to SeaweedFS: " + e.getMessage(), e);
        }
    }

    /**
     * 从 SeaweedFS 删除文件。
     *
     * <p>公共读模式下通过 fid 删除（从上传响应中解析）；
     * 非公共读模式下 fileName 即为 fid。
     *
     * @param fileName 对象 key 或 fid
     */
    @Override
    public void delete(String fileName) {
        // 构造删除 URL：DELETE http://endpoint/{fid}
        String deleteUrl = props.endpoint().replaceAll("/+$", "") + "/" + fileName;
        try (Response response = HTTP_CLIENT.newCall(new Request.Builder()
                .url(deleteUrl)
                .delete()
                .build())
                .execute()) {
            // 非 2xx 记录警告（不阻断业务）
            if (!response.isSuccessful()) {
                log.warn("SeaweedFS delete failed for {}: HTTP {}", fileName, response.code());
            } else {
                log.info("SeaweedFS file deleted: {}", fileName);
            }
        } catch (Exception e) {
            log.warn("SeaweedFS delete exception for {}: {}", fileName, e.getMessage());
        }
    }

    /**
     * 判断文件是否存在（通过 HEAD 请求探测）。
     *
     * @param fileName 对象 key 或 fid
     * @return 存在返回 true
     */
    @Override
    public boolean exists(String fileName) {
        // 构造 HEAD 请求 URL
        String url = props.endpoint().replaceAll("/+$", "") + "/" + fileName;
        try (Response response = HTTP_CLIENT.newCall(new Request.Builder()
                .url(url)
                .head()
                .build())
                .execute()) {
            // 2xx 表示存在，404 表示不存在
            return response.isSuccessful();
        } catch (Exception e) {
            // 网络异常时认为不存在
            return false;
        }
    }

    /**
     * 生成可直接访问的下载 URL（公共读模式专用）。
     *
     * <p>对于 SeaweedFS 公共读模式，返回 {@code endpoint/filename}，数据库直接存储此 URL。
     * 对于私有模式（publicRead=false），仍可通过此方法获取基础访问地址。
     *
     * @param fileName 对象 key 或 fid
     * @return 完整可访问的 URL 字符串
     */
    @Override
    public String generatePresignedUrl(String fileName, int expirationMinutes) {
        // 公共读模式下，直接返回完整 HTTP URL（无需签名，永久有效）
        // 若 fileName 本身已是完整 URL（公共读上传时返回的 publicUrl），直接返回
        if (fileName.startsWith("http://") || fileName.startsWith("https://")) {
            return fileName;
        }
        // 否则拼接 endpoint + fileName
        String baseUrl = props.publicBaseUrl() != null && !props.publicBaseUrl().isBlank()
                ? props.publicBaseUrl().replaceAll("/+$", "")
                : props.endpoint().replaceAll("/+$", "");
        return baseUrl + "/" + fileName;
    }

    /**
     * 生成公共读的完整访问 URL（供 Service 层在 public-read 存储类型下直接使用）。
     * 与 {@link #generatePresignedUrl} 的区别：此方法不要求 fileName 已含完整 URL，
     * 始终根据 endpoint + fileName 重新拼接，保证 URL 格式正确。
     *
     * @param fileName 对象 key（如 avatars/uuid.jpg）
     * @return 完整可访问的 URL
     */
    public String generateUrl(String fileName) {
        // 若 fileName 已是完整 URL，直接返回（避免重复拼接）
        if (fileName.startsWith("http://") || fileName.startsWith("https://")) {
            return fileName;
        }
        // 使用配置的 publicBaseUrl（若有）或 endpoint 作为基础地址
        String baseUrl = props.publicBaseUrl() != null && !props.publicBaseUrl().isBlank()
                ? props.publicBaseUrl().replaceAll("/+$", "")
                : props.endpoint().replaceAll("/+$", "");
        // 拼接文件路径，确保单斜杠分隔
        return baseUrl + "/" + fileName.replaceAll("^/+", "");
    }
}
