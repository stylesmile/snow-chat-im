package com.stylesmile.chat.storage;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * StorageType 枚举的单元测试。
 *
 * <p>StorageType 是"按 storage.type 切换存储实现"的唯一解析入口，
 * 因此必须保证：配置值大小写/空白/下划线容错，未配置时安全降级到 LOCAL，
 * 配置了非法值时快速失败（避免静默降级到内存存储导致线上文件丢失）。
 *
 * @author mmm
 */
class StorageTypeTest {

    /**
     * 精确匹配：aliyun-oss 应解析为 ALIYUN_OSS。
     */
    @Test
    void parsesAliyunOssExactly() {
        // 解析配置文件里书写的规范值
        assertEquals(StorageType.ALIYUN_OSS, StorageType.of("aliyun-oss"),
                "aliyun-oss 应解析为 ALIYUN_OSS");
    }

    /**
     * 大小写不敏感：ALIYUN-OSS / Aliyun-Oss 都应解析成功。
     */
    @Test
    void parsesCaseInsensitively() {
        // 大写形式
        assertEquals(StorageType.ALIYUN_OSS, StorageType.of("ALIYUN-OSS"),
                "大写应能正确解析");
        // 混合大小写形式
        assertEquals(StorageType.ALIYUN_OSS, StorageType.of("Aliyun-Oss"),
                "混合大小写应能正确解析");
    }

    /**
     * 容错：首尾空白与下划线写法都应归一化为连字符形式。
     */
    @Test
    void trimsWhitespaceAndNormalizesUnderscore() {
        // 带首尾空白
        assertEquals(StorageType.ALIYUN_OSS, StorageType.of("  aliyun-oss  "),
                "应忽略首尾空白");
        // 下划线写法（部分运维喜欢写 aliyun_oss）
        assertEquals(StorageType.ALIYUN_OSS, StorageType.of("aliyun_oss"),
                "下划线应归一化为连字符");
    }

    /**
     * 未配置（null / 空串 / 空白）时降级为 LOCAL，保证应用能启动。
     */
    @Test
    void defaultsToLocalWhenMissing() {
        // null 场景
        assertEquals(StorageType.LOCAL, StorageType.of(null), "null 应降级为 LOCAL");
        // 空串场景
        assertEquals(StorageType.LOCAL, StorageType.of(""), "空串应降级为 LOCAL");
        // 全空白场景
        assertEquals(StorageType.LOCAL, StorageType.of("   "), "空白应降级为 LOCAL");
    }

    /**
     * 非法值必须抛异常而非静默降级，避免线上配错后文件写进内存。
     */
    @Test
    void throwsOnUnknownValue() {
        // 断言抛出 IllegalArgumentException
        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class,
                () -> StorageType.of("oss"), "未知类型应抛 IllegalArgumentException");
        // 异常信息应包含非法值，便于排查
        assertTrue(ex.getMessage().contains("oss"), "异常信息应包含非法配置值");
    }

    /**
     * configValue() 必须与 @ConditionalOnProperty 的 havingValue 字面量保持一致，
     * 否则会出现"配置对但 Bean 不装配"的隐蔽故障。
     */
    @Test
    void configValueMatchesConditionLiterals() {
        // 逐个断言四个枚举的配置值
        assertEquals("local", StorageType.LOCAL.configValue(), "local 配置值应为 local");
        assertEquals("disk", StorageType.DISK.configValue(), "disk 配置值应为 disk");
        assertEquals("minio", StorageType.MINIO.configValue(), "minio 配置值应为 minio");
        assertEquals("seaweedfs", StorageType.SEAWEEDFS.configValue(), "seaweedfs 配置值应为 seaweedfs");
        assertEquals("aliyun-oss", StorageType.ALIYUN_OSS.configValue(),
                "阿里云 OSS 配置值应为 aliyun-oss（与 Bean 装配条件一致）");
    }
}
