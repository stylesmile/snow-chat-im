package com.stylesmile.chat.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.stylesmile.chat.entity.ChatAppVersion;
import org.apache.ibatis.annotations.Mapper;

/**
 * App 版本更新 mapper。
 *
 * <p>普通单表查询走 MyBatis-Plus BaseMapper 即可满足（取最新一条、按平台过滤，
 * 均可由 LambdaQueryWrapper 完成），无需自定义 SQL。
 */
@Mapper
public interface ChatAppVersionMapper extends BaseMapper<ChatAppVersion> {
}