package com.stylesmile.chat.mapper;

import org.apache.ibatis.annotations.Param;
import org.junit.jupiter.api.Test;

import java.lang.reflect.Method;
import java.lang.reflect.Parameter;
import java.util.Arrays;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Mapper / Service / Controller 中「ID 参数必须是 Long」的防回归测试。
 *
 * <p>背景：chat_user 使用雪花 ID，AUTO_INCREMENT 已达 2091818653023719424，
 * 远大于 {@code Integer.MAX_VALUE}。凡是 ID 参数声明成 Integer 的位置，
 * 大 ID 用户都会出问题：
 * <ul>
 *   <li>Controller 的 {@code @RequestParam Integer} 在参数绑定阶段就抛
 *       NumberFormatException，直接 400，用户拉不到任何历史消息；</li>
 *   <li>Mapper / Service 的 Integer 参数会走 int 类型的 JDBC setter，
 *       数值被截断或报错。</li>
 * </ul>
 * 这些点是被逐个补上的（ChatUserController → ChatSessionMapper →
 * ChatMessageMapper → ChatMessageController），很容易在后续重构里被改回去，
 * 所以用反射把签名钉住。
 *
 * <p>依赖 {@code -parameters} 编译参数（spring-boot-starter-parent 默认开启），
 * 因此每个方法都会先断言参数名可用，避免参数名退化成 arg0 导致测试「假通过」。
 */
class MapperIdTypeTest {

    /** ID 语义的参数名：命中这些名字的参数必须是 Long */
    private static final List<String> ID_PARAM_NAMES = List.of(
            "userId", "targetId", "fromUserId", "toUserId",
            "groupId", "messageId", "friendId", "ownerId", "beforeMessageId"
    );

    @Test
    void chatSessionMapperDeclaresAllIdParamsAsLong() {
        assertIdParamsAreLong(ChatSessionMapper.class,
                "getSessionsByUserId", "getOrCreateSession", "updateLastMessage", "clearUnreadCount");
    }

    @Test
    void chatMessageMapperDeclaresAllIdParamsAsLong() {
        assertIdParamsAreLong(ChatMessageMapper.class, "getHistoryMessages");
    }

    @Test
    void chatMessageServiceDeclaresAllIdParamsAsLong() {
        assertIdParamsAreLong(com.stylesmile.chat.service.ChatMessageService.class,
                "getHistoryMessages", "getHistoryMessagesByCursor");
    }

    @Test
    void chatMessageControllerDeclaresAllIdParamsAsLong() {
        assertIdParamsAreLong(com.stylesmile.chat.controller.ChatMessageController.class,
                "history", "historyCursor");
    }

    @Test
    void chatUserVoDeclaresIdAsLong() throws NoSuchFieldException {
        assertEquals(Long.class,
                com.stylesmile.chat.vo.ChatUserVO.class.getDeclaredField("id").getType(),
                "ChatUserVO.id 必须是 Long：它是返回给前端的用户 ID，Integer 会溢出");
    }

    @Test
    void entityIdFieldsAreLong() throws NoSuchFieldException {
        // 实体是 ORM 映射的源头，这里退化为 Integer 会让所有上层 Long 白改
        assertFieldType(com.stylesmile.chat.entity.ChatUser.class, "id");
        assertFieldType(com.stylesmile.chat.entity.ChatMessage.class, "id");
        assertFieldType(com.stylesmile.chat.entity.ChatMessage.class, "fromUserId");
        assertFieldType(com.stylesmile.chat.entity.ChatMessage.class, "toUserId");
        assertFieldType(com.stylesmile.chat.entity.ChatMessage.class, "groupId");
        assertFieldType(com.stylesmile.chat.entity.ChatSession.class, "userId");
        assertFieldType(com.stylesmile.chat.entity.ChatSession.class, "targetId");
        assertFieldType(com.stylesmile.chat.entity.ChatFriend.class, "userId");
        assertFieldType(com.stylesmile.chat.entity.ChatFriend.class, "friendId");
        assertFieldType(com.stylesmile.chat.entity.ChatFriendRequest.class, "fromUserId");
        assertFieldType(com.stylesmile.chat.entity.ChatFriendRequest.class, "toUserId");
        assertFieldType(com.stylesmile.chat.entity.ChatOfflineMessage.class, "toUserId");
        assertFieldType(com.stylesmile.chat.entity.ChatGroup.class, "ownerId");
        assertFieldType(com.stylesmile.chat.entity.ChatGroupMember.class, "userId");
    }

    private void assertFieldType(Class<?> type, String fieldName) throws NoSuchFieldException {
        assertEquals(Long.class, type.getDeclaredField(fieldName).getType(),
                type.getSimpleName() + "." + fieldName + " 必须是 Long（雪花 ID 超出 int 范围）");
    }

    /**
     * 校验指定方法里所有「ID 语义」的参数类型都是 Long。
     * 只校验命中白名单的参数，避免误伤 page / size 这类本来就该是 Integer 的分页参数。
     */
    private void assertIdParamsAreLong(Class<?> type, String... methodNames) {
        for (String methodName : methodNames) {
            List<Method> candidates = Arrays.stream(type.getDeclaredMethods())
                    .filter(m -> m.getName().equals(methodName))
                    .toList();
            assertTrue(!candidates.isEmpty(),
                    type.getSimpleName() + " 上找不到方法 " + methodName);

            for (Method method : candidates) {
                Parameter[] params = method.getParameters();
                for (Parameter param : params) {
                    assertFalse(param.getName().startsWith("arg"),
                            "反射拿不到真实参数名（" + type.getSimpleName() + "#" + methodName
                                    + " 的 " + param.getName()
                                    + "）—— 缺少 -parameters 编译参数，本测试会假通过，请检查构建配置");
                }
                for (Parameter param : params) {
                    if (!ID_PARAM_NAMES.contains(param.getName())) {
                        continue;
                    }
                    assertEquals(Long.class, param.getType(),
                            type.getSimpleName() + "#" + methodName
                                    + " 的参数 " + param.getName() + " 必须是 Long（雪花 ID 超出 int 范围）");
                }
                // Mapper 上还有 @Param 注解：注解值与参数名不一致时同样视为回归
                for (Parameter param : params) {
                    Param annotation = param.getAnnotation(Param.class);
                    if (annotation != null && ID_PARAM_NAMES.contains(annotation.value())) {
                        assertEquals(Long.class, param.getType(),
                                type.getSimpleName() + "#" + methodName + " 的 @Param(\""
                                        + annotation.value() + "\") 必须是 Long");
                    }
                }
            }
        }
    }
}
