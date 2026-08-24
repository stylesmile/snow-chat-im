/*
 Navicat Premium Dump SQL

 Source Server         : localhost_3306
 Source Server Type    : MySQL
 Source Server Version : 80046 (8.0.46)
 Source Host           : localhost:3306
 Source Schema         : snow_chat_im

 Target Server Type    : MySQL
 Target Server Version : 80046 (8.0.46)
 File Encoding         : 65001

 Date: 24/08/2026 17:02:01
*/

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ----------------------------
-- Table structure for chat_friend
-- ----------------------------
DROP TABLE IF EXISTS `chat_friend`;
CREATE TABLE `chat_friend` (
                               `id` bigint NOT NULL AUTO_INCREMENT,
                               `user_id` bigint NOT NULL COMMENT '用户ID',
                               `friend_id` bigint NOT NULL COMMENT '好友ID',
                               `remark` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_520_ci DEFAULT '' COMMENT '好友备注',
                               `create_time` datetime DEFAULT CURRENT_TIMESTAMP,
                               PRIMARY KEY (`id`) USING BTREE,
                               UNIQUE KEY `uk_user_friend` (`user_id`,`friend_id`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_520_ci ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for chat_friend_request
-- ----------------------------
DROP TABLE IF EXISTS `chat_friend_request`;
CREATE TABLE `chat_friend_request` (
                                       `id` bigint NOT NULL AUTO_INCREMENT,
                                       `from_user_id` bigint NOT NULL COMMENT '发送方用户ID',
                                       `to_user_id` bigint NOT NULL COMMENT '接收方用户ID',
                                       `status` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_520_ci DEFAULT 'pending' COMMENT 'pending/accepted/rejected',
                                       `remark` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_520_ci DEFAULT '' COMMENT '备注',
                                       `create_time` datetime DEFAULT CURRENT_TIMESTAMP,
                                       PRIMARY KEY (`id`) USING BTREE,
                                       UNIQUE KEY `uk_from_to` (`from_user_id`,`to_user_id`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_520_ci ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for chat_group
-- ----------------------------
DROP TABLE IF EXISTS `chat_group`;
CREATE TABLE `chat_group` (
                              `id` bigint NOT NULL AUTO_INCREMENT,
                              `name` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_520_ci NOT NULL,
                              `avatar` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_520_ci DEFAULT '' COMMENT '头像',
                              `owner_id` int NOT NULL COMMENT '群主用户ID',
                              `max_members` int DEFAULT '500' COMMENT '最大成员数',
                              `create_time` datetime DEFAULT CURRENT_TIMESTAMP,
                              `update_time` datetime DEFAULT CURRENT_TIMESTAMP,
                              `del_flag` int DEFAULT '0' COMMENT '删除标志',
                              PRIMARY KEY (`id`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_520_ci ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for chat_group_member
-- ----------------------------
DROP TABLE IF EXISTS `chat_group_member`;
CREATE TABLE `chat_group_member` (
                                     `id` bigint NOT NULL AUTO_INCREMENT,
                                     `group_id` bigint NOT NULL COMMENT '群ID',
                                     `user_id` bigint NOT NULL COMMENT '用户ID',
                                     `role` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_520_ci DEFAULT 'member' COMMENT 'admin/member',
                                     `join_time` datetime DEFAULT CURRENT_TIMESTAMP,
                                     `mute` int DEFAULT '0' COMMENT '是否禁言',
                                     PRIMARY KEY (`id`) USING BTREE,
                                     UNIQUE KEY `uk_group_user` (`group_id`,`user_id`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_520_ci ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for chat_message
-- ----------------------------
DROP TABLE IF EXISTS `chat_message`;
CREATE TABLE `chat_message` (
                                `id` bigint NOT NULL AUTO_INCREMENT,
                                `from_user_id` bigint NOT NULL COMMENT '发送方用户ID',
                                `to_user_id` bigint DEFAULT NULL COMMENT '接收方用户ID，私聊时不为空',
                                `group_id` bigint DEFAULT NULL COMMENT '群ID，群聊时不为空',
                                `type` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_520_ci NOT NULL COMMENT 'text/image/video/system',
                                `content` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_520_ci NOT NULL COMMENT '消息内容，支持 Emoji（utf8mb4）',
                                `local_seq` bigint DEFAULT '0' COMMENT '本地序列号（支持时间戳格式：timestamp * 1000 + random）',
                                `status` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_520_ci DEFAULT 'sent' COMMENT 'sent/reading/sent/read/failed',
                                `create_time` datetime DEFAULT CURRENT_TIMESTAMP,
                                `push_status` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_520_ci DEFAULT 'pending' COMMENT '推送状态：pending=待推送, server_received=服务器已收到, client_ack=客户端已确认, delivered=已送达',
                                PRIMARY KEY (`id`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_520_ci ROW_FORMAT=DYNAMIC COMMENT='聊天消息表 - 存储所有私聊和群聊消息';

-- ----------------------------
-- Table structure for chat_offline_message
-- ----------------------------
DROP TABLE IF EXISTS `chat_offline_message`;
CREATE TABLE `chat_offline_message` (
                                        `id` bigint NOT NULL AUTO_INCREMENT,
                                        `to_user_id` bigint NOT NULL COMMENT '接收方用户ID',
                                        `topic` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_520_ci NOT NULL COMMENT '原始 topic',
                                        `cmd` int NOT NULL COMMENT '命令码',
                                        `payload` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_520_ci NOT NULL COMMENT '消息 json（含 Emoji 内容）',
                                        `create_time` datetime DEFAULT CURRENT_TIMESTAMP,
                                        PRIMARY KEY (`id`) USING BTREE,
                                        KEY `idx_to_user` (`to_user_id`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_520_ci ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for chat_session
-- ----------------------------
DROP TABLE IF EXISTS `chat_session`;
CREATE TABLE `chat_session` (
                                `id` bigint NOT NULL AUTO_INCREMENT,
                                `user_id` bigint NOT NULL COMMENT '用户ID',
                                `target_id` bigint NOT NULL COMMENT '会话目标ID（好友ID或群ID）',
                                `target_type` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_520_ci NOT NULL COMMENT 'friend/group',
                                `last_msg` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_520_ci COMMENT '最后一条消息内容（支持 Emoji）',
                                `last_msg_time` datetime DEFAULT NULL COMMENT '最后一条消息时间',
                                `unread_count` int DEFAULT '0' COMMENT '未读消息数',
                                `is_muted` int DEFAULT '0' COMMENT '是否免打扰',
                                `update_time` datetime DEFAULT CURRENT_TIMESTAMP,
                                `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '会话创建时间，用于审计和会话排序',
                                PRIMARY KEY (`id`) USING BTREE,
                                UNIQUE KEY `uk_user_target` (`user_id`,`target_id`,`target_type`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_520_ci ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for chat_user
-- ----------------------------
DROP TABLE IF EXISTS `chat_user`;
CREATE TABLE `chat_user` (
                             `id` bigint NOT NULL AUTO_INCREMENT,
                             `username` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_520_ci NOT NULL,
                             `password` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_520_ci NOT NULL,
                             `nickname` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_520_ci NOT NULL,
                             `email` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_520_ci DEFAULT '' COMMENT '邮箱',
                             `avatar` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_520_ci DEFAULT '' COMMENT '头像',
                             `signature` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_520_ci DEFAULT '' COMMENT '个性签名',
                             `status` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_520_ci DEFAULT 'offline' COMMENT 'online/offline/busy',
                             `del_flag` int DEFAULT '0' COMMENT '删除标志',
                             `create_time` datetime DEFAULT CURRENT_TIMESTAMP,
                             `update_time` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                             PRIMARY KEY (`id`) USING BTREE,
                             UNIQUE KEY `uk_username` (`username`) USING BTREE,
                             KEY `idx_username` (`username`) USING BTREE,
                             KEY `idx_email` (`email`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_520_ci ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for chat_verify_code
-- ----------------------------
DROP TABLE IF EXISTS `chat_verify_code`;
CREATE TABLE `chat_verify_code` (
                                    `id` bigint NOT NULL AUTO_INCREMENT,
                                    `email` varchar(128) COLLATE utf8mb4_unicode_520_ci NOT NULL COMMENT '邮箱地址',
                                    `code` varchar(10) COLLATE utf8mb4_unicode_520_ci NOT NULL COMMENT '6位验证码',
                                    `type` varchar(20) COLLATE utf8mb4_unicode_520_ci NOT NULL DEFAULT 'register' COMMENT '验证码类型：register / reset_password',
                                    `expire_time` datetime NOT NULL COMMENT '过期时间',
                                    `used` tinyint NOT NULL DEFAULT '0' COMMENT '是否已使用：0=未使用 1=已使用',
                                    `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                    PRIMARY KEY (`id`) USING BTREE,
                                    KEY `idx_email_type_used` (`email`,`type`,`used`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_520_ci ROW_FORMAT=DYNAMIC;

SET FOREIGN_KEY_CHECKS = 1;
