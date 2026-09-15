package com.stylesmile.chat.mqtt;

import net.dreamlu.iot.mqtt.core.server.auth.IMqttServerAuthHandler;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * MQTT 服务端认证处理器
 */
@Component
public class MqttAuthHandler implements IMqttServerAuthHandler {

    @Value("${chat.mqtt.username:mica}")
    private String mqttUsername;

    @Value("${chat.mqtt.password:123456}")
    private String mqttPassword;


    @Override
    public boolean verifyAuthenticate(org.tio.core.ChannelContext context, String uniqueId, String clientId, String userName, String password) {
        return IMqttServerAuthHandler.super.verifyAuthenticate(context, uniqueId, clientId, userName, password);
    }

    @Override
    public boolean authenticate(org.tio.core.ChannelContext context, String uniqueId, String clientId, String userName, String password) {
        // 未配置认证时允许所有连接
        if (mqttUsername == null || mqttUsername.isEmpty()) {
            return true;
        }
        return mqttUsername.equals(userName) && mqttPassword.equals(password);
    }
}
