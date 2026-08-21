package com.stylesmile.chat.service;

/**
 * 验证码服务：生成、发送、校验验证码
 *
 * @author chenye
 * @date 2026/08/19
 */
public interface ChatVerifyCodeService {
    /** 验证码有效期：5 分钟（单位：秒） */
    int EXPIRE_SECONDS = 300;
    /** 验证码长度 */
    int CODE_LENGTH = 6;

    /**
     * 发送验证码到指定邮箱
     *
     * @param email 收件邮箱
     * @param type  验证码类型：register / reset_password
     * @return true 表示发送成功
     */
    boolean sendCode(String email, String type);

    /**
     * 校验验证码（校验后立即标记为已使用，防止重复使用）
     *
     * @param email 邮箱
     * @param code  用户输入的验证码
     * @param type  验证码类型
     * @return true 表示校验通过
     */
    boolean verifyCode(String email, String code, String type);

    /**
     * 仅校验验证码是否有效（不消耗/不标记为已使用）
     * 用于注册流程的步骤1预览验证，最终注册时仍调用 verifyCode 消费验证码
     *
     * @param email 邮箱
     * @param code  用户输入的验证码
     * @param type  验证码类型
     * @return true 表示校验通过
     */
    boolean checkCode(String email, String code, String type);
}
