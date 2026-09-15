-- ----------------------------
-- V7: 版本更新表 chat_app_version
-- 用途：App 每次启动调用接口检查是否需要更新，是则弹窗提示并跳转下载地址。
-- ----------------------------
SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

CREATE TABLE IF NOT EXISTS `chat_app_version` (
    `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `app_type` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_520_ci NOT NULL DEFAULT 'android' COMMENT '平台：android/ios/desktop（macos/window）',
    `version` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_520_ci NOT NULL COMMENT '版本号，如 2.1.0（前端做语义化字符串比较）',
    `download_url` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_520_ci DEFAULT '' COMMENT '下载/跳转地址（打开浏览器访问）',
    `update_message` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_520_ci DEFAULT '' COMMENT '更新说明文案',
    `is_notify` tinyint NOT NULL DEFAULT '1' COMMENT '是否提示更新：1=提示 0=不提示',
    `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`id`) USING BTREE,
    KEY `idx_app_type` (`app_type`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_520_ci ROW_FORMAT=DYNAMIC COMMENT='App版本更新表';

-- ----------------------------
-- 默认数据：android / ios / desktop 各插入一条基础记录
-- 默认 version 与当前 App 版本一致（2.0.9），download_url 留空、可手动维护；
-- 这样新装用户不会误弹更新，管理员拿到新包后在库里改 version/download_url 即可触发升级。
-- ----------------------------
INSERT INTO `chat_app_version` (`app_type`, `version`, `download_url`, `update_message`, `is_notify`) VALUES
    ('android', '2.0.9', '', '', 1),
    ('ios',     '2.0.9', '', '', 1),
    ('desktop', '2.0.9', '', '', 1);

SET FOREIGN_KEY_CHECKS = 1;