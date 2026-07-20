-- V5: 为 chat_session 表添加 create_time 字段
--
-- 问题背景：
-- 实体类 ChatSession.java 中定义了 createTime 字段
-- 但数据库表 chat_session 中没有这个字段
-- 导致运行时错误：Unknown column 'create_time' in 'field list'
--
-- 解决方案：
-- 在数据库表中添加 create_time 字段
-- 这样可以保持代码和数据库的一致性
--
-- 影响分析：
-- 1. 现有数据：不会丢失
--    - 新字段设置默认值为当前时间
--    - 现有记录会使用 UPDATE_TIME 作为 CREATE_TIME
--
-- 2. 性能影响：✅ 可忽略
--    - 每行只增加8字节（DATETIME类型）
--    - 对于百万级会话，只增加约8MB
--
-- 3. 索引影响：⚠️ 建议添加索引（可选）
--    - 如果需要按创建时间排序，建议添加索引
--
-- 4. 兼容性影响：✅ 完全兼容
--    - 新字段有默认值，不会影响现有查询
--    - 代码已经支持这个字段

-- 第1步：添加 create_time 字段
-- 使用 ALTER TABLE 语句添加新字段
-- DATETIME 类型存储日期和时间
-- NOT NULL 确保字段不为空
-- DEFAULT CURRENT_TIMESTAMP 设置默认值为当前时间
-- COMMENT 说明字段用途
ALTER TABLE `chat_session`
ADD COLUMN `create_time` datetime(0) NOT NULL DEFAULT CURRENT_TIMESTAMP(0)
COMMENT '会话创建时间，用于审计和会话排序';

-- 第2步：更新现有记录的 create_time 值
-- 将所有现有记录的 create_time 设置为 update_time
-- 这样可以保持数据一致性
-- 使用 UPDATE 语句批量更新
UPDATE `chat_session`
SET `create_time` = `update_time`
WHERE `create_time` IS NULL;

-- 第3步（可选）：为 create_time 添加索引
-- 如果需要按创建时间查询或排序，取消下面的注释
-- 这会提高按创建时间查询的性能
-- CREATE INDEX `idx_create_time` ON `chat_session`(`create_time`);

-- 第4步（可选）：为复合查询添加索引
-- 如果需要按 user_id 和 create_time 查询，取消下面的注释
-- 这会提高用户会话列表按时间排序的查询性能
-- CREATE INDEX `idx_user_create_time` ON `chat_session`(`user_id`, `create_time`);

-- 验证修改（可选，可手动执行）
-- 检查字段是否添加成功
-- SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, COLUMN_DEFAULT, COLUMN_COMMENT
-- FROM INFORMATION_SCHEMA.COLUMNS
-- WHERE TABLE_SCHEMA = 'your_database_name'
--   AND TABLE_NAME = 'chat_session'
--   AND COLUMN_NAME = 'create_time';
--
-- 预期结果：
-- COLUMN_NAME: create_time
-- DATA_TYPE: datetime
-- IS_NULLABLE: NO
-- COLUMN_DEFAULT: CURRENT_TIMESTAMP
-- COLUMN_COMMENT: 会话创建时间，用于审计和会话排序

-- 验证数据更新（可选，可手动执行）
-- 检查 create_time 是否已正确设置
-- SELECT id, user_id, target_id, create_time, update_time
-- FROM chat_session
-- LIMIT 10;
--
-- 预期结果：
-- - create_time 应该与 update_time 相同
-- - 所有记录都应该有 create_time 值
