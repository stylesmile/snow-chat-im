-- 修复 local_seq 字段类型，从 INT 改为 BIGINT
-- 原因：客户端生成的序列号格式为 timestamp * 1000 + random
-- 当前时间戳已经超过INT范围，需要使用BIGINT支持更大的数值
--
-- 时间线：
-- - 2024-07-20: 发现local_seq字段溢出问题
-- - 修复方案：将INT改为BIGINT（最大值：9,223,372,036,854,775,807）
-- - BIGINT可以支持到公元292,278,994年
--
-- 影响分析：
-- - 现有数据：不会丢失，INT值可以无缝转换为BIGINT
-- - 索引：需要重建（如果存在local_seq的索引）
-- - 性能：BIGINT占用8字节，比INT的4字节多，但现代硬件影响可忽略

-- 修改 chat_message 表的 local_seq 字段
ALTER TABLE `chat_message`
MODIFY COLUMN `local_seq` bigint(0) NULL DEFAULT 0 COMMENT '本地序列号（支持时间戳格式：timestamp * 1000 + random）';

-- 添加注释说明字段用途和约束
ALTER TABLE `chat_message`
COMMENT = '聊天消息表 - 存储所有私聊和群聊消息';

-- 如果需要为local_seq添加索引（用于消息同步和去重查询），可以取消下面的注释：
-- CREATE INDEX `idx_local_seq` ON `chat_message`(`local_seq`);
-- CREATE INDEX `idx_sender_local_seq` ON `chat_message`(`from_user_id`, `local_seq`);

-- 验证修改（可选）
-- SELECT COLUMN_TYPE, IS_NULLABLE, COLUMN_DEFAULT
-- FROM INFORMATION_SCHEMA.COLUMNS
-- WHERE TABLE_SCHEMA = 'your_database_name'
--   AND TABLE_NAME = 'chat_message'
--   AND COLUMN_NAME = 'local_seq';
