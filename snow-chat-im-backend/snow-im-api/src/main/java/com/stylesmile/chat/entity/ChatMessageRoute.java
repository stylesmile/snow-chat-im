package com.stylesmile.chat.entity;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

/**
 * 消息分片路由记录。
 *
 * <p>分表之后，「只拿着 messageId」的操作（撤回、已读回执）无法反推消息落在哪张表里，
 * 所以每写一条消息就顺带写一行路由：{@code messageId → (targetType, shardKey)}，
 * 由 {@link com.stylesmile.chat.shard.MessageShardRouter#tableForRoute} 还原表名。
 *
 * <p>ID 就是消息 ID 本身（非自增），由业务侧显式赋值。
 *
 * @author mmm
 */
@Data
@TableName("chat_message_route")
public class ChatMessageRoute {

    /** 消息 ID（与分表里的消息 id 一致） */
    @TableId
    private Long id;

    /** 会话类型：friend / group / file_helper */
    private String targetType;

    /** 分片键：群聊=groupId，私聊=min(双方用户ID) */
    private Long shardKey;
}
