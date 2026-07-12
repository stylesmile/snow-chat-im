package com.stylesmile.chat.service.impl;

import com.stylesmile.common.service.BaseServiceImpl;
import com.stylesmile.chat.entity.ChatGroup;
import com.stylesmile.chat.mapper.ChatGroupMapper;
import com.stylesmile.chat.service.ChatGroupMemberService;
import com.stylesmile.chat.service.ChatGroupService;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import javax.annotation.Resource;
import java.util.Date;
import java.util.List;

/**
 * 群组服务实现
 *
 * @author chenye
 * @date 2018/12/10
 */
@Service
public class ChatGroupServiceImpl extends BaseServiceImpl<ChatGroupMapper, ChatGroup> implements ChatGroupService {

    @Resource
    private ChatGroupMemberService chatGroupMemberService;

    @Override
    public ChatGroup getGroupById(Integer groupId) {
        return getById(groupId);
    }

    @Override
    public List<ChatGroup> getGroupsByUserId(Integer userId) {
        return baseMapper.getGroupsByUserId(userId);
    }

    @Override
    @Transactional
    public Integer createGroup(Integer ownerId, String name, String avatar, Integer maxMembers, List<Integer> memberIds) {
        ChatGroup group = new ChatGroup();
        group.setOwnerId(ownerId);
        group.setName(name);
        group.setAvatar(avatar);
        group.setMaxMembers(maxMembers != null ? maxMembers : 500);
        group.setDelFlag(0);
        group.setCreateTime(new Date());
        group.setUpdateTime(new Date());
        save(group);

        if (memberIds != null) {
            for (Integer memberId : memberIds) {
                chatGroupMemberService.addMember(group.getId(), memberId);
            }
        }
        return group.getId();
    }
}
