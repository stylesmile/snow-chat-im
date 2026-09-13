package com.stylesmile.chat.storage;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * 文件存储类型配置（{@code storage.type}）。
 *
 * <p>本类存在的意义是<b>启动期快速失败</b>：{@code @ConditionalOnProperty} 遇到无法识别的
 * storage.type 时只会"谁都不装配"，最终表现为一个语义模糊的
 * {@code NoSuchBeanDefinitionException}；而这里通过 {@link StorageType#of(String)}
 * 提前校验并抛出带可选值提示的异常，让配置错误一眼可见。
 *
 * <p>同时把解析结果打进启动日志，便于线上确认"当前到底用的哪套存储"。
 *
 * @author mmm
 * @see StorageType
 */
@ConfigurationProperties(prefix = "storage")
public class StorageProperties {

    /** 日志器 */
    private static final Logger log = LoggerFactory.getLogger(StorageProperties.class);

    /** 解析后的存储类型（未配置时降级为 LOCAL） */
    private final StorageType type;

    /**
     * 构造器绑定：Spring 把 {@code storage.type} 的原始字符串传进来后立即解析。
     *
     * @param type 原始配置值（可为 null，表示未配置）
     * @throws IllegalArgumentException 配置了无法识别的存储类型时抛出
     */
    public StorageProperties(String type) {
        // 解析并校验（非法值在此处快速失败，而非等到 Bean 缺失才报错）
        this.type = StorageType.of(type);
        // 打印解析结果，便于排障（不含任何敏感信息）
        log.info("File storage type resolved: {} (raw config value: '{}')",
                this.type.configValue(), type == null ? "<absent>" : type);
    }

    /**
     * 获取解析后的存储类型。
     *
     * @return 存储类型枚举，永不为 null
     */
    public StorageType type() {
        return type;
    }
}
