package com.stylesmile.chat.entity;

import com.fasterxml.jackson.annotation.JsonProperty;
import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Data;

import java.util.Date;

/**
 * App 版本更新实体，对应 chat_app_version 表。
 *
 * 每个平台（android/ios/desktop）一行，App 启动时通过 /chat/app/version 拉取，
 * 与本地版本比较后决定是否弹窗提示更新。
 */
@Data
@Schema(description = "App版本更新实体")
public class ChatAppVersion {

    @Schema(description = "主键ID")
    private Long id;

    /** 平台：android/ios/desktop（macos/window） */
    @JsonProperty("appType")
    @Schema(description = "平台：android/ios/desktop", example = "android")
    private String appType;

    /** 版本号，如 2.1.0；前端做语义化字符串比较 */
    @Schema(description = "版本号，如 2.1.0", example = "2.1.0")
    private String version;

    /** 下载/跳转地址，前端打开浏览器访问 */
    @JsonProperty("downloadUrl")
    @Schema(description = "下载/跳转地址（打开浏览器访问）")
    private String downloadUrl;

    /** 更新说明文案 */
    @JsonProperty("updateMessage")
    @Schema(description = "更新说明文案")
    private String updateMessage;

    /** 是否提示更新：1=提示 0=不提示 */
    @JsonProperty("isNotify")
    @Schema(description = "是否提示更新：1=提示 0=不提示", example = "1")
    private Integer isNotify;

    @Schema(description = "创建时间")
    private Date createTime;

    @Schema(description = "更新时间")
    private Date updateTime;
}