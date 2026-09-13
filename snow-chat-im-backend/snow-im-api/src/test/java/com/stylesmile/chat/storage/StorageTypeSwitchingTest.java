package com.stylesmile.chat.storage;

import com.aliyun.oss.OSS;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;

/**
 * 存储实现"按 storage.type 切换"的装配行为测试。
 *
 * <p>这是本次改造的核心回归测试，重点守住两条约束：
 * <ol>
 *   <li><b>同一时刻有且仅有一个 {@link FileStorage} Bean</b>——
 *       旧实现用 {@code minio.enabled}/{@code seaweedfs.enabled} 两个独立开关，
 *       在 {@code storage.type=seaweedfs} 时会把 SeaweedfsFileStorage 与
 *       InMemoryFileStorage 同时装配，导致注入报 NoUniqueBeanDefinitionException；</li>
 *   <li><b>storage.type 与最终装配的实现严格对应</b>，避免"配置写了但没生效"。</li>
 * </ol>
 *
 * @author mmm
 */
class StorageTypeSwitchingTest {

    /**
     * 上下文运行器：注册全部四个存储实现 + 它们所需的依赖 Bean。
     * 依赖用 mock 提供，避免测试真的去连 MinIO / SeaweedFS / 阿里云 OSS。
     */
    private final ApplicationContextRunner runner = new ApplicationContextRunner()
            .withUserConfiguration(
                    StorageDependencyConfig.class,   // 提供各实现所需的配置属性与客户端 mock
                    InMemoryFileStorage.class,       // local
                    MinioFileStorage.class,          // minio
                    SeaweedfsFileStorage.class,      // seaweedfs
                    AliyunOssFileStorage.class       // aliyun-oss
            );

    /**
     * 未配置 storage.type 时应降级为内存存储（保证应用能启动）。
     */
    @Test
    void assemblesInMemoryWhenTypeAbsent() {
        runner.run(context -> {
            // 断言有且仅有一个实现，且是内存实现
            assertThat(context).hasSingleBean(FileStorage.class);
            assertThat(context.getBean(FileStorage.class)).isInstanceOf(InMemoryFileStorage.class);
        });
    }

    /**
     * storage.type=local 时应装配内存存储。
     */
    @Test
    void assemblesInMemoryWhenTypeIsLocal() {
        runner.withPropertyValues("storage.type=local").run(context -> {
            assertThat(context).hasSingleBean(FileStorage.class);
            assertThat(context.getBean(FileStorage.class)).isInstanceOf(InMemoryFileStorage.class);
        });
    }

    /**
     * storage.type=minio 时只装配 MinIO 实现，内存实现必须让位。
     */
    @Test
    void assemblesOnlyMinioWhenTypeIsMinio() {
        runner.withPropertyValues("storage.type=minio").run(context -> {
            assertThat(context).hasSingleBean(FileStorage.class);
            assertThat(context.getBean(FileStorage.class)).isInstanceOf(MinioFileStorage.class);
        });
    }

    /**
     * storage.type=seaweedfs 时只装配 SeaweedFS 实现。
     *
     * <p>这是旧实现会踩坑的场景：旧条件（minio.enabled=false）会让内存实现
     * 与 SeaweedFS 实现同时装配。本用例即为该缺陷的回归防护。
     */
    @Test
    void assemblesOnlySeaweedfsWhenTypeIsSeaweedfs() {
        runner.withPropertyValues("storage.type=seaweedfs").run(context -> {
            assertThat(context).hasSingleBean(FileStorage.class);
            assertThat(context.getBean(FileStorage.class)).isInstanceOf(SeaweedfsFileStorage.class);
        });
    }

    /**
     * storage.type=aliyun-oss 时只装配阿里云 OSS 实现。
     */
    @Test
    void assemblesOnlyAliyunOssWhenTypeIsAliyunOss() {
        runner.withPropertyValues("storage.type=aliyun-oss").run(context -> {
            assertThat(context).hasSingleBean(FileStorage.class);
            assertThat(context.getBean(FileStorage.class)).isInstanceOf(AliyunOssFileStorage.class);
        });
    }

    /**
     * 配置值大小写不敏感：ALIYUN-OSS 同样应命中阿里云 OSS 实现。
     */
    @Test
    void switchingIsCaseInsensitive() {
        runner.withPropertyValues("storage.type=ALIYUN-OSS").run(context -> {
            assertThat(context).hasSingleBean(FileStorage.class);
            assertThat(context.getBean(FileStorage.class)).isInstanceOf(AliyunOssFileStorage.class);
        });
    }

    /**
     * 测试用的依赖配置：提供三个存储实现所需的配置属性与客户端 mock。
     */
    @Configuration
    static class StorageDependencyConfig {

        /**
         * MinIO 配置（字段值本身不影响装配条件，仅保证 Bean 可创建）。
         */
        @Bean
        MinioProperties minioProperties() {
            return new MinioProperties(false, "http://localhost:9000", "ak", "sk",
                    "snow-chat", "", "us-east-1", false);
        }

        /**
         * SeaweedFS 配置。
         */
        @Bean
        SeaweedfsProperties seaweedfsProperties() {
            return new SeaweedfsProperties(false, "http://localhost:8888", "/1", true, "");
        }

        /**
         * 阿里云 OSS 配置。
         */
        @Bean
        AliyunOssProperties aliyunOssProperties() {
            return new AliyunOssProperties("https://oss-cn-hangzhou.aliyuncs.com", "ak", "sk",
                    "snow-chat", "", false, 60);
        }

        /**
         * S3 客户端 mock：MinioFileStorage 构造时会调用 headBucket，mock 返回 null 即视为成功。
         */
        @Bean
        S3Client s3Client() {
            return mock(S3Client.class);
        }

        /**
         * 预签名器 mock。
         */
        @Bean
        S3Presigner s3Presigner() {
            return mock(S3Presigner.class);
        }

        /**
         * 阿里云 OSS 客户端 mock。
         */
        @Bean
        OSS ossClient() {
            return mock(OSS.class);
        }
    }
}
