package com.stylesmile.chat.controller;

import com.stylesmile.chat.dto.UploadResult;
import com.stylesmile.chat.service.FileStorageService;
import com.stylesmile.common.util.Result;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import javax.annotation.Resource;

/**
 * 文件上传控制器。
 *
 * <p>暴露 {@code POST /file/upload} multipart 接口，
 * 供前端上传头像等文件，返回 {@code {key, url}} 供前端使用。
 *
 * <p>典型场景：前端选择图片 → 上传到本接口 → 拿到 {@link UploadResult#key()} 与 {@link UploadResult#url()} →
 * 调用 {@code PUT /chat/user/profile} 把 key 存入用户头像字段 → 前端用 url 立即展示。
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
     * 上传文件并返回 key 与 pre-signed URL。
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
}
