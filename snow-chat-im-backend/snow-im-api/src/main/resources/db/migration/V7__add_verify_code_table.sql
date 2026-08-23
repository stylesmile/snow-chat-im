-- 验证码表：用于邮箱注册验证和找回密码
-- Verify code table: used for email registration verification and password reset

CREATE TABLE IF NOT EXISTS `chat_verify_code` (
  `id`          bigint          NOT NULL AUTO_INCREMENT,
  `email`       VARCHAR(128) NOT NULL                COMMENT '邮箱地址',
  `code`        VARCHAR(10)  NOT NULL                COMMENT '6位验证码',
  `type`        VARCHAR(20)  NOT NULL DEFAULT 'register' COMMENT '验证码类型：register / reset_password',
  `expire_time` DATETIME     NOT NULL                COMMENT '过期时间',
  `used`        TINYINT      NOT NULL DEFAULT 0      COMMENT '是否已使用：0=未使用 1=已使用',
  `create_time` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_email_type_used` (`email`, `type`, `used`) USING BTREE
) ENGINE=InnoDB CHARACTER SET=utf8 COLLATE=utf8_general_ci ROW_FORMAT=Dynamic;
