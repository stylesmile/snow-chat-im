-- 为 chat_user 表添加性别字段
-- gender: 0=未设置, 1=男, 2=女, 默认 NULL 表示未设置
ALTER TABLE `chat_user`
    ADD COLUMN `gender` tinyint DEFAULT NULL COMMENT '性别：0=未设置,1=男,2=女' AFTER `status`;
