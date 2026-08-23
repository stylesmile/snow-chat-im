package com.stylesmile.common.util;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Date;

/**
 * JWT 工具类：生成和解析登录令牌
 *
 * 用法：
 *   String token = JwtUtil.createToken(userId, username);
 *   Integer userId = JwtUtil.getUserId(token);
 */
public class JwtUtil {

    // 签名密钥：至少 256 位（32 字节），生产环境建议从配置读取
    private static final String SECRET = "snow-chat-im-jwt-secret-key-2024-snow-chat";

    // Token 有效期：7 天
    private static final long EXPIRE_MS = 7L * 24 * 60 * 60 * 1000;

    // Header 中 token 的字段名（前端发送：Authorization: Bearer <token>）
    public static final String HEADER = "Authorization";
    public static final String PREFIX = "Bearer ";

    private static final SecretKey KEY = Keys.hmacShaKeyFor(
            SECRET.getBytes(StandardCharsets.UTF_8)
    );

    /**
     * 生成 JWT token
     *
     * @param userId   用户 ID
     * @param username 用户名
     * @return JWT 字符串
     */
    public static String createToken(Integer userId, String username) {
        return Jwts.builder()
                .subject(String.valueOf(userId))          // subject：用户 ID
                .claim("username", username)              // 附加字段：用户名
                .issuedAt(new Date())                     // 签发时间
                .expiration(new Date(System.currentTimeMillis() + EXPIRE_MS)) // 过期时间
                .signWith(KEY)                            // 签名
                .compact();
    }

    /**
     * 解析 token，返回用户 ID；token 无效或过期返回 null
     *
     * @param token JWT 字符串（不含 Bearer 前缀）
     * @return 用户 ID，无效时返回 null
     */
    public static Integer getUserId(String token) {
        try {
            Claims claims = Jwts.parser()
                    .verifyWith(KEY)
                    .build()
                    .parseSignedClaims(token)
                    .getPayload();
            return Integer.parseInt(claims.getSubject());
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * 解析 token，返回用户名
     */
    public static String getUsername(String token) {
        try {
            Claims claims = Jwts.parser()
                    .verifyWith(KEY)
                    .build()
                    .parseSignedClaims(token)
                    .getPayload();
            return claims.get("username", String.class);
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * 验证 token 是否有效（未签名损坏且未过期）
     */
    public static boolean validateToken(String token) {
        return getUserId(token) != null;
    }
}
