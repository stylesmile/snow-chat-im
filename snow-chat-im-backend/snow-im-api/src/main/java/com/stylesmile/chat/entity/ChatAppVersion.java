package com.stylesmile.chat.entity;

import com.fasterxml.jackson.annotation.JsonProperty;
import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Data;

/**
 * App 版本更新实体。
 *
 * <p>对应数据库表 chat_app_version。前端每次启动调用接口取最新一条，
 * 用语义化版本字符串与本地当前版本比较，若服务端更新且 isNotify 为真
 * 则弹窗提示，用户点击后在浏览器打开 downloadUrl。
 */
@Data
@Schema(description = "App版本更新实体")
public class ChatAppVersion {
    @Schema(description = "主键ID")
    private Long id;
    @Schema(description = "平台：android/ios/desktop")
    @JsonProperty("appType")
    private String appType;
    @Schema(description = "版本号，如 2.1.0")
    private String version;
    @Schema(description = "下载/跳转地址")
    @JsonProperty("downloadUrl")
    private String downloadUrl;
    @Schema(description = "更新说明")
    @JsonProperty("updateMessage")
    private String updateMessage;
    @Schema(description = "是否提示更新：1=提示 0=不提示")
    @JsonProperty("isNotify")
    private Integer isNotify;
    @Schema(description = "创建时间")
    private java.util.Date createTime;
    @Schema(description = "更新时间")
    private java.util.Date updateTime;

    public ChatAppVersion() {
    }
}