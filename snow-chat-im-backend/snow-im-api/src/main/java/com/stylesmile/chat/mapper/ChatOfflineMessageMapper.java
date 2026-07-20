package com.stylesmile.chat.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.stylesmile.chat.entity.ChatOfflineMessage;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

import java.util.List;

/**
 * 离线消息 Mapper
 */
@Mapper
public interface ChatOfflineMessageMapper extends BaseMapper<ChatOfflineMessage> {

    /**
     * 查询接收方的离线消息
     */
    List<ChatOfflineMessage> findByToUserId(@Param("toUserId") Integer toUserId);

    /**
     * 删除接收方的离线消息
     */
    void deleteByToUserId(@Param("toUserId") Integer toUserId);
}
