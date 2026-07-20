package com.stylesmile.chat.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.stylesmile.chat.entity.ChatGroup;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

import java.util.List;

/**
 * 群组 mapper
 *
 * @author chenye
 * @date 2018/12/10
 */
@Mapper
public interface ChatGroupMapper extends BaseMapper<ChatGroup> {

    /**
     * 查询用户所在的群组
     *
     * @param userId 用户ID
     * @return 群组列表
     */
    List<ChatGroup> getGroupsByUserId(@Param("userId") Long userId);
}
