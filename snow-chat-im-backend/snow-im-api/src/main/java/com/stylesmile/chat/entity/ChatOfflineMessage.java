package com.stylesmile.chat.entity;

import lombok.Getter;
import lombok.Setter;

import java.util.Date;

/**
 * 离线消息实体
 * <p>
 * 当用户离线时，系统将 MQTT 消息暂存到数据库，
 * 待用户重新上线后由 {@link com.stylesmile.chat.mqtt.MqttOfflineMessageDeliver} 投递。
 * </p>
 */
@Setter
@Getter
public class ChatOfflineMessage {
    /** 主键 ID */
    private Long id;
    /** 接收者用户 ID */
    private Long toUserId;
    /** MQTT 主题（如 chat/user/{userId}） */
    private String topic;
    /** 消息命令类型（参见 WsCmd） */
    private Integer cmd;
    /** 消息体 JSON（包含 cmd、seq、data） */
    private String payload;
    /** 消息创建时间 */
    private Date createTime;

}
