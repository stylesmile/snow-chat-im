package com.stylesmile.common.util;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;
import java.util.Base64;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;

/**
 * JwtUtil 单元测试
 *
 * 覆盖的重点是「用户 ID 超出 int 范围」的场景：用户表主键由雪花算法生成
 * （如 2091818653023719424），早已超出 Integer.MAX_VALUE。此前 getUserId
 * 用 Integer.parseInt 解析，超范围会抛 NumberFormatException 并被 catch 成
 * null，导致 AuthFilter 判定"未登录"——这类账号登录后所有接口 401，
 * 好友申请页面空白、通讯录红点不亮。这里用测试把该回归锁死。
 */
class JwtUtilTest {

    /** 超出 int 范围的用户 ID（对应注册用户 qq 的实际主键） */
    private static final long BEYOND_INT_USER_ID = 2091818653023719424L;

    @Test
    @DisplayName("解析常规范围的用户 ID")
    void getUserId_normalRange() {
        String token = JwtUtil.createToken(1001L, "zz_probe");

        assertEquals(1001L, JwtUtil.getUserId(token));
        assertEquals("zz_probe", JwtUtil.getUsername(token));
    }

    @Test
    @DisplayName("解析超过 int 范围的用户 ID（雪花 ID，曾导致 401 未登录）")
    void getUserId_beyondIntRange() {
        String token = JwtUtil.createToken(BEYOND_INT_USER_ID, "qq");

        Long userId = JwtUtil.getUserId(token);
        assertNotNull(userId, "超 int 范围的 ID 必须能解析出来，否则这类账号全部接口 401");
        assertEquals(BEYOND_INT_USER_ID, userId, "解析出的 ID 必须与原值完全一致，不能被截断");
    }

    @Test
    @DisplayName("无效或过期 token 返回 null")
    void getUserId_invalidToken() {
        assertNull(JwtUtil.getUserId("not-a-jwt"));
        assertNull(JwtUtil.getUserId(""));
    }

    @Test
    @DisplayName("validateToken 对超 int 范围的 ID 同样返回 true")
    void validateToken_beyondIntRange() {
        assertEquals(true, JwtUtil.validateToken(JwtUtil.createToken(BEYOND_INT_USER_ID, "qq")));
        assertEquals(false, JwtUtil.validateToken("garbage"));
    }

    @Test
    @DisplayName("token 有效期为 30 天")
    void createToken_ttlIsThirtyDays() {
        // 背景：有效期原为 7 天，客户端没有续期/过期处理，用户每隔 7 天就会遇到
        // "token 过期 → 所有接口 401 → 发消息失败"，这里把 30 天的有效期锁死。
        String token = JwtUtil.createToken(1001L, "ttl_probe");

        // JWT 由 header.payload.signature 三段组成，第二段是 base64url 编码的 payload
        String[] segments = token.split("\\.");
        assertEquals(3, segments.length, "JWT 必须是三段式结构");

        // 解码 payload，用正则取出 exp（过期时间）与 iat（签发时间）两个秒级时间戳
        String payload = new String(Base64.getUrlDecoder().decode(segments[1]), StandardCharsets.UTF_8);
        long issuedAt = parseClaim(payload, "iat");
        long expiration = parseClaim(payload, "exp");

        // 有效期 = exp - iat，必须正好是 30 天（秒）
        assertEquals(30L * 24 * 60 * 60, expiration - issuedAt,
                "token 有效期应为 30 天，实际 payload: " + payload);
    }

    /**
     * 从 JWT payload 的 JSON 文本中取出指定字段的数值。
     *
     * @param payload JSON 文本（如 {"sub":"1","iat":1789459106,"exp":1802051106}）
     * @param claim   字段名（iat / exp）
     * @return 该字段的 long 值
     */
    private static long parseClaim(String payload, String claim) {
        // 用非贪婪匹配定位 "<claim>":<数字>，避免与 payload 中其它数字串混淆
        java.util.regex.Matcher matcher =
                java.util.regex.Pattern.compile("\"" + claim + "\":(\\d+)").matcher(payload);
        if (!matcher.find()) {
            throw new AssertionError("payload 中缺少字段 " + claim + ": " + payload);
        }
        return Long.parseLong(matcher.group(1));
    }
}
