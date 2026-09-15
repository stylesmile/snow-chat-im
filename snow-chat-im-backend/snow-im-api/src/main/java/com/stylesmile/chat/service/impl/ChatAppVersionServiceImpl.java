package com.stylesmile.chat.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.stylesmile.chat.entity.ChatAppVersion;
import com.stylesmile.chat.mapper.ChatAppVersionMapper;
import com.stylesmile.chat.service.ChatAppVersionService;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

import javax.annotation.Resource;

/**
 * App 版本更新服务实现。
 *
 * <p>版本记录按 id 倒序取最新一条（管理员维护时以插入/更新顺序为准），
 * 仅返回 isNotify=1（开启提示）的记录，避免把已下线的版本提示给用户。
 */
@Service
public class ChatAppVersionServiceImpl implements ChatAppVersionService {

    @Resource
    private ChatAppVersionMapper chatAppVersionMapper;

    @Override
    public ChatAppVersion getNotifyVersion(String appType) {
        // 条件1：仅返回开启提示更新的记录
        LambdaQueryWrapper<ChatAppVersion> query = new LambdaQueryWrapper<>();
        query.eq(ChatAppVersion::getIsNotify, 1);
        // 条件2：指定了平台则同时限定 app_type；否则取全局最新
        if (StringUtils.hasText(appType)) {
            query.eq(ChatAppVersion::getAppType, appType);
        }
        // 取最新一条：按 id 倒序并限制返回 1 行
        query.orderByDesc(ChatAppVersion::getId).last("limit 1");
        return chatAppVersionMapper.selectOne(query);
    }
}