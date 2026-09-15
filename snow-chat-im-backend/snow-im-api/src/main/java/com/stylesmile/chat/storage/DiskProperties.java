package com.stylesmile.chat.storage;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * 本地磁盘存储配置属性。
 * 对应各环境 yml 中的 {@code disk} 配置段，仅在 {@code storage.type=disk} 时生效。
 *
 * <p>字段说明：
 * <ul>
 *   <li>{@code path}：文件落盘根目录，支持 {@code ~} 展开为当前用户 home；
 *       缺省 {@code ~/snow-file}。</li>
 *   <li>{@code publicUrl}：外部访问前缀（如 {@code http://192.168.0.100:8091}）。
 *       上传后生成的访问地址形如 {@code {publicUrl}/file/raw/{key}}。
 *       之所以必须显式配置，是因为后端无法从一次无请求上下文的调用里推断出
 *       「手机/模拟器真正能访问到本机」的那个地址（127.0.0.1 在真机上不可达）。</li>
 * </ul>
 *
 * @param path      本地磁盘存储根目录
 * @param publicUrl 外部访问前缀，用于拼接 /file/raw/{key} 完整地址
 * @author mmm
 * @see LocalDiskFileStorage
 * @see StorageType
 */
@ConfigurationProperties(prefix = "disk")
public record DiskProperties(
        String path,      // 落盘根目录，支持 ~ 展开
        String publicUrl  // 外部访问前缀，如 http://192.168.0.100:8091
) {
    /** 默认落盘根目录（用户 home 下） */
    private static final String DEFAULT_PATH = "~/snow-file";

    /** 默认外部访问前缀（本机回环，仅服务端自测可用） */
    private static final String DEFAULT_PUBLIC_URL = "http://127.0.0.1:8091";

    /**
     * 紧凑构造器：缺失字段兜底，并把 {@code ~} 展开为 {@code user.home}。
     */
    public DiskProperties {
        if (path == null || path.isBlank()) {
            path = DEFAULT_PATH;
        }
        if (publicUrl == null || publicUrl.isBlank()) {
            publicUrl = DEFAULT_PUBLIC_URL;
        }
        // 去掉结尾多余的斜杠，避免拼接出 //file/raw/... 这种双斜杠地址
        while (publicUrl.endsWith("/")) {
            publicUrl = publicUrl.substring(0, publicUrl.length() - 1);
        }
    }

    /**
     * 返回展开 {@code ~} 之后的落盘根目录。
     *
     * @return 可直接用于创建目录的绝对路径
     */
    public String resolvedPath() {
        return path.startsWith("~")
                ? System.getProperty("user.home") + path.substring(1)
                : path;
    }
}
