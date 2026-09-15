package com.stylesmile.chat.controller;

import com.stylesmile.chat.entity.ChatAppVersion;
import com.stylesmile.chat.service.ChatAppVersionService;
import com.stylesmile.common.util.Result;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import javax.annotation.Resource;

/**
 * App 版本更新控制器。
 *
 * <p>App 每次启动调用本接口检查是否有可提示的更新版本；返回的实体中
 * downloadUrl 供前端「立即更新」时在浏览器打开。
 */
@RestController
@RequestMapping("/chat/app")
@Tag(name = "App版本更新", description = "App启动时检查版本更新")
public class ChatAppVersionController {

    @Resource
    private ChatAppVersionService chatAppVersionService;

    /**
     * 获取应提示更新的最新版本。
     */
    @Operation(summary = "获取最新可提示版本", description = "返回最新且开启提示的版本记录；无更新时不返回或返回同版本")
    @ApiResponse(responseCode = "200", description = "查询成功")
    @GetMapping("/version")
    // appType 可选：传参则限定平台，不传则返回全局最新一条
    public Result<ChatAppVersion> version(
            @Parameter(description = "平台：android/ios/desktop，可空")
            @RequestParam(required = false) String appType) {
        return Result.success(chatAppVersionService.getNotifyVersion(appType));
    }
}