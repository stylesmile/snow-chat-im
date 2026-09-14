package com.stylesmile.chat.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.stylesmile.chat.entity.ChatMessage;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

import java.util.List;

/**
 * 消息 mapper
 *
 * @author chenye
 * @date 2018/12/10
 */
@Mapper
public interface ChatMessageMapper extends BaseMapper<ChatMessage> {

    /**
     * 查询历史消息
     *
     * @param userId     用户ID
     * @param targetId   目标ID
     * @param targetType 目标类型
     * @param page       页码
     * @param size       每页大小
     * @return 消息列表
     */
    List<ChatMessage> getHistoryMessages(@Param("userId") Long userId,
                                         @Param("targetId") Long targetId,
                                         @Param("targetType") String targetType,
                                         @Param("page") int page,
                                         @Param("size") int size);
}
