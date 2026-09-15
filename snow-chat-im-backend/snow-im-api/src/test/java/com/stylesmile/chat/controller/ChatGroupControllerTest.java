package com.stylesmile.chat.controller;

import com.stylesmile.chat.dto.MemberOperationDTO;
import com.stylesmile.chat.entity.ChatGroup;
import com.stylesmile.chat.entity.ChatGroupMember;
import com.stylesmile.chat.service.ChatGroupMemberService;
import com.stylesmile.chat.service.ChatGroupService;
import com.stylesmile.common.util.Result;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ChatGroupControllerTest {

    @Mock
    private ChatGroupService chatGroupService;

    @Mock
    private ChatGroupMemberService chatGroupMemberService;

    @InjectMocks
    private ChatGroupController controller;

    @Test
    void createsGroupAndParsesMemberIds() {
        ChatGroupController.GroupCreateDTO dto = new ChatGroupController.GroupCreateDTO();
        dto.setOwnerId(1L);
        dto.setName("开发组");
        dto.setAvatar("avatar.png");
        dto.setMaxMembers(100);
        dto.setMemberIds("2, 3,4");
        when(chatGroupService.createGroup(1L, "开发组", "avatar.png", 100, List.of(2L, 3L, 4L)))
                .thenReturn(9L);

        Result<Long> result = controller.create(dto);

        assertSuccess(result);
        assertEquals(9, result.getData());
        verify(chatGroupService).createGroup(1L, "开发组", "avatar.png", 100, List.of(2L, 3L, 4L));
    }

    @Test
    void createsGroupWithoutInitialMembers() {
        ChatGroupController.GroupCreateDTO dto = new ChatGroupController.GroupCreateDTO();
        dto.setOwnerId(1L);
        dto.setName("空群");
        when(chatGroupService.createGroup(1L, "空群", null, null, null)).thenReturn(10L);

        Result<Long> result = controller.create(dto);

        assertSuccess(result);
        assertEquals(10, result.getData());
        verify(chatGroupService).createGroup(1L, "空群", null, null, null);
    }

    @Test
    void getsGroupAndMembers() {
        ChatGroup group = new ChatGroup();
        List<ChatGroupMember> members = List.of(new ChatGroupMember());
        when(chatGroupService.getGroupById(9L)).thenReturn(group);
        when(chatGroupMemberService.getMembersByGroupId(9L)).thenReturn(members);

        Result<ChatGroup> groupResult = controller.getGroup(9L);
        Result<List<ChatGroupMember>> memberResult = controller.getMembers(9L);

        assertSuccess(groupResult);
        assertEquals(group, groupResult.getData());
        assertSuccess(memberResult);
        assertEquals(members, memberResult.getData());
    }

    @Test
    void listsGroupsForUser() {
        List<ChatGroup> groups = List.of(new ChatGroup());
        when(chatGroupService.getGroupsByUserId(3L)).thenReturn(groups);

        Result<List<ChatGroup>> result = controller.list(3L);

        assertSuccess(result);
        assertEquals(groups, result.getData());
    }

    @Test
    void addsAndRemovesAllRequestedMembers() {
        MemberOperationDTO dto = new MemberOperationDTO();
        dto.setGroupId(9L);
        dto.setUserIds(new Long[]{2L, 3L});

        assertSuccess(controller.addMembers(dto));
        assertSuccess(controller.removeMembers(dto));

        verify(chatGroupMemberService).addMember(9L, 2L);
        verify(chatGroupMemberService).addMember(9L, 3L);
        verify(chatGroupMemberService).removeMember(9L, 2L);
        verify(chatGroupMemberService).removeMember(9L, 3L);
    }

    private void assertSuccess(Result<?> result) {
        assertEquals("200", result.getCode());
    }
}
