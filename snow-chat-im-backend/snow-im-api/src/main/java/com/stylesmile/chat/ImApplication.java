package com.stylesmile.chat;

import com.stylesmile.chat.filter.AuthFilter;
import com.stylesmile.chat.storage.MinioProperties;
import org.mybatis.spring.annotation.MapperScan;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;

/**
 * IM 应用主入口。
 * 启用 MinioProperties 配置绑定，使 minio.* 配置可注入到 Bean。
 *
 * @author mmm
 */
@MapperScan("com.stylesmile.chat.mapper")
@SpringBootApplication
@EnableConfigurationProperties(MinioProperties.class)
public class ImApplication {
    public static void main(String[] args) {
        SpringApplication.run(ImApplication.class, args);
    }

    /**
     * 注册 Token 认证 Filter
     *
     * 拦截所有 /chat/** 路径（除了白名单中的公开接口）
     * 白名单由 AuthFilter 内部维护：login / register / send/email/code / verify/code / reset/password
     */
    @Bean
    public FilterRegistrationBean<AuthFilter> authFilterRegistration() {
        FilterRegistrationBean<AuthFilter> bean = new FilterRegistrationBean<>();
        bean.setFilter(new AuthFilter());
        bean.addUrlPatterns("/chat/*");
        bean.setOrder(1); // 最高优先级，在其他 Filter 之前执行
        bean.setName("authFilter");
        return bean;
    }
}
