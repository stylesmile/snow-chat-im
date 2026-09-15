package com.stylesmile.chat.controller;

import com.stylesmile.chat.dto.UploadResult;
import com.stylesmile.chat.service.FileStorageService;
import com.stylesmile.common.util.Result;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import io.swagger.v3.oas.annotations.media.Schema;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import jakarta.servlet.http.HttpServletRequest;

import org.springframework.core.io.InputStreamResource;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;

import javax.annotation.Resource;
import java.io.InputStream;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.util.Locale;
import java.util.Set;
import java.util.regex.Pattern;

/**
 * 文件上传控制器
 *
 * 提供三类上传接口：
 * - POST /file/upload：通用文件上传
 * - POST /file/avatar：头像专用上传
 * - POST /file/media/{type}：媒体/附件专用上传
 */
@RestController
@RequestMapping("/file")
@Tag(name = "文件管理", description = "文件上传、头像上传、媒体文件上传接口")
public class FileController {

    /**
     * 媒体类型白名单：image / video / file / voice
     */
    private static final Set<String> ALLOWED_MEDIA_TYPES = Set.of("image", "video", "file", "voice");

    /**
     * 允许通过 /file/raw/** 下载的对象 key 白名单。
     *
     * <p>只放行五大业务目录，且文件名只允许字母数字与 . _ -，
     * 从入口处阻断 {@code ..} 之类的路径穿越与目录探测。
     *
     * <p>中间的日期目录 {@code (?:\\d{4}/\\d{2}/\\d{2}/)?} 是可选的：聊天媒体文件的 key 形如
     * {@code images/2026/09/14/uuid.jpg}（见 {@code FileStorageServiceImpl} 的日期分层），
     * 头像与历史数据仍是一层 {@code avatars/uuid.jpg}。这里刻意只认"纯数字日期"这一种
     * 多级目录，不写成"任意目录段"，否则 {@code images/../../etc/passwd} 会被放行。
     */
    private static final Pattern RAW_KEY_PATTERN =
            Pattern.compile("^(avatars|images|videos|files|voices)/(?:\\d{4}/\\d{2}/\\d{2}/)?[A-Za-z0-9._-]+$");

    /**
     * 判断对象 key 是否允许通过 {@code /file/raw/**} 下载（供单测直接校验白名单）。
     *
     * @param key 解码后的对象 key
     * @return 允许下载返回 true
     */
    static boolean isRawKeyAllowed(String key) {
        return key != null && RAW_KEY_PATTERN.matcher(key).matches();
    }

    @Resource
    private FileStorageService fileStorageService;

    /**
     * 读取文件内容（本地磁盘存储 {@code storage.type=disk} 的下载端点）。
     *
     * <p>上传接口返回的地址形如 {@code {disk.public-url}/file/raw/images/uuid.jpg}，
     * 前端（含真机）直接用它加载图片/视频/语音，因此这里必须能匿名访问，
     * 故未纳入 AuthFilter 的 /chat/* 拦截范围。
     *
     * @param request 用于取出 {@code /raw/} 之后的对象 key
     * @return 文件字节流；key 非法或文件不存在时返回 404
     */
    @Operation(summary = "读取文件", description = "按对象 key 返回文件内容（本地磁盘存储模式）")
    @ApiResponse(responseCode = "200", description = "文件存在")
    @ApiResponse(responseCode = "404", description = "key 非法或文件不存在")
    @GetMapping("/raw/**")
    public ResponseEntity<InputStreamResource> raw(
            @Parameter(hidden = true) HttpServletRequest request) {
        // 取 /file/raw/ 之后的完整路径并做 URL 解码。
        //
        // 这里不用 HandlerMapping.PATH_WITHIN_HANDLER_MAPPING_ATTRIBUTE：该属性只在
        // 部分 HandlerMapping 实现下才被填充，实测 Spring Boot 3.5 的
        // RequestMappingHandlerMapping 取到 null，导致所有下载一律 404。
        // 直接按请求 URI 定位 /raw/ 更稳妥，且与 servlet 上下文路径无关。
        String uri = request.getRequestURI();
        String path = uri.startsWith(request.getContextPath())
                ? uri.substring(request.getContextPath().length())
                : uri;
        int rawIndex = path.indexOf("/raw/");
        if (rawIndex < 0) {
            return ResponseEntity.notFound().build();
        }
        String key = URLDecoder.decode(
                path.substring(rawIndex + "/raw/".length()), StandardCharsets.UTF_8);
        // 白名单校验：只放行业务目录（可含一级日期目录）+ 安全文件名
        if (!isRawKeyAllowed(key)) {
            return ResponseEntity.notFound().build();
        }
        // 读取字节流（对象存储实现返回 null，本端点仅服务本地磁盘存储）
        InputStream stream = fileStorageService.load(key);
        if (stream == null) {
            return ResponseEntity.notFound().build();
        }
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType(inferContentType(key)))
                .body(new InputStreamResource(stream));
    }

    /**
     * 按文件扩展名推断 Content-Type，未知类型回退 application/octet-stream。
     *
     * @param key 对象 key
     * @return MIME 类型字符串
     */
    private static String inferContentType(String key) {
        int dot = key.lastIndexOf('.');
        if (dot < 0) {
            return MediaType.APPLICATION_OCTET_STREAM_VALUE;
        }
        String ext = key.substring(dot + 1).toLowerCase(Locale.ROOT);
        return switch (ext) {
            case "jpg", "jpeg" -> "image/jpeg";
            case "png" -> "image/png";
            case "gif" -> "image/gif";
            case "webp" -> "image/webp";
            case "mp4" -> "video/mp4";
            case "mov" -> "video/quicktime";
            case "m4a" -> "audio/mp4";
            case "mp3" -> "audio/mpeg";
            case "wav" -> "audio/wav";
            case "aac" -> "audio/aac";
            default -> MediaType.APPLICATION_OCTET_STREAM_VALUE;
        };
    }

    /**
     * 通用文件上传
     */
    @Operation(summary = "通用文件上传", description = "上传任意文件，返回key和预签名URL")
    @ApiResponse(responseCode = "200", description = "上传成功")
    @ApiResponse(responseCode = "400", description = "空文件")
    @PostMapping("/upload")
    public Result<UploadResult> upload(
            @Parameter(description = "上传的文件", required = true)
            @RequestParam("file") MultipartFile file) {
        if (file == null || file.isEmpty()) {
            return Result.fail();
        }
        UploadResult uploadResult = fileStorageService.uploadAndSign(file);
        return Result.success(uploadResult);
    }

    /**
     * 上传用户头像
     */
    @Operation(summary = "上传用户头像", description = "上传头像到avatars/目录，返回key和URL")
    @ApiResponse(responseCode = "200", description = "上传成功")
    @ApiResponse(responseCode = "400", description = "空文件")
    @PostMapping("/avatar")
    public Result<UploadResult> uploadAvatar(
            @Parameter(description = "头像文件", required = true)
            @RequestParam("file") MultipartFile file) {
        if (file == null || file.isEmpty()) {
            return Result.fail();
        }
        UploadResult uploadResult = fileStorageService.uploadAndSign(file);
        return Result.success(uploadResult);
    }

    /**
     * 上传媒体/附件文件
     */
    @Operation(summary = "上传媒体文件", description = "按类型上传媒体文件到images/videos/files/目录")
    @ApiResponse(responseCode = "200", description = "上传成功")
    @ApiResponse(responseCode = "400", description = "空文件或非法type")
    @PostMapping("/media/{type}")
    public Result<UploadResult> uploadMedia(
            @Parameter(description = "媒体类型：image/video/file/voice", required = true, example = "image")
            @PathVariable String type,
            @Parameter(description = "上传的文件", required = true)
            @RequestParam("file") MultipartFile file) {
        if (!ALLOWED_MEDIA_TYPES.contains(type)) {
            return Result.failMessage("非法的媒体类型，只允许 image/video/file/voice");
        }
        if (file == null || file.isEmpty()) {
            return Result.fail();
        }
        String mediaType = type + "s";
        UploadResult uploadResult = fileStorageService.uploadAndSign(file, mediaType);
        return Result.success(uploadResult);
    }
}
