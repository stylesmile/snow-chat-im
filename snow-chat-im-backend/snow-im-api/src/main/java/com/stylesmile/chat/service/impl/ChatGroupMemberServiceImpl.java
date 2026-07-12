package com.stylesmile.chat.service.impl;

import com.stylesmile.common.service.BaseServiceImpl;
import com.stylesmile.chat.entity.ChatGroupMember;
import com.stylesmile.chat.mapper.ChatGroupMemberMapper;
import com.stylesmile.chat.service.ChatGroupMemberService;
import org.springframework.stereotype.Service;

import java.util.Date;
import java.util.List;

/**
 * 群组成员服务实现
 *
 * @author chenye
 * @date 2018/12/10
 */
@Service
public class ChatGroupMemberServiceImpl extends BaseServiceImpl<ChatGroupMemberMapper, ChatGroupMember> implements ChatGroupMemberService {

    @Override
    public List<ChatGroupMember> getMembersByGroupId(Integer groupId) {
        return baseMapper.getMembersByGroupId(groupId);
    }

    @Override
    public void addMember(Integer groupId, Integer userId) {
        ChatGroupMember member = new ChatGroupMember();
        member.setGroupId(groupId);
        member.setUserId(userId);
        member.setRole("member");
        member.setJoinTime(new Date());
        member.setMute(0);
        save(member);
    }

    @Override
    public void removeMember(Integer groupId, Integer userId) {
        remove(lambdaQuery()
                .eq(ChatGroupMember::getGroupId, groupId)
                .eq(ChatGroupMember::getUserId, userId)
                .getWrapper());
    }

    @Override
    public boolean isMember(Integer groupId, Integer userId) {
        return lambdaQuery()
                .eq(ChatGroupMember::getGroupId, groupId)
                .eq(ChatGroupMember::getUserId, userId)
                .exists();
    }
}
