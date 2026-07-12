package com.stylesmile.chat.controller;

import com.stylesmile.common.util.Result;
import com.stylesmile.chat.entity.ChatGroup;
import com.stylesmile.chat.entity.ChatGroupMember;
import com.stylesmile.chat.service.ChatGroupMemberService;
import com.stylesmile.chat.service.ChatGroupService;
import org.springframework.web.bind.annotation.*;

import javax.annotation.Resource;
import java.util.Arrays;
import java.util.List;

/**
 * 群组控制器
 *
 * @author chenye
 * @date 2018/12/10
 */
@RestController
@RequestMapping("/chat/group")
public class ChatGroupController {

    @Resource
    private ChatGroupService chatGroupService;

    @Resource
    private ChatGroupMemberService chatGroupMemberService;

    /**
     * 创建群组
     *
     * @param body 包含ownerId, name, avatar, maxMembers, memberIds
     * @return Result
     */
    @PostMapping("/create")
    public Result<Integer> create(@RequestBody GroupCreateDTO body) {
        List<Integer> memberIds = body.getMemberIds() != null
                ? Arrays.stream(body.getMemberIds().split(","))
                .map(String::trim)
                .map(Integer::valueOf)
                .toList()
                : null;
        Integer groupId = chatGroupService.createGroup(
                body.getOwnerId(),
                body.getName(),
                body.getAvatar(),
                body.getMaxMembers(),
                memberIds
        );
        return Result.success(groupId);
    }

    /**
     * 获取群组信息
     *
     * @param groupId 群组ID
     * @return Result
     */
    @GetMapping("/{groupId}")
    public Result<ChatGroup> getGroup(@PathVariable Integer groupId) {
        ChatGroup group = chatGroupService.getGroupById(groupId);
        return Result.success(group);
    }

    /**
     * 获取用户所在群组列表
     *
     * @param userId 用户ID
     * @return Result
     */
    @GetMapping("/list")
    public Result<List<ChatGroup>> list(@RequestParam Integer userId) {
        List<ChatGroup> groups = chatGroupService.getGroupsByUserId(userId);
        return Result.success(groups);
    }

    /**
     * 获取群组成员列表
     *
     * @param groupId 群组ID
     * @return Result
     */
    @GetMapping("/members/{groupId}")
    public Result<List<ChatGroupMember>> getMembers(@PathVariable Integer groupId) {
        List<ChatGroupMember> members = chatGroupMemberService.getMembersByGroupId(groupId);
        return Result.success(members);
    }

    /**
     * 添加群组成员
     *
     * @param body 包含groupId和userIds
     * @return Result
     */
    @PostMapping("/members/add")
    public Result<Void> addMembers(@RequestBody MemberOperationDTO body) {
        for (Integer userId : body.getUserIds()) {
            chatGroupMemberService.addMember(body.getGroupId(), userId);
        }
        return Result.success();
    }

    /**
     * 移除群组成员
     *
     * @param body 包含groupId和userIds
     * @return Result
     */
    @PostMapping("/members/remove")
    public Result<Void> removeMembers(@RequestBody MemberOperationDTO body) {
        for (Integer userId : body.getUserIds()) {
            chatGroupMemberService.removeMember(body.getGroupId(), userId);
        }
        return Result.success();
    }

    /**
     * 创建群组请求DTO
     */
    public static class GroupCreateDTO {
        private Integer ownerId;
        private String name;
        private String avatar;
        private Integer maxMembers;
        private String memberIds;

        public Integer getOwnerId() {
            return ownerId;
        }

        public void setOwnerId(Integer ownerId) {
            this.ownerId = ownerId;
        }

        public String getName() {
            return name;
        }

        public void setName(String name) {
            this.name = name;
        }

        public String getAvatar() {
            return avatar;
        }

        public void setAvatar(String avatar) {
            this.avatar = avatar;
        }

        public Integer getMaxMembers() {
            return maxMembers;
        }

        public void setMaxMembers(Integer maxMembers) {
            this.maxMembers = maxMembers;
        }

        public String getMemberIds() {
            return memberIds;
        }

        public void setMemberIds(String memberIds) {
            this.memberIds = memberIds;
        }
    }

    /**
     * 成员操作DTO
     */
    public static class MemberOperationDTO {
        private Integer groupId;
        private Integer[] userIds;

        public Integer getGroupId() {
            return groupId;
        }

        public void setGroupId(Integer groupId) {
            this.groupId = groupId;
        }

        public Integer[] getUserIds() {
            return userIds;
        }

        public void setUserIds(Integer[] userIds) {
            this.userIds = userIds;
        }
    }
}
