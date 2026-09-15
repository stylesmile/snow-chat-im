package com.stylesmile.chat.service;

import com.stylesmile.chat.entity.ChatAppVersion;
import com.stylesmile.common.service.BaseService;

/**
 * App 版本更新服务。
 */
public interface ChatAppVersionService extends BaseService<ChatAppVersion> {

    /**
     * 查询指定平台「应提示更新」的最新版本记录。
     *
     * @param appType 平台：android/ios/desktop；为空时查询任意平台的最新一条
     * @return 版本记录；没有开启提示的记录时返回 null
     */
    ChatAppVersion getNotifyVersion(String appType);
}