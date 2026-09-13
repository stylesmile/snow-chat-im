package com.stylesmile.chat.storage;

import com.aliyun.oss.OSS;
import com.aliyun.oss.OSSClientBuilder;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * 阿里云 OSS Spring 配置类。
 * 仅当 {@code storage.type=aliyun-oss} 时生效，注册 OSS 客户端 Bean。
 *
 * <p>OSS 客户端是线程安全的，官方建议全局单例复用（内部维护连接池），
 * 因此这里注册为 Spring 单例 Bean，并由容器在关闭时调用 {@code shutdown()} 释放资源。
 *
 * @author mmm
 * @see AliyunOssFileStorage
 */
@Configuration
@ConditionalOnProperty(prefix = "storage", name = "type", havingValue = "aliyun-oss")
public class AliyunOssConfig {

    /**
     * 创建阿里云 OSS 客户端 Bean。
     *
     * <p>注意：AccessKey 属于敏感凭据，只从配置读取，绝不硬编码、不打印日志。
     *
     * @param props OSS 配置属性
     * @return OSS 客户端实例（容器关闭时自动 shutdown）
     */
    @Bean(destroyMethod = "shutdown")
    public OSS ossClient(AliyunOssProperties props) {
        // 使用官方构建器创建单例客户端：endpoint + ak + sk
        return new OSSClientBuilder().build(
                props.endpoint(),         // 区域端点
                props.accessKeyId(),      // AccessKey ID
                props.accessKeySecret()   // AccessKey Secret
        );
    }
}
