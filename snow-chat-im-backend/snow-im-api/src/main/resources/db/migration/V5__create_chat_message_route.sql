-- 消息分片路由表
--
-- 分表后「只拿着 messageId」的操作（撤回、已读回执）无法反推消息落在哪张物理表里，
-- 因此每写一条消息就顺带写一行路由：messageId → (targetType, shardKey)，
-- 由 MessageShardRouter#tableForRoute 还原出 chat_message_group_N / chat_message_friend_N。
--
-- id 就是消息 ID 本身（业务侧显式赋值，非自增）。
CREATE TABLE IF NOT EXISTS `chat_message_route` (
                                                    `id` bigint NOT NULL COMMENT '消息ID',
                                                    `target_type` varchar(16) NOT NULL COMMENT '会话类型：friend/group/file_helper',
                                                    `shard_key` bigint NOT NULL COMMENT '分片键：群聊=groupId，私聊=min(双方用户ID)',
                                                    `create_time` datetime DEFAULT CURRENT_TIMESTAMP,
                                                    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_520_ci ROW_FORMAT=DYNAMIC
  COMMENT='消息分片路由：messageId 到分表的映射';
