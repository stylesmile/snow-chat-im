-- chat_group.owner_id 由 int 改为 bigint
--
-- 原因：用户 ID 是雪花 ID（chat_user.id 的 AUTO_INCREMENT 已达 2091818653023719424，
-- 远超 int 上限 2147483647）。owner_id 还是 int 时，大 ID 用户建群会写入失败或被截断，
-- 与实体 ChatGroup.ownerId(Long) 也不匹配。
--
-- 本次一并核对了所有存 ID 的列，其余（chat_message.from_user_id/to_user_id/group_id、
-- chat_session.user_id/target_id、chat_friend.user_id/friend_id、
-- chat_friend_request.from_user_id/to_user_id、chat_group_member.group_id/user_id、
-- chat_offline_message.to_user_id）在 V2 中已经是 bigint，只有这一处遗漏。
ALTER TABLE `chat_group`
    MODIFY COLUMN `owner_id` bigint NOT NULL COMMENT '群主用户ID';
