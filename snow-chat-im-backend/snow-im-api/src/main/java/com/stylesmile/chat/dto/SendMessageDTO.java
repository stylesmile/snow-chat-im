package com.stylesmile.chat.dto;

import com.fasterxml.jackson.annotation.JsonAlias;
import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Getter;
import lombok.Setter;

/**
 * 消息发送DTO类
 *
 * 这个类封装了发送消息所需的所有信息。
 * 使用@JsonAlias注解支持多种字段命名风格（camelCase和snake_case），
 * 提高与不同客户端的兼容性。
 *
 * 字段说明：
 * - fromUserId: 发送者ID，唯一标识发送消息的用户
 * - toUserId: 接收者ID，用于一对一消息，唯一标识接收消息的用户
 * - groupId: 群组ID，用于群聊消息，唯一标识目标群组
 * - type: 消息类型，定义消息的内容格式（text, image, file等）
 * - content: 消息内容，实际传输的文本或数据
 * - localSeq: 本地序列号，用于消息去重和排序
 *
 * 使用示例：
 * ```java
 * SendMessageDTO dto = new SendMessageDTO();
 * dto.setFromUserId(1001L);
 * dto.setToUserId(1002L);
 * dto.setType("text");
 * dto.setContent("Hello, World!");
 * ```
 * 消息发送DTO - 用于封装发送消息的请求数据
 */
@Getter
@Setter
@Schema(description = "消息发送请求DTO")
public class SendMessageDTO {
    /**
     * 发送者用户ID
     *
     * 这个字段标识消息的发送者。在系统中，每个用户都有唯一的ID。
     * 这个ID用于：
     * 1. 验证发送者身份
     * 2. 记录消息来源
     * 3. 更新发送者的最近消息列表
     *
     * 数据库映射：对应chat_message表的sender_id字段
     * 约束：不能为null，必须是有效的用户ID
     *
     * @JsonAlias支持的别名：
     * - "fromUserId": Java标准命名（camelCase）
     * - "from_user_id": Python/Ruby风格命名（snake_case）
     *
     * 这种设计允许不同编程语言的客户端使用各自的命名风格
     */
    @Schema(description = "发送者用户ID", example = "1001", requiredMode = Schema.RequiredMode.REQUIRED)
    @JsonAlias({"fromUserId", "from_user_id"})
    private Long fromUserId;
    /**
     * 接收者用户ID（一对一消息）
     *
     * 这个字段用于私聊消息，标识消息的接收者。
     * 当发送私聊消息时，必须提供这个字段。
     * 当发送群聊消息时，这个字段应该为null。
     *
     * 数据库映射：对应chat_message表的receiver_id字段
     * 约束：与groupId互斥，至少要提供其中一个
     *
     * 业务规则：
     * - 如果toUserId和groupId都不为null，优先处理私聊消息
     * - 如果两者都为null，抛出IllegalArgumentException
     * - 接收者必须是发送者的好友（如果启用了好友验证）
     */
    @Schema(description = "接收者用户ID（一对一消息）", example = "1002")
    @JsonAlias({"toUserId", "to_user_id"})
    private Long toUserId;

    @Schema(description = "群组ID（群聊消息）", example = "2001")
    @JsonAlias({"groupId", "group_id"})
    private Long groupId;
    /**
     * 消息类型
     *
     * 这个字段定义消息的内容格式。不同的类型有不同的处理逻辑：
     *
     * 支持的类型：
     * - "text": 纯文本消息，直接显示
     * - "image": 图片消息，需要下载和显示缩略图
     * - "file": 文件消息，支持下载
     * - "voice": 语音消息，支持播放
     * - "video": 视频消息，支持播放
     * - "location": 位置消息，显示地图
     * - "system": 系统消息，不显示发送者头像
     *
     * 数据库映射：对应chat_message表的type字段
     * 约束：不能为null，必须是支持的类型之一
     *
     * 处理逻辑：
     * - 根据类型选择不同的消息渲染方式
     * - 根据类型决定是否需要额外的元数据
     * - 根据类型选择不同的存储策略
     */
    @Schema(description = "消息类型：text/image/file/video/voice/emoji/self/recall", example = "text")
    @JsonAlias({"type", "msgType"})
    private String type;

    /**
     * 消息内容
     *
     * 这个字段存储实际的消息数据。内容格式取决于type字段：
     *
     * 对于text类型：
     * - 纯文本，支持表情符号
     * - 最大长度：4096字符
     * - 不支持HTML标签（防止XSS攻击）
     *
     * 对于image类型：
     * - 图片的URL或Base64编码
     * - 需要进行图片压缩和缩略图生成
     *
     * 对于file类型：
     * - 文件的URL和元数据（文件名、大小、类型）
     * - 需要进行病毒扫描和文件类型验证
     *
     * 数据库映射：对应chat_message表的content字段（TEXT类型）
     * 约束：不能为null或空字符串
     *
     * 安全考虑：
     * - 对所有内容进行转义，防止XSS攻击
     * - 对文件类型进行白名单验证
     * - 限制内容长度，防止DoS攻击
     */

    @Schema(description = "消息内容", example = "Hello World")
    @JsonAlias({"content"})
    private String content;

    /**
     * 本地序列号
     *
     * 这个字段用于消息去重和排序。客户端在发送消息时生成唯一的序列号，
     * 服务器使用这个序列号来：
     *
     * 1. 消息去重：
     *    - 如果收到相同序列号的消息，忽略重复的消息
     *    - 防止网络抖动导致的重复发送
     *
     * 2. 消息排序：
     *    - 使用序列号对消息进行排序
     *    - 保证消息的顺序性
     *
     * 3. 消息同步：
     *    - 客户端使用序列号进行增量同步
     *    - 服务器返回大于指定序列号的所有新消息
     *
     * 数据库映射：对应chat_message表的local_seq字段
     * 约束：不能为null，每个用户的序列号必须唯一
     *
     * 实现细节：
     * - 序列号由客户端生成，格式为：timestamp * 1000 + random
     * - 服务器不验证序列号的格式，只验证唯一性
     * - 如果序列号重复，返回409 Conflict错误
     */
    @Schema(description = "本地序列号，用于消息去重和排序", example = "1700000000000")
    @JsonAlias({"localSeq", "local_seq"})
    private Long localSeq;
}
