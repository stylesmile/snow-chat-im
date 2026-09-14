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
     * <p>注意第 4 个参数是<b>偏移量</b>而不是页码：XML 里写的是
     * {@code LIMIT #{offset}, #{size}}，调用方需自己算 {@code (page - 1) * size}。
     * 参数名必须与 XML 占位符一致，否则运行时报
     * {@code BindingException: Parameter 'offset' not found}。
     *
     * @param userId     用户ID
     * @param targetId   目标ID
     * @param targetType 目标类型
     * @param offset     偏移量（(page - 1) * size）
     * @param size       每页大小
     * @return 消息列表
     */
    List<ChatMessage> getHistoryMessages(@Param("userId") Long userId,
                                         @Param("targetId") Long targetId,
                                         @Param("targetType") String targetType,
                                         @Param("offset") int offset,
                                         @Param("size") int size);
}
