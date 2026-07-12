package com.stylesmile.chat.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.stylesmile.chat.entity.ChatGroupMember;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

import java.util.List;

/**
 * 群组成员 mapper
 *
 * @author chenye
 * @date 2018/12/10
 */
@Mapper
public interface ChatGroupMemberMapper extends BaseMapper<ChatGroupMember> {

    /**
     * 查询群组成员
     *
     * @param groupId 群组ID
     * @return 成员列表
     */
    List<ChatGroupMember> getMembersByGroupId(@Param("groupId") Integer groupId);
}
