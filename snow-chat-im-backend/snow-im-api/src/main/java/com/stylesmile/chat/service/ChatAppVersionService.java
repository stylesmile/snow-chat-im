package com.stylesmile.chat.service;

import com.stylesmile.chat.entity.ChatAppVersion;

/**
 * App 版本更新服务。
 */
public interface ChatAppVersionService {

    /**
     * 获取应提示更新的最新版本记录。
     *
     * @param appType 平台（android/ios/desktop）；为空则不限定平台，返回最新一条
     * @return 最新且 isNotify=1 的版本记录；无匹配时返回 null
     */
    ChatAppVersion getNotifyVersion(String appType);
}