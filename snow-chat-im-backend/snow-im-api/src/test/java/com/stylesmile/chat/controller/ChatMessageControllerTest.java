package com.stylesmile.chat.controller;

import com.stylesmile.chat.dto.ReadMessageDTO;
import com.stylesmile.chat.dto.RecallMessageDTO;
import com.stylesmile.chat.dto.SendMessageDTO;
import com.stylesmile.chat.entity.ChatMessage;
import com.stylesmile.chat.service.ChatMessageService;
import com.stylesmile.common.util.Result;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.atLeast;
import static org.mockito.Mockito.doNothing;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ChatMessageControllerTest {

    @Mock
    private ChatMessageService chatMessageService;

    @InjectMocks
    private ChatMessageController controller;

    @Test
    void getsHistoryWithPagingArguments() {
        List<ChatMessage> messages = List.of(new ChatMessage());
        when(chatMessageService.getHistoryMessages(1, 2, "friend", 2, 15)).thenReturn(messages);

        Result<List<ChatMessage>> result = controller.history(1, 2, "friend", 2, 15);

        assertSuccess(result);
        assertEquals(messages, result.getData());
        verify(chatMessageService).getHistoryMessages(1, 2, "friend", 2, 15);
    }

    @Test
    void recallsAndMarksMessagesAsRead() {
        RecallMessageDTO recall = new RecallMessageDTO();
        recall.setUserId(1L);
        recall.setMessageId(99L);
        ReadMessageDTO read = new ReadMessageDTO();
        read.setUserId(1L);
        read.setTargetId(2L);
        read.setTargetType("group");

        assertSuccess(controller.recall(recall));
        assertSuccess(controller.markAsRead(read));

        verify(chatMessageService).recallMessage(1L, 99L);
        verify(chatMessageService).markAsRead(1L, 2L, "group");
    }

    @Test
    void mapsSendDtoToChatMessage() {
        SendMessageDTO dto = new SendMessageDTO();
        dto.setFromUserId(1L);
        dto.setToUserId(2L);
        dto.setGroupId(null);
        dto.setType("text");
        dto.setContent("hello");

        assertSuccess(controller.send(dto));

        ArgumentCaptor<ChatMessage> captor = ArgumentCaptor.forClass(ChatMessage.class);
        verify(chatMessageService).sendMessage(captor.capture());
        ChatMessage message = captor.getValue();
        assertEquals(1, message.getFromUserId());
        assertEquals(2, message.getToUserId());
        assertEquals("text", message.getType());
        assertEquals("hello", message.getContent());
    }

    /**
     * 小需求1：MQTT 重连补推接口
     * 验证 POST /chat/message/sync 委托给 service.fetchAndPushUndelivered
     * 区别于 /undelivered（返回列表由客户端拉取），/sync 由服务器通过 MQTT 主动推送
     */
    @Test
    void syncDelegatesToFetchAndPushUndelivered() {
        // 准备：构造请求体，模拟 MQTT 重连后客户端请求补推未送达消息
        ChatMessageController.FetchUndeliveredDTO body = new ChatMessageController.FetchUndeliveredDTO();
        body.setUserId(1L);            // 当前用户 ID
        body.setTargetId(2L);          // 对端用户 ID（私聊）或群组 ID
        body.setTargetType("friend");  // 会话类型：friend=私聊 / group=群聊

        // 执行：调用 sync 接口，应委托给 service.fetchAndPushUndelivered
        assertSuccess(controller.sync(body));

        // 验证：service.fetchAndPushUndelivered 被正确参数调用（通过 MQTT 推送而非返回列表）
        verify(chatMessageService).fetchAndPushUndelivered(1L, 2L, "friend");
    }

    /**
     * 消息类型白名单校验：非法 type 应返回 fail，不委托 service
     */
    @Test
    void sendRejectsInvalidMessageType() {
        // 准备：type 设为未在白名单中的值
        SendMessageDTO dto = new SendMessageDTO();
        dto.setFromUserId(1L);
        dto.setToUserId(2L);
        dto.setType("unknown");  // 不在白名单
        dto.setContent("x");

        // 执行
        Result<Void> result = controller.send(dto);

        // 验证：失败返回（code="500"），且不委托 service
        assertEquals("500", result.getCode());
        assertNotNull(result.getMsg());
        verify(chatMessageService, never()).sendMessage(any());
    }

    /**
     * 消息类型白名单校验：合法 type（image/video/file/self/recall）应正常发送
     */
    @Test
    void sendAcceptsAllowedMessageTypes() {
        // 循环前统一设置 lenient stub：避免 strict stubbing 在循环中叠加冲突
        org.mockito.Mockito.lenient().doNothing().when(chatMessageService).sendMessage(any());
        for (String type : new String[]{"image", "video", "file", "self", "recall"}) {
            // 准备
            SendMessageDTO dto = new SendMessageDTO();
            dto.setFromUserId(1L);
            dto.setToUserId(2L);
            dto.setType(type);
            dto.setContent("content");
            // 执行
            Result<Void> result = controller.send(dto);
            // 验证：成功且委托 service（至少 1 次，容忍历史 stub 残留）
            assertSuccess(result);
            org.mockito.Mockito.verify(chatMessageService, atLeast(1)).sendMessage(any());
        }
    }

    private void assertSuccess(Result<?> result) {
        assertEquals("200", result.getCode());
    }
}
