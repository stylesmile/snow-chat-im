package com.stylesmile.chat.storage;

/**
 * 文件存储类型枚举。
 *
 * <p>对应配置项 {@code storage.type}，是"存储实现按配置切换"的唯一解析入口。
 * 每个枚举值通过 {@link #configValue()} 与各实现类上
 * {@code @ConditionalOnProperty(havingValue = "...")} 的字面量一一对应，
 * 修改配置值时必须同步修改两处，{@code StorageTypeTest#configValueMatchesConditionLiterals}
 * 会守住这条约束。
 *
 * <p>设计取舍：<b>未配置时降级为 {@link #LOCAL}（不报错，保证应用可启动），
 * 但配置了非法值时必须快速失败</b>。因为"配错后静默降级到内存存储"会让线上文件
 * 在重启后全部丢失，这种故障远比启动报错严重。
 *
 * @author mmm
 * @see FileStorage
 */
public enum StorageType {

    /**
     * 本地内存存储（InMemoryFileStorage）。
     * 应用重启后文件丢失，仅用于本地开发与单元测试。
     */
    LOCAL("local"),

    /**
     * 本地磁盘存储（LocalDiskFileStorage）。
     *
     * <p>文件落盘到 {@code disk.path}（默认 {@code ~/snow-file}）并通过
     * {@code GET /file/raw/**} 提供真实 HTTP 访问地址。相比 {@link #LOCAL}
     * 的「内存 + base64 data URL」，它重启不丢文件、消息体只存 URL，
     * 本地联调（尤其真机）时用这个。
     */
    DISK("disk"),

    /**
     * MinIO 对象存储（MinioFileStorage），基于 AWS S3 协议。
     */
    MINIO("minio"),

    /**
     * SeaweedFS 对象存储（SeaweedfsFileStorage），基于其 REST API。
     */
    SEAWEEDFS("seaweedfs"),

    /**
     * 阿里云 OSS 对象存储（AliyunOssFileStorage），基于阿里云官方 SDK。
     */
    ALIYUN_OSS("aliyun-oss");

    /** 配置文件里书写的规范值（与 @ConditionalOnProperty 的 havingValue 一致） */
    private final String configValue;

    /**
     * 枚举构造器。
     *
     * @param configValue 配置文件中使用的值
     */
    StorageType(String configValue) {
        this.configValue = configValue;
    }

    /**
     * 返回该类型在配置文件中的规范值。
     *
     * @return 配置值，如 {@code aliyun-oss}
     */
    public String configValue() {
        return configValue;
    }

    /**
     * 解析 {@code storage.type} 配置值。
     *
     * <p>容错规则：忽略首尾空白、忽略大小写、把下划线视为连字符
     * （兼容 {@code aliyun_oss} 这类写法）。
     *
     * @param raw 原始配置值（可能为 null / 空串 / 空白）
     * @return 对应的存储类型；未配置时返回 {@link #LOCAL}
     * @throws IllegalArgumentException 配置了无法识别的值时抛出，避免静默降级
     */
    public static StorageType of(String raw) {
        // 未配置：安全降级为本地内存存储，保证应用能启动
        if (raw == null || raw.isBlank()) {
            return LOCAL;
        }
        // 归一化：去空白 + 转小写 + 下划线转连字符
        String normalized = raw.trim().toLowerCase().replace('_', '-');
        // 逐个比对规范值
        for (StorageType type : values()) {
            if (type.configValue.equals(normalized)) {
                return type;
            }
        }
        // 未匹配到任何类型：快速失败，附带可选值提示便于排查
        throw new IllegalArgumentException(
                "未知的文件存储类型: " + raw + "，可选值: local / disk / minio / seaweedfs / aliyun-oss");
    }
}
