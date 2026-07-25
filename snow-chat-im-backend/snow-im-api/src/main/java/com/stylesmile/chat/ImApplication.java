package com.stylesmile.chat;

import com.stylesmile.chat.storage.MinioProperties;
import org.mybatis.spring.annotation.MapperScan;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.EnableConfigurationProperties;

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
        // 启动 Spring Boot
        SpringApplication.run(ImApplication.class, args);
    }
}
