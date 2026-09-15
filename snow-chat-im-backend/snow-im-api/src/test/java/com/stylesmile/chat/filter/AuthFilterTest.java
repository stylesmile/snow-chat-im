package com.stylesmile.chat.filter;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.stylesmile.common.util.JwtUtil;
import jakarta.servlet.FilterChain;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;

/**
 * AuthFilter 单元测试：验证 token 解析失败的账号不会被误判为"未登录"
 *
 * 背景：注册用户的主键由雪花算法生成（如 2091818653023719424），超出 int 范围。
 * 此前 AuthFilter 用 Integer 接收 JwtUtil.getUserId 的结果，解析异常被吞成
 * null 后直接返回 401，于是这类账号登录后任何接口都拿不到数据。
 */
class AuthFilterTest {

    /** 超出 int 范围的用户 ID（注册用户 qq 的实际主键） */
    private static final long BEYOND_INT_USER_ID = 2091818653023719424L;

    private AuthFilter filter;
    private final ObjectMapper objectMapper = new ObjectMapper();

    @BeforeEach
    void setUp() {
        filter = new AuthFilter();
    }

    @Test
    @DisplayName("超 int 范围的用户 ID 应通过鉴权并写入请求属性")
    void doFilter_beyondIntUserId_passes() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/chat/friend/pending");
        request.addHeader(JwtUtil.HEADER, JwtUtil.PREFIX + JwtUtil.createToken(BEYOND_INT_USER_ID, "qq"));
        MockHttpServletResponse response = new MockHttpServletResponse();
        FilterChain chain = new MockFilterChain();

        filter.doFilter(request, response, chain);

        assertEquals(200, response.getStatus(), "合法 token 不应返回 401");
        Object attr = request.getAttribute("currentUserId");
        assertNotNull(attr, "鉴权通过后必须把 userId 写入请求属性");
        // 属性必须是完整的大 ID（Long），不能用 int 承载
        assertEquals(BEYOND_INT_USER_ID, ((Number) attr).longValue());
    }

    @Test
    @DisplayName("缺少 token 返回 401 未登录")
    void doFilter_missingToken_returns401() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/chat/friend/pending");
        MockHttpServletResponse response = new MockHttpServletResponse();

        filter.doFilter(request, response, new MockFilterChain());

        assertEquals(401, response.getStatus());
        JsonNode body = objectMapper.readTree(response.getContentAsString());
        assertEquals("401", body.get("code").asText());
        assertNull(request.getAttribute("currentUserId"));
    }

    @Test
    @DisplayName("损坏的 token 返回 401 且不放行")
    void doFilter_brokenToken_returns401() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/chat/friend/pending");
        request.addHeader(JwtUtil.HEADER, JwtUtil.PREFIX + "broken.token.value");
        MockHttpServletResponse response = new MockHttpServletResponse();
        MockFilterChain chain = new MockFilterChain();

        filter.doFilter(request, response, chain);

        assertEquals(401, response.getStatus());
        // MockFilterChain 未被调用，说明请求没有继续往下走
        assertNull(chain.getRequest(), "鉴权失败时不应放行到后续链路");
    }

    @Test
    @DisplayName("白名单路径无需 token 直接放行")
    void doFilter_whiteList_passesWithoutToken() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("POST", "/chat/user/login");
        MockHttpServletResponse response = new MockHttpServletResponse();
        MockFilterChain chain = new MockFilterChain();

        filter.doFilter(request, response, chain);

        assertEquals(200, response.getStatus());
        assertNotNull(chain.getRequest(), "白名单接口应放行到后续链路");
    }
}
