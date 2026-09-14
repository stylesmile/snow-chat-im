package com.stylesmile.chat;

import com.stylesmile.chat.filter.AuthFilter;
import com.stylesmile.chat.shard.MessageShardProperties;
import com.stylesmile.chat.storage.AliyunOssProperties;
import com.stylesmile.chat.storage.DiskProperties;
import com.stylesmile.chat.storage.MinioProperties;
import com.stylesmile.chat.storage.SeaweedfsProperties;
import com.stylesmile.chat.storage.StorageProperties;
import org.mybatis.spring.annotation.MapperScan;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;

/**
 * IM 应用主入口。
 *
 * <p>显式注册文件存储相关的配置属性类（minio / seaweedfs / aliyun-oss）。
 * 这些类都是 record，没有 {@code @Component}，必须在此注册才能完成配置绑定，
 * 否则存储 Bean 注入配置时会因找不到对应 Bean 而启动失败。
 *
 * <p>具体启用哪一种存储由配置项 {@code storage.type} 决定，见
 * {@link com.stylesmile.chat.storage.StorageType}。
 *
 * @author mmm
 */
@MapperScan("com.stylesmile.chat.mapper")
@SpringBootApplication
@EnableConfigurationProperties({
        StorageProperties.class,    // 存储类型解析（storage.type），非法值启动期快速失败
        MinioProperties.class,      // MinIO 配置绑定（storage.type=minio）
        SeaweedfsProperties.class,  // SeaweedFS 配置绑定（storage.type=seaweedfs）
        AliyunOssProperties.class,  // 阿里云 OSS 配置绑定（storage.type=aliyun-oss）
        DiskProperties.class,       // 本地磁盘存储配置绑定（storage.type=disk）
        MessageShardProperties.class // 消息分表粒度（chat.message.shard.*）
})
public class ImApiApplication {
    public static void main(String[] args) {
        SpringApplication.run(ImApiApplication.class, args);
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
