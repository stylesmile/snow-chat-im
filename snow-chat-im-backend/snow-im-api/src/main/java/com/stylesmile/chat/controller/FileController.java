package com.stylesmile.chat.controller;

import com.stylesmile.chat.dto.UploadResult;
import com.stylesmile.chat.service.FileStorageService;
import com.stylesmile.common.util.Result;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import javax.annotation.Resource;

/**
 * 文件上传控制器。
 *
 * <p>提供两类上传接口：
 * <ul>
 *   <li>{@code POST /file/upload}：通用文件上传，返回 {@code {key, url}}；</li>
 *   <li>{@code POST /file/avatar}：头像专用上传，自动写入 {@code avatars/} 目录，
 *       返回 {@code {key, url}} 供前端立即展示。</li>
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
}
