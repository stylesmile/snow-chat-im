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

import javax.annotation.Resource;
import java.util.Set;

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

    @Resource
    private FileStorageService fileStorageService;

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
