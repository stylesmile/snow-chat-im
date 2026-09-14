package com.stylesmile.chat.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.stylesmile.chat.entity.ChatMessage;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

import java.util.List;

/**
 * 消息 mapper。
 *
 * <p>⚠️ 消息表已按「群 / 私聊分片」拆成多张物理表（见
 * {@code com.stylesmile.chat.shard.MessageShardRouter}），因此<b>所有方法第一个参数都是
 * {@code table}</b>（物理表名），XML 里用 {@code ${table}} 拼接。
 *
 * <p>为什么不走 MyBatis-Plus 的实体固定表名 + 动态表名拦截器：
 * 拦截器靠 ThreadLocal 传表名，一旦哪个分支忘了清理就会静默写错表；
 * 显式传参虽然每个方法多一个参数，但调用链上一眼能看出落在哪张表，单测也好断言。
 *
 * <p>表名由路由组件计算得到（前缀 + 数字），不是外部输入，不存在注入风险；
 * XML 里除 {@code ${table}} 外的条件一律用 {@code #{}} 预编译。
 *
 * @author chenye
 * @date 2018/12/10
 */
@Mapper
public interface ChatMessageMapper extends BaseMapper<ChatMessage> {

    /**
     * 写入一条消息到指定分表。
     *
     * <p>ID 由调用方用雪花算法生成后传入（不依赖数据库自增，
     * 分表后各表自增 id 会重复，必须全局唯一）。
     *
     * @param table 物理表名
     * @param m     消息实体（id 必须已赋值）
     * @return 影响行数
     */
    int insertInto(@Param("table") String table, @Param("m") ChatMessage m);

    /**
     * 查询历史消息（按时间倒序，最新在前）。
     *
     * <p>注意 {@code offset} 是<b>偏移量</b>而不是页码：XML 里写的是
     * {@code LIMIT #{offset}, #{size}}，调用方需自己算 {@code (page - 1) * size}。
     * 参数名必须与 XML 占位符一致，否则运行时报
     * {@code BindingException: Parameter 'offset' not found}。
     *
     * @param table      物理表名
     * @param userId     用户ID
     * @param targetId   目标ID
     * @param targetType 目标类型
     * @param offset     偏移量（(page - 1) * size）
     * @param size       每页大小
     * @return 消息列表
     */
    List<ChatMessage> getHistoryMessages(@Param("table") String table,
                                         @Param("userId") Long userId,
                                         @Param("targetId") Long targetId,
                                         @Param("targetType") String targetType,
                                         @Param("offset") int offset,
                                         @Param("size") int size);

    /**
     * 游标分页查询历史消息（只取 id 小于 {@code beforeMessageId} 的）。
     *
     * @param table           物理表名
     * @param userId          用户ID
     * @param targetId        目标ID
     * @param targetType      目标类型
     * @param beforeMessageId 上一页最后一条消息ID，为 null 时从最新开始
     * @param size            每页大小
     * @return 消息列表（倒序）
     */
    List<ChatMessage> getMessagesByCursor(@Param("table") String table,
                                          @Param("userId") Long userId,
                                          @Param("targetId") Long targetId,
                                          @Param("targetType") String targetType,
                                          @Param("beforeMessageId") Long beforeMessageId,
                                          @Param("size") int size);

    /**
     * 按主键查一条消息（撤回、回执等"只知 messageId"的场景，表由路由表定位）。
     *
     * @param table 物理表名
     * @param id    消息ID
     * @return 消息实体，不存在返回 null
     */
    ChatMessage selectByIdFrom(@Param("table") String table, @Param("id") Long id);

    /**
     * 撤回消息：内容替换为"[消息已撤回]"，type 置为 recall。
     *
     * @param table 物理表名
     * @param id    消息ID
     * @return 影响行数
     */
    int recallById(@Param("table") String table, @Param("id") Long id);

    /**
     * 按会话把对方发来的未读消息标记为已读。
     *
     * @param table      物理表名
     * @param userId     当前用户ID（接收方）
     * @param targetId   目标ID
     * @param targetType 目标类型
     * @return 影响行数
     */
    int markRead(@Param("table") String table,
                 @Param("userId") Long userId,
                 @Param("targetId") Long targetId,
                 @Param("targetType") String targetType);

    /**
     * 更新消息推送状态。
     *
     * @param table  物理表名
     * @param id     消息ID
     * @param status 新状态（server_received / delivered ...）
     * @return 影响行数
     */
    int updatePushStatus(@Param("table") String table,
                         @Param("id") Long id,
                         @Param("status") String status);

    /**
     * 查询尚未送达（未 ack / 未 delivered）的消息，用于上线补投。
     *
     * @param table      物理表名
     * @param userId     接收方用户ID
     * @param targetId   目标ID
     * @param targetType 目标类型
     * @return 消息列表（按时间正序）
     */
    List<ChatMessage> selectUndelivered(@Param("table") String table,
                                        @Param("userId") Long userId,
                                        @Param("targetId") Long targetId,
                                        @Param("targetType") String targetType);
}
