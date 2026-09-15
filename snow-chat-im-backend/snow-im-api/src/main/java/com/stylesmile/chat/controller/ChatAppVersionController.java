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
 * 该接口为匿名接口（见 AuthFilter 白名单），App 每次启动无需登录即可调用，
 * 返回当前应提示的最新版本；前端与本地版本比较后决定是否弹窗。
 */
@RestController
@RequestMapping("/chat/app")
@Tag(name = "App版本更新", description = "App 启动时检查版本更新")
public class ChatAppVersionController {

    @Resource
    private ChatAppVersionService chatAppVersionService;

    /**
     * 获取指定平台「应提示」的最新版本；无提示记录时返回 data=null。
     */
    @Operation(summary = "获取最新可提示版本", description = "返回最新且开启提示的版本记录；无更新时 data 为 null")
    @ApiResponse(responseCode = "200", description = "查询成功")
    @GetMapping("/version")
    public Result<ChatAppVersion> version(
            @Parameter(description = "平台：android/ios/desktop，可空")
            @RequestParam(required = false) String appType) {
        return Result.success(chatAppVersionService.getNotifyVersion(appType));
    }
}