package com.stylesmile.chat.service;

import com.stylesmile.common.service.BaseService;
import com.stylesmile.chat.entity.ChatGroupMember;

import java.util.List;

/**
 * 群组成员服务
 *
 * @author chenye
 * @date 2018/12/10
 */
public interface ChatGroupMemberService extends BaseService<ChatGroupMember> {

    /**
     * 查询群组成员列表
     *
     * @param groupId 群组ID
     * @return 成员列表
     */
    List<ChatGroupMember> getMembersByGroupId(Integer groupId);

    /**
     * 添加群组成员
     *
     * @param groupId 群组ID
     * @param userId  用户ID
     */
    void addMember(Integer groupId, Integer userId);

    /**
     * 移除群组成员
     *
     * @param groupId 群组ID
     * @param userId  用户ID
     */
    void removeMember(Integer groupId, Integer userId);

    /**
     * 判断用户是否在群组中
     *
     * @param groupId 群组ID
     * @param userId  用户ID
     * @return true-在群组中, false-不在群组中
     */
    boolean isMember(Integer groupId, Integer userId);
}
