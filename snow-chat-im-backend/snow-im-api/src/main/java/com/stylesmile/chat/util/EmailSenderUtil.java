package com.stylesmile.chat.util;

import cn.hutool.core.util.StrUtil;
import jakarta.mail.*;
import jakarta.mail.internet.InternetAddress;
import jakarta.mail.internet.MimeBodyPart;
import jakarta.mail.internet.MimeMessage;

import jakarta.mail.internet.MimeMultipart;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.util.Date;
import java.util.Properties;

/**
 * 邮箱发送工具，配置从 application.yml 的 email.* 读取
 *
 * @author chenye
 * @date 2026/08/19
 */
@Component
public class EmailSenderUtil {

    /** SMTP 服务器地址 */
    @Value("${email.smtp-host:smtpout.secureserver.net}")
    private String smtpHost;

    /** SMTP 端口（SSL） */
    @Value("${email.smtp-port:465}")
    private int smtpPort;

    /** 发件人邮箱 */
    @Value("${email.from:''}")
    private String from;

    /** 发件人授权码/密码 */
    @Value("${email.password}")
    private String password;

    /**
     * 发送 HTML 格式邮件（GoDaddy Titan SMTP，SSL 465端口）
     *
     * @param to      收件人邮箱
     * @param subject 邮件主题
     * @param content HTML 内容
     */
    public void sendHtmlEmail(String to, String subject, String content) {
        // 参数校验
        if (StrUtil.isBlank(to)) {
            System.err.println("收件人不能为空");
            return;
        }
        if (StrUtil.isBlank(subject)) {
            System.err.println("邮件主题不能为空");
            return;
        }
        if (StrUtil.isBlank(content)) {
            System.err.println("邮件内容不能为空");
            return;
        }

        // 构建 SMTP 连接属性（SSL 465端口需要）
        Properties props = new Properties();
        props.put("mail.smtp.host", smtpHost);
        props.put("mail.smtp.port", String.valueOf(smtpPort));
        props.put("mail.smtp.auth", "true");
        props.put("mail.smtp.ssl.enable", "true");
        props.put("mail.smtp.ssl.trust", "*");

        // 创建认证会话
        Session session = Session.getInstance(props, new Authenticator() {
            @Override
            protected PasswordAuthentication getPasswordAuthentication() {
                return new PasswordAuthentication(from, password);
            }
        });

        try {
            // 构建邮件消息
            MimeMessage msg = new MimeMessage(session);
            msg.setFrom(new InternetAddress(from));
            msg.setRecipients(Message.RecipientType.TO, InternetAddress.parse(to));
            msg.setSubject(subject, "UTF-8");
            msg.setContent(content, "text/html;charset=UTF-8");
            msg.setSentDate(new Date());

            // 发送邮件
            Transport.send(msg);
            System.out.println("邮件发送成功 → " + to);
        } catch (Exception e) {
            System.err.println("邮件发送失败 → " + to + ": " + e.getMessage());
            e.printStackTrace();
        }
    }
//    public static void sendGodaddyTiTanUsingSmtp(String to, String subject, String content) {
//        Properties props = new Properties();
//        props.put("mail.smtp.host", "smtpout.secureserver.net");
//        props.put("mail.smtp.port", "465");
//        props.put("mail.smtp.auth", "true");
//        props.put("mail.smtp.ssl.enable", "true");
//        props.put("mail.smtp.ssl.trust", "*");
//
//
//        Session session = Session.getInstance(props, new Authenticator() {
//            protected PasswordAuthentication getPasswordAuthentication() {
//                return new PasswordAuthentication(from, password);
//
//            }
//        });
//        MimeMessage msg = new MimeMessage(session);
//        try {
//            InternetAddress fromAddress = new InternetAddress(EMAIL_USERNAME);
////            fromAddress.setPersonal(EMAIL_USERNAME, "UTF-8");
//            msg.setFrom(fromAddress);
//            msg.setRecipients(MimeMessage.RecipientType.TO, InternetAddress.parse(to));
//            msg.setSubject(subject, "UTF-8");
//            msg.setContent(content, "text/html;charset=UTF-8");
//            msg.setSentDate(new Date());
//
//            MimeBodyPart messageBodyPart = new MimeBodyPart();
//            messageBodyPart.setContent("Test Content.", "text/html");
//
//            Multipart multipart = new MimeMultipart();
//            multipart.addBodyPart(messageBodyPart);
//            MimeBodyPart attachPart = new MimeBodyPart();
//
////            attachPart.attachFile("/var/tmp/abc.txt");
////            multipart.addBodyPart(attachPart);
////            msg.setContent(multipart);
//            Transport.send(msg);
//        } catch (MessagingException e) {
//            // TODO Auto-generated catch block
//            e.printStackTrace();
//        }
//    }
}
