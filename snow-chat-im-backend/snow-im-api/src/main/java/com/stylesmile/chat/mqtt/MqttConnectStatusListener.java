package com.stylesmile.chat.mqtt;

import net.dreamlu.iot.mqtt.core.server.event.IMqttConnectStatusListener;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

import javax.annotation.Resource;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

/**
 * MQTT 客户端连接状态监听器，维护在线 clientId 集合
 */
@Component
public class MqttConnectStatusListener implements IMqttConnectStatusListener {

    private static final Logger log = LoggerFactory.getLogger(MqttConnectStatusListener.class);

    private final Set<String> onlineClientIds = ConcurrentHashMap.newKeySet();

    @Autowired(required = false)
    private MqttOfflineMessageDeliver offlineMessageDeliver;

    /**
     * 判断指定 clientId 是否在线
     */
    public boolean isOnline(String clientId) {
        return onlineClientIds.contains(clientId);
    }

    public Set<String> getOnlineClientIds() {
        return onlineClientIds;
    }

    @Override
    public void online(org.tio.core.ChannelContext context, String clientId, String username) {
        onlineClientIds.add(clientId);
        log.debug("MQTT client online: {}", clientId);
        // 投递离线消息
        offlineMessageDeliver.deliverOfflineMessages(clientId);
    }

    @Override
    public void offline(org.tio.core.ChannelContext context, String clientId, String username, String reason) {
        onlineClientIds.remove(clientId);
        log.debug("MQTT client offline: {}, reason: {}", clientId, reason);

    }
}
