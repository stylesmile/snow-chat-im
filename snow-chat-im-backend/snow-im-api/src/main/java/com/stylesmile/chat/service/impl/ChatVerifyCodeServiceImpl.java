package com.stylesmile.chat.service.impl;

import cn.hutool.core.util.StrUtil;
import com.stylesmile.chat.entity.ChatVerifyCode;
import com.stylesmile.chat.mapper.ChatVerifyCodeMapper;
import com.stylesmile.chat.service.ChatVerifyCodeService;
import com.stylesmile.chat.util.EmailSenderUtil;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import javax.annotation.Resource;
import java.util.Date;
import java.util.Random;

/**
 * 验证码服务实现：持久化到数据库，通过 EmailSenderUtil 发送邮件
 *
 * @author chenye
 * @date 2026/08/19
 */
@Slf4j
@Service
public class ChatVerifyCodeServiceImpl implements ChatVerifyCodeService {

    @Resource
    private ChatVerifyCodeMapper verifyCodeMapper;

    @Resource
    private EmailSenderUtil emailSenderUtil;

    /**
     * 发送验证码到指定邮箱
     * 流程：生成6位随机码 → 写入 DB（5分钟过期）→ 调用邮件工具发送
     *
     * @param email 收件邮箱
     * @param type  验证码类型：register / reset_password
     * @return true 表示发送成功
     */
    @Override
    public boolean sendCode(String email, String type) {
        // 生成6位数字验证码
        String code = generateCode();
        log.info(" email: {}, code : {}", email, code);
        // 计算过期时间：当前时间 + 5分钟
        Date expireTime = new Date(System.currentTimeMillis() + EXPIRE_SECONDS * 1000L);

        // 将验证码持久化到数据库，用于后续校验和防止过期检查
        ChatVerifyCode record = new ChatVerifyCode();
        record.setEmail(email);
        record.setCode(code);
        record.setType(type);
        record.setExpireTime(expireTime);
        record.setUsed(0);
        verifyCodeMapper.insert(record);

        // 根据验证码类型构造邮件标题和正文
        // Use different email subject/content for registration vs password reset
        String subject;
        String content;
        if ("register".equals(type)) {
            subject = "SnowChat 注册验证码";
            content = "<h2>您的注册验证码是：</h2>"
                    + "<h1 style='color:#4A90D9;letter-spacing:4px;'>" + code + "</h1>"
                    + "<p>验证码有效期5分钟，请尽快完成注册。</p>";
        } else {
            subject = "SnowChat 找回密码验证码";
            content = "<h2>您的找回密码验证码是：</h2>"
                    + "<h1 style='color:#4A90D9;letter-spacing:4px;'>" + code + "</h1>"
                    + "<p>验证码有效期5分钟，请尽快重置密码。</p>";
        }

        // 发送邮件（静默失败：发送异常不影响主流程，仅打印日志）
        // Send email (log failure silently so it doesn't block the main flow)
        try {
            emailSenderUtil.sendHtmlEmail(email, subject, content);
            return true;
        } catch (Exception e) {
            System.err.println("验证码邮件发送失败: " + e.getMessage());
            return false;
        }
    }

    /**
     * 仅校验验证码是否有效（不消耗/不标记为已使用）
     * 用于注册流程的步骤1预览验证，最终注册时仍调用 verifyCode 消费验证码
     */
    @Override
    public boolean checkCode(String email, String code, String type) {
        if (StrUtil.isBlank(email) || StrUtil.isBlank(code)) {
            return false;
        }
        // 查询最新一条未使用的同类型验证码记录（不标记已使用）
        ChatVerifyCode record = verifyCodeMapper.selectLatestUnused(email, type);
        if (record == null) {
            return false;
        }
        // 检查是否过期
        if (record.getExpireTime().before(new Date())) {
            return false;
        }
        // 验证码不区分大小写比较
        return record.getCode().equalsIgnoreCase(code);
    }

    /**
     * 校验验证码（通过后立即标记为已使用）
     * 校验逻辑：查最新一条未使用的记录 → 判断是否过期 → 标记已使用
     *
     * @param email 邮箱
     * @param code  用户输入
     * @param type  类型
     * @return true 表示校验通过
     */
    @Override
    public boolean verifyCode(String email, String code, String type) {
        if (StrUtil.isBlank(email) || StrUtil.isBlank(code)) {
            return false;
        }
        // 查询最新一条未使用的同类型验证码记录
        ChatVerifyCode record = verifyCodeMapper.selectLatestUnused(email, type);
        if (record == null) {
            return false;
        }
        // 检查是否过期
        if (record.getExpireTime().before(new Date())) {
            return false;
        }
        // 验证码不区分大小写比较
        if (!record.getCode().equalsIgnoreCase(code)) {
            return false;
        }
        // 校验通过，立即标记为已使用，防止重复使用
        verifyCodeMapper.markUsed(record.getId());
        return true;
    }

    /**
     * 生成6位纯数字验证码
     */
    private String generateCode() {
        Random random = new Random();
        int code = 100000 + random.nextInt(900000);
        return String.valueOf(code);
    }
}
