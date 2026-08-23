-- ----------------------------
-- Chat/IM Schema Initialization
-- ----------------------------

-- ----------------------------
-- Table structure for chat_user
-- ----------------------------
DROP TABLE IF EXISTS `chat_user`;
CREATE TABLE `chat_user`  (
  `id` bigint(0) NOT NULL AUTO_INCREMENT,
  `username` varchar(64) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL,
  `password` varchar(64) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL,
  `nickname` varchar(64) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL,
  `email` varchar(128) CHARACTER SET utf8 COLLATE utf8_general_ci NULL DEFAULT '' COMMENT '邮箱',
  `avatar` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NULL DEFAULT '' COMMENT '头像',
  `signature` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NULL DEFAULT '' COMMENT '个性签名',
  `status` varchar(20) CHARACTER SET utf8 COLLATE utf8_general_ci NULL DEFAULT 'offline' COMMENT 'online/offline/busy',
  `del_flag` int(1) NULL DEFAULT 0 COMMENT '删除标志',
  `create_time` datetime(0) NULL DEFAULT CURRENT_TIMESTAMP(0),
  `update_time` datetime(0) NULL DEFAULT CURRENT_TIMESTAMP(0) ON UPDATE CURRENT_TIMESTAMP(0),
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_username`(`username`) USING BTREE,
  INDEX `idx_username`(`username`) USING BTREE,
  INDEX `idx_email`(`email`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8 COLLATE = utf8_general_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for chat_group
-- ----------------------------
DROP TABLE IF EXISTS `chat_group`;
CREATE TABLE `chat_group`  (
  `id` bigint(0) NOT NULL AUTO_INCREMENT,
  `name` varchar(128) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL,
  `avatar` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NULL DEFAULT '' COMMENT '头像',
  `owner_id` int(0) NOT NULL COMMENT '群主用户ID',
  `max_members` int(0) NULL DEFAULT 500 COMMENT '最大成员数',
  `create_time` datetime(0) NULL DEFAULT CURRENT_TIMESTAMP(0),
  `update_time` datetime(0) NULL DEFAULT CURRENT_TIMESTAMP(0),
  `del_flag` int(0) NULL DEFAULT 0 COMMENT '删除标志',
  PRIMARY KEY (`id`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8 COLLATE = utf8_general_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for chat_group_member
-- ----------------------------
DROP TABLE IF EXISTS `chat_group_member`;
CREATE TABLE `chat_group_member`  (
  `id` bigint(0) NOT NULL AUTO_INCREMENT,
  `group_id` bigint(0) NOT NULL COMMENT '群ID',
  `user_id` bigint(0) NOT NULL COMMENT '用户ID',
  `role` varchar(20) CHARACTER SET utf8 COLLATE utf8_general_ci NULL DEFAULT 'member' COMMENT 'admin/member',
  `join_time` datetime(0) NULL DEFAULT CURRENT_TIMESTAMP(0),
  `mute` int(0) NULL DEFAULT 0 COMMENT '是否禁言',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_group_user`(`group_id`, `user_id`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8 COLLATE = utf8_general_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for chat_friend_request
-- ----------------------------
DROP TABLE IF EXISTS `chat_friend_request`;
CREATE TABLE `chat_friend_request`  (
  `id` bigint(0) NOT NULL AUTO_INCREMENT,
  `from_user_id` bigint(0) NOT NULL COMMENT '发送方用户ID',
  `to_user_id` bigint(0) NOT NULL COMMENT '接收方用户ID',
  `status` varchar(20) CHARACTER SET utf8 COLLATE utf8_general_ci NULL DEFAULT 'pending' COMMENT 'pending/accepted/rejected',
  `remark` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NULL DEFAULT '' COMMENT '备注',
  `create_time` datetime(0) NULL DEFAULT CURRENT_TIMESTAMP(0),
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_from_to`(`from_user_id`, `to_user_id`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8 COLLATE = utf8_general_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for chat_friend
-- ----------------------------
DROP TABLE IF EXISTS `chat_friend`;
CREATE TABLE `chat_friend`  (
  `id` bigint(0) NOT NULL AUTO_INCREMENT,
  `user_id` bigint(0) NOT NULL COMMENT '用户ID',
  `friend_id` bigint(0) NOT NULL COMMENT '好友ID',
  `remark` varchar(100) CHARACTER SET utf8 COLLATE utf8_general_ci NULL DEFAULT '' COMMENT '好友备注',
  `create_time` datetime(0) NULL DEFAULT CURRENT_TIMESTAMP(0),
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_user_friend`(`user_id`, `friend_id`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8 COLLATE = utf8_general_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for chat_message
-- ----------------------------
DROP TABLE IF EXISTS `chat_message`;
CREATE TABLE `chat_message`  (
  `id` bigint(0) NOT NULL AUTO_INCREMENT,
  `from_user_id` bigint(0) NOT NULL COMMENT '发送方用户ID',
  `to_user_id` bigint(0) NULL DEFAULT NULL COMMENT '接收方用户ID，私聊时不为空',
  `group_id` bigint(0) NULL DEFAULT NULL COMMENT '群ID，群聊时不为空',
  `type` varchar(20) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT 'text/image/video/system',
  `content` text CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL,
  `local_seq` int(0) NULL DEFAULT 0 COMMENT '本地序列号',
  `status` varchar(20) CHARACTER SET utf8 COLLATE utf8_general_ci NULL DEFAULT 'sent' COMMENT 'sent/reading/sent/read/failed',
  `create_time` datetime(0) NULL DEFAULT CURRENT_TIMESTAMP(0),
  PRIMARY KEY (`id`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8 COLLATE = utf8_general_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for chat_session
-- ----------------------------
DROP TABLE IF EXISTS `chat_session`;
CREATE TABLE `chat_session`  (
  `id` bigint(0) NOT NULL AUTO_INCREMENT,
  `user_id` bigint(0) NOT NULL COMMENT '用户ID',
  `target_id` bigint(0) NOT NULL COMMENT '会话目标ID（好友ID或群ID）',
  `target_type` varchar(20) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT 'friend/group',
  `last_msg` text CHARACTER SET utf8 COLLATE utf8_general_ci NULL COMMENT '最后一条消息内容',
  `last_msg_time` datetime(0) NULL DEFAULT NULL COMMENT '最后一条消息时间',
  `unread_count` int(0) NULL DEFAULT 0 COMMENT '未读消息数',
  `is_muted` int(0) NULL DEFAULT 0 COMMENT '是否免打扰',
  `update_time` datetime(0) NULL DEFAULT CURRENT_TIMESTAMP(0),
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_user_target`(`user_id`, `target_id`, `target_type`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8 COLLATE = utf8_general_ci ROW_FORMAT = Dynamic;
