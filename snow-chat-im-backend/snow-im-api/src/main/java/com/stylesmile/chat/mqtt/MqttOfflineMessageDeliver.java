package com.stylesmile.chat.mqtt;

import com.stylesmile.chat.entity.ChatOfflineMessage;
import com.stylesmile.chat.mapper.ChatOfflineMessageMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

import javax.annotation.Resource;
import java.util.List;

/**
 * 离线消息投递监听器：用户上线时推送离线消息
 */
@Component
public class MqttOfflineMessageDeliver {

    private static final Logger log = LoggerFactory.getLogger(MqttOfflineMessageDeliver.class);

    @Resource
    private ChatOfflineMessageMapper chatOfflineMessageMapper;

    @Autowired(required = false)
    private MqttPushService mqttPushService;

    /**
     * 用户上线时投递离线消息
     */
    public void deliverOfflineMessages(String clientId) {
        Integer userId = parseUserId(clientId);
        if (userId == null) {
            return;
        }
        try {
            List<ChatOfflineMessage> offlineMessages = chatOfflineMessageMapper.findByToUserId(userId);
            if (offlineMessages == null || offlineMessages.isEmpty()) {
                return;
            }
            for (ChatOfflineMessage msg : offlineMessages) {
                mqttPushService.publishRaw(msg.getTopic(), msg.getPayload());
            }
            chatOfflineMessageMapper.deleteByToUserId(userId);
            log.debug("Delivered {} offline messages to user {}", offlineMessages.size(), userId);
        } catch (Exception e) {
            log.error("Failed to deliver offline messages for user {}", userId, e);
        }
    }

    private Integer parseUserId(String clientId) {
        if (clientId == null || clientId.isEmpty()) {
            return null;
        }
        try {
            // 支持 "user_{userId}" 和 "user_{userId}_chat_*" 两种 clientId 格式
            if (clientId.startsWith("user_")) {
                String rest = clientId.substring(5);
                int underscoreIdx = rest.indexOf('_');
                String idPart = underscoreIdx > 0 ? rest.substring(0, underscoreIdx) : rest;
                return Integer.parseInt(idPart);
            }
            return Integer.parseInt(clientId);
        } catch (NumberFormatException e) {
            log.warn("Cannot parse userId from clientId: {}", clientId);
            return null;
        }
    }
}
