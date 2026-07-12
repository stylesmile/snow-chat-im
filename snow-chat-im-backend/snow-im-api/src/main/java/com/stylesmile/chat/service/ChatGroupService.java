package com.stylesmile.chat.service;

import com.stylesmile.common.service.BaseService;
import com.stylesmile.chat.entity.ChatGroup;

import java.util.List;

/**
 * 群组服务
 *
 * @author chenye
 * @date 2018/12/10
 */
public interface ChatGroupService extends BaseService<ChatGroup> {

    /**
     * 查询群组详情
     *
     * @param groupId 群组ID
     * @return 群组
     */
    ChatGroup getGroupById(Integer groupId);

    /**
     * 查询用户所在的群组列表
     *
     * @param userId 用户ID
     * @return 群组列表
     */
    List<ChatGroup> getGroupsByUserId(Integer userId);

    /**
     * 创建群组
     *
     * @param ownerId    群主ID
     * @param name       群名称
     * @param avatar     群头像
     * @param maxMembers 最大成员数
     * @param memberIds  初始成员ID列表
     * @return 群组ID
     */
    Integer createGroup(Integer ownerId, String name, String avatar, Integer maxMembers, List<Integer> memberIds);
}
