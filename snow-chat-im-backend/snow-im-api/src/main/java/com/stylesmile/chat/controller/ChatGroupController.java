package com.stylesmile.chat.controller;

import com.stylesmile.chat.dto.MemberOperationDTO;
import com.stylesmile.common.util.Result;
import com.stylesmile.chat.entity.ChatGroup;
import com.stylesmile.chat.entity.ChatGroupMember;
import com.stylesmile.chat.service.ChatGroupMemberService;
import com.stylesmile.chat.service.ChatGroupService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Data;
import org.springframework.web.bind.annotation.*;

import javax.annotation.Resource;
import java.util.Arrays;
import java.util.List;

/**
 * 群组控制器
 */
@RestController
@RequestMapping("/chat/group")
@Tag(name = "群组管理", description = "群组创建、查询、成员管理接口")
public class ChatGroupController {

    @Resource
    private ChatGroupService chatGroupService;

    @Resource
    private ChatGroupMemberService chatGroupMemberService;

    /**
     * 创建群组
     */
    @Operation(summary = "创建群组", description = "创建新群组，可指定初始成员")
    @ApiResponse(responseCode = "200", description = "创建成功，返回群组ID")
    @ApiResponse(responseCode = "400", description = "参数错误")
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
     */
    @Operation(summary = "获取群组信息", description = "根据群组ID获取群组详细信息")
    @ApiResponse(responseCode = "200", description = "查询成功")
    @ApiResponse(responseCode = "404", description = "群组不存在")
    @GetMapping("/{groupId}")
    public Result<ChatGroup> getGroup(
            @Parameter(description = "群组ID", required = true) @PathVariable Long groupId) {
        ChatGroup group = chatGroupService.getGroupById(groupId);
        return Result.success(group);
    }

    /**
     * 获取用户所在群组列表
     */
    @Operation(summary = "获取用户群组列表", description = "获取指定用户所在的所有群组")
    @ApiResponse(responseCode = "200", description = "查询成功")
    @GetMapping("/list")
    public Result<List<ChatGroup>> list(
            @Parameter(description = "用户ID", required = true) @RequestParam Long userId) {
        List<ChatGroup> groups = chatGroupService.getGroupsByUserId(userId);
        return Result.success(groups);
    }

    /**
     * 获取群组成员列表
     */
    @Operation(summary = "获取群组成员列表", description = "获取指定群组的所有成员")
    @ApiResponse(responseCode = "200", description = "查询成功")
    @GetMapping("/members/{groupId}")
    public Result<List<ChatGroupMember>> getMembers(
            @Parameter(description = "群组ID", required = true) @PathVariable Long groupId) {
        List<ChatGroupMember> members = chatGroupMemberService.getMembersByGroupId(groupId);
        return Result.success(members);
    }

    /**
     * 添加群组成员
     */
    @Operation(summary = "添加群组成员", description = "向群组添加一个或多个成员")
    @ApiResponse(responseCode = "200", description = "添加成功")
    @ApiResponse(responseCode = "400", description = "参数错误")
    @PostMapping("/members/add")
    public Result<Void> addMembers(@RequestBody MemberOperationDTO body) {
        for (Long userId : body.getUserIds()) {
            chatGroupMemberService.addMember(body.getGroupId(), userId);
        }
        return Result.success();
    }

    /**
     * 移除群组成员
     */
    @Operation(summary = "移除群组成员", description = "从群组移除一个或多个成员")
    @ApiResponse(responseCode = "200", description = "移除成功")
    @ApiResponse(responseCode = "400", description = "参数错误")
    @PostMapping("/members/remove")
    public Result<Void> removeMembers(@RequestBody MemberOperationDTO body) {
        for (Long userId : body.getUserIds()) {
            chatGroupMemberService.removeMember(body.getGroupId(), userId);
        }
        return Result.success();
    }

    @Data
    @Schema(description = "创建群组请求DTO")
    public static class GroupCreateDTO {
        @Schema(description = "群主ID", example = "1")
        private Long ownerId;
        @Schema(description = "群组名称", example = "测试群组")
        private String name;
        @Schema(description = "群组头像URL", example = "https://example.com/group.jpg")
        private String avatar;
        @Schema(description = "最大成员数", example = "500")
        private Integer maxMembers;
        @Schema(description = "初始成员ID列表（逗号分隔）", example = "2,3,4")
        private String memberIds;
    }
}
