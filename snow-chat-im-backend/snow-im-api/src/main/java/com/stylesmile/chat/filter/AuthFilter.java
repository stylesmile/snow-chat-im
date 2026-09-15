package com.stylesmile.chat.filter;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.stylesmile.common.util.JwtUtil;
import com.stylesmile.common.util.Result;
import com.stylesmile.common.util.ReturnCode;

import jakarta.servlet.*;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.List;

/**
 * Token 认证拦截器（Servlet Filter）
 *
 * 逻辑：
 * 1. 检查请求路径是否在白名单中（登录/注册/发送验证码等公开接口），是则放行
 * 2. 从 Header Authorization 中提取 Bearer token
 * 3. 解析 token，提取 userId，设置到请求属性中（供 Controller 使用）
 * 4. token 无效或过期时返回 401
 */
public class AuthFilter implements Filter {

    // 白名单路径：不需要 token 校验的接口
    private static final List<String> WHITE_LIST = List.of(
            "/chat/user/login",
            "/chat/user/register",
            "/chat/user/send/email/code",
            "/chat/user/verify/code",
            "/chat/user/reset/password",
            "/chat/app/version"
    );

    private final ObjectMapper objectMapper = new ObjectMapper();

    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {

        HttpServletRequest httpReq = (HttpServletRequest) request;
        HttpServletResponse httpResp = (HttpServletResponse) response;

        String path = httpReq.getRequestURI();

        // 1. 白名单路径直接放行
        if (isWhiteList(path)) {
            chain.doFilter(request, response);
            return;
        }

        // 2. 从 Authorization header 获取 token
        String authHeader = httpReq.getHeader(JwtUtil.HEADER);
        if (authHeader == null || !authHeader.startsWith(JwtUtil.PREFIX)) {
            sendUnauthorized(httpResp);
            return;
        }

        // 3. 去掉 Bearer 前缀，解析 token 获取 userId
        String token = authHeader.substring(JwtUtil.PREFIX.length());
        Long userId = JwtUtil.getUserId(token);
        if (userId == null) {
            sendUnauthorized(httpResp);
            return;
        }

        // 4. 将 userId 写入请求属性，供下游 Controller 读取
        httpReq.setAttribute("currentUserId", userId);
        chain.doFilter(request, response);
    }

    /**
     * 判断路径是否在白名单中（支持通配前缀匹配）
     */
    private boolean isWhiteList(String path) {
        return WHITE_LIST.stream().anyMatch(path::endsWith);
    }

    /**
     * 返回 401 未授权响应
     */
    private void sendUnauthorized(HttpServletResponse response) throws IOException {
        response.setContentType("application/json;charset=UTF-8");
        response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        Result<Void> result = new Result<>();
        result.setCode(ReturnCode.NOT_LOGIN.getCode());
        result.setMsg(ReturnCode.NOT_LOGIN.getDesc());
        response.getWriter().write(objectMapper.writeValueAsString(result));
    }
}
