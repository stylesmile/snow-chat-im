package com.stylesmile.chat.controller;

import com.stylesmile.chat.dto.MemberOperationDTO;
import com.stylesmile.common.util.Result;
import com.stylesmile.chat.entity.ChatGroup;
import com.stylesmile.chat.entity.ChatGroupMember;
import com.stylesmile.chat.service.ChatGroupMemberService;
import com.stylesmile.chat.service.ChatGroupService;
import lombok.Data;
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
    public Result<Long> create(@RequestBody GroupCreateDTO body) {
        List<Long> memberIds = body.getMemberIds() != null
                ? Arrays.stream(body.getMemberIds().split(","))
                .map(String::trim)
                .map(Long::valueOf)
                .toList()
                : null;
        Long groupId = chatGroupService.createGroup(
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
    public Result<ChatGroup> getGroup(@PathVariable Long groupId) {
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
    public Result<List<ChatGroup>> list(@RequestParam Long userId) {
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
    public Result<List<ChatGroupMember>> getMembers(@PathVariable Long groupId) {
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
        for (Long userId : body.getUserIds()) {
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
        for (Long userId : body.getUserIds()) {
            chatGroupMemberService.removeMember(body.getGroupId(), userId);
        }
        return Result.success();
    }

    /**
     * 创建群组请求DTO
     */
    @Data
    public static class GroupCreateDTO {
        private Long ownerId;
        private String name;
        private String avatar;
        private Integer maxMembers;
        private String memberIds;
    }


}
