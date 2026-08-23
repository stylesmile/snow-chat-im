package com.stylesmile.chat.controller;

import com.stylesmile.chat.dto.UploadResult;
import com.stylesmile.chat.service.FileStorageService;
import com.stylesmile.common.util.Result;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import javax.annotation.Resource;
import java.util.Set;

/**
 * 文件上传控制器。
 *
 * <p>提供三类上传接口：
 * <ul>
 *   <li>{@code POST /file/upload}：通用文件上传，返回 {@code {key, url}}；</li>
 *   <li>{@code POST /file/avatar}：头像专用上传，自动写入 {@code avatars/} 目录，
 *       返回 {@code {key, url}} 供前端立即展示；</li>
 *   <li>{@code POST /file/media/{type}}：媒体/附件专用上传，按 type 写入
 *       {@code images/}/{@code videos/}/{@code files/} 子目录，
 *       返回 {@code {key, url}} 可直接用作消息 content。</li>
 * </ul>
 *
 * @author mmm
 * @see FileStorageService
 * @see UploadResult
 */
@RestController
@RequestMapping("/file")
public class FileController {

    /**
     * 媒体类型白名单：image / video / file。
     * 用于校验路径变量 {@code {type}}，防止非法路径触发任意目录写入。
     */
    private static final Set<String> ALLOWED_MEDIA_TYPES = Set.of("image", "video", "file");

    /**
     * 文件存储服务：负责上传与 pre-signed URL 生成。
     * 使用 @Resource 注入（与项目其他 Controller 风格一致）。
     */
    @Resource
    private FileStorageService fileStorageService;

    /**
     * 通用文件上传（不绑定用户，返回 key 和预签名 URL）。
     *
     * @param file multipart 文件，表单字段名 {@code file}
     * @return 成功：{@code Result.success(UploadResult)}，code=200；
     *         失败（空文件）：{@code Result.fail()}，code=500，data=null
     */
    @PostMapping("/upload")
    public Result<UploadResult> upload(@RequestParam("file") MultipartFile file) {
        // 校验：空文件直接返回失败（避免无谓的上传调用）
        if (file == null || file.isEmpty()) {
            return Result.fail();
        }
        // 委托 service 完成上传与签名，包装成成功结果返回
        UploadResult uploadResult = fileStorageService.uploadAndSign(file);
        return Result.success(uploadResult);
    }

    /**
     * 上传用户头像（独立接口，自动存入 avatars/ 目录）。
     *
     * <p>与 {@link #upload} 的区别：
     * <ul>
     *   <li>文件名自动替换为 {@code avatars/{uuid}.{ext}} 格式，确保头像统一存储路径；</li>
     *   <li>前端可直接使用返回的 {@code url} 作为头像展示地址。</li>
     * </ul>
     *
     * @param file multipart 头像文件，表单字段名 {@code file}
     * @return 成功：{@code Result.success(UploadResult)}，code=200；
     *         失败（空文件）：{@code Result.fail()}，code=500，data=null
     */
    @PostMapping("/avatar")
    public Result<UploadResult> uploadAvatar(@RequestParam("file") MultipartFile file) {
        // 校验：空文件直接返回失败
        if (file == null || file.isEmpty()) {
            return Result.fail();
        }
        // 复用通用上传逻辑（内部会按原始文件名生成 avatars/{uuid}.{ext}）
        UploadResult uploadResult = fileStorageService.uploadAndSign(file);
        return Result.success(uploadResult);
    }

    /**
     * 上传媒体/附件文件（按类型分目录：images/、videos/、files/）。
     *
     * <p>本接口专门为聊天消息场景设计：
     * <ul>
     *   <li>{@code type=image}：图片消息，存入 {@code images/} 目录；</li>
     *   <li>{@code type=video}：视频消息，存入 {@code videos/} 目录；</li>
     *   <li>{@code type=file}：通用文件（文档、压缩包等），存入 {@code files/} 目录。</li>
     * </ul>
     * 前端上传成功后用返回的 {@code url} 作为消息 content，{@code type} 字段与之一一对应。
     *
     * @param type   媒体类型，必须是 {@code image} / {@code video} / {@code file} 之一
     * @param file   multipart 文件，表单字段名 {@code file}
     * @return 成功：{@code Result.success(UploadResult)}，code=200；
     *         失败（空文件 / 非法 type）：{@code Result.fail()}，code=500
     */
    @PostMapping("/media/{type}")
    public Result<UploadResult> uploadMedia(
            @PathVariable String type,
            @RequestParam("file") MultipartFile file) {
        // 安全校验：type 必须是白名单之一，防止路径穿越或非法目录写入
        if (!ALLOWED_MEDIA_TYPES.contains(type)) {
            return Result.failMessage("非法的媒体类型，只允许 image/video/file");
        }
        // 校验：空文件直接返回失败
        if (file == null || file.isEmpty()) {
            return Result.fail();
        }
        // 复用通用上传逻辑（内部会自动改为 {type}/{uuid}.{ext} 格式）
        // 通过重载 uploadAndSign 以 mediaType 参数支持动态目录前缀
        UploadResult uploadResult = fileStorageService.uploadAndSign(file, type);
        return Result.success(uploadResult);
    }
}
