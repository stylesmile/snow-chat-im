package com.stylesmile.chat.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.stylesmile.chat.entity.ChatAppVersion;
import org.apache.ibatis.annotations.Mapper;

/**
 * App 版本更新 mapper。
 *
 * 基于 BaseMapper 提供通用的增删改查（这里仅需要查询，无需自定义 SQL），
 * 由 MyBatis-Plus 自动生成 CRUD 方法。
 */
@Mapper
public interface ChatAppVersionMapper extends BaseMapper<ChatAppVersion> {
}