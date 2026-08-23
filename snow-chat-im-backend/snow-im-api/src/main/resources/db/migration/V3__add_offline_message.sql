-- ----------------------------
-- 离线消息表
-- ----------------------------
DROP TABLE IF EXISTS `chat_offline_message`;
CREATE TABLE `chat_offline_message` (
  `id` bigint(0) NOT NULL AUTO_INCREMENT,
  `to_user_id` bigint(0) NOT NULL COMMENT '接收方用户ID',
  `topic` varchar(128) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '原始 topic',
  `cmd` int(0) NOT NULL COMMENT '命令码',
  `payload` text CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '消息 json',
  `create_time` datetime(0) NULL DEFAULT CURRENT_TIMESTAMP(0),
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_to_user`(`to_user_id`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8 COLLATE = utf8_general_ci ROW_FORMAT = Dynamic;
