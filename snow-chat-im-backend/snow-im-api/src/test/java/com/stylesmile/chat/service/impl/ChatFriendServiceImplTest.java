// ChatFriendServiceImpl 扩展单测
// 覆盖：重复添加、移除、按 userId 查询、isFriend 判等
import com.stylesmile.chat.entity.ChatFriend;
import com.stylesmile.chat.mapper.ChatFriendMapper;
import com.stylesmile.chat.service.impl.ChatFriendServiceImpl;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.Spy;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doReturn;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ChatFriendServiceImplTest {

    @Mock
    private ChatFriendMapper mapper;

    @Spy
    private ChatFriendServiceImpl service;

    @BeforeEach
    void setUp() {
        ReflectionTestUtils.setField(service, "baseMapper", mapper);
    }

    @Test
    void delegatesFriendQueries() {
        List<ChatFriend> friends = List.of(new ChatFriend());
        ChatFriend friend = new ChatFriend();
        // 业务方法签名期望 Long
        when(mapper.getFriendsByUserId(1L)).thenReturn(friends);
        when(mapper.getFriend(1L, 2L)).thenReturn(friend);

        assertEquals(friends, service.getFriendsByUserId(1L));
        assertEquals(friend, service.getFriend(1L, 2L));
        assertTrue(service.isFriend(1L, 2L));
        when(mapper.getFriend(1L, 3L)).thenReturn(null);
        assertFalse(service.isFriend(1L, 3L));
    }

    @Test
    void createsFriendRelation() {
        doReturn(true).when(service).save(any(ChatFriend.class));

        // addFriend 签名期望 Long
        service.addFriend(1L, 2L);

        ArgumentCaptor<ChatFriend> captor = ArgumentCaptor.forClass(ChatFriend.class);
        verify(service).save(captor.capture());
        assertEquals(1L, captor.getValue().getUserId());
        assertEquals(2L, captor.getValue().getFriendId());
    }

    @Test
    void addFriendSkipsWhenAlreadyFriend() {
        // isFriend 返回 true，说明已经建立好友关系
        doReturn(true).when(service).isFriend(1L, 2L);
        service.addFriend(1L, 2L);
        // 不应再写入新记录
        verify(service, never()).save(any(ChatFriend.class));
    }

    @Test
    void removeFriendDeletesBothDirections() {
        service.removeFriend(1L, 2L);

        // 双向删除：一共调用两次 delete，具体 QueryWrapper 形状不验证
        verify(mapper, times(2)).delete(any());
    }

    @Test
    void getFriendsByUserIdReturnsEmptyWhenNone() {
        when(mapper.getFriendsByUserId(7L)).thenReturn(List.of());
        assertEquals(List.of(), service.getFriendsByUserId(7L));
    }

    @Test
    void getFriendReturnsNullWhenNotExists() {
        when(mapper.getFriend(5L, 6L)).thenReturn(null);
        assertSame(null, service.getFriend(5L, 6L));
        assertFalse(service.isFriend(5L, 6L));
    }
}
