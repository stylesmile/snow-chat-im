package com.stylesmile.chat.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.stylesmile.chat.entity.ChatMessageRoute;
import org.apache.ibatis.annotations.Mapper;

/**
 * 消息分片路由 mapper（对应 {@code chat_message_route}）。
 *
 * <p>只有单表（不分片），直接用 MyBatis-Plus 的 {@link BaseMapper} 即可。
 *
 * @author mmm
 */
@Mapper
public interface ChatMessageRouteMapper extends BaseMapper<ChatMessageRoute> {
}
