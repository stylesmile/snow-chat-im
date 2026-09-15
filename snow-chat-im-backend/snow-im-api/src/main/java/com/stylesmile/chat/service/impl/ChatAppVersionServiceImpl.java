package com.stylesmile.chat.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.stylesmile.chat.entity.ChatAppVersion;
import com.stylesmile.chat.mapper.ChatAppVersionMapper;
import com.stylesmile.chat.service.ChatAppVersionService;
import com.stylesmile.common.service.BaseServiceImpl;
import org.springframework.stereotype.Service;

/**
 * App 版本更新服务实现。
 *
 * 注意：这里刻意使用字符串列名的 {@link QueryWrapper}（而非 {@code LambdaQueryWrapper}），
 * 目的是让 getNotifyVersion 能被纯 Mockito 单元测试覆盖——字符串列名无需 MyBatis-Plus
 * 的 lambda cache 就能构造 wrapper，进而可以 mock mapper.selectOne 验证行为。
 */
@Service
public class ChatAppVersionServiceImpl extends BaseServiceImpl<ChatAppVersionMapper, ChatAppVersion>
        implements ChatAppVersionService {

    /**
     * 查询指定平台「应提示更新」的最新版本记录。
     *
     * 过滤条件：
     * 1. is_notify = 1（仅返回开启提示的平台记录）
     * 2. 若传入 appType，则限定平台；否则取任意平台的最新一条
     * 3. 按 id 倒序取最新（同一平台通常只维护一条，多条时取 id 最大者）
     */
    @Override
    public ChatAppVersion getNotifyVersion(String appType) {
        // 构造查询条件：只取「开启了提示」的记录
        QueryWrapper<ChatAppVersion> wrapper = new QueryWrapper<>();
        wrapper.eq("is_notify", 1);

        // 平台不为空时精确匹配平台；为空时不做平台限制
        if (appType != null && !appType.isBlank()) {
            wrapper.eq("app_type", appType);
        }

        // 取最新一条（id 为自增主键，越大越新）
        wrapper.orderByDesc("id");
        wrapper.last("LIMIT 1");

        // 单条查询，没有开启提示的记录时返回 null
        return baseMapper.selectOne(wrapper);
    }
}