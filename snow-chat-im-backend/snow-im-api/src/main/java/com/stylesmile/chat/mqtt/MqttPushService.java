package com.stylesmile.chat.mqtt;

import cn.hutool.core.util.IdUtil;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import net.dreamlu.iot.mqtt.spring.server.MqttServerTemplate;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.nio.charset.StandardCharsets;
import java.util.Map;
import java.util.UUID;

/**
 * MQTT 消息推送服务。
 * <p>
 * 直接使用 mica-mqtt 内置的 {@link MqttServerTemplate} 在 broker 内部投递消息，
 * 无需再用 paho 客户端建立额外的 TCP 连接，避免因连接失败导致消息全部丢失。
 */
@Service
public class MqttPushService {

    private static final Logger log = LoggerFactory.getLogger(MqttPushService.class);

    @Autowired(required = false)
    private ObjectMapper objectMapper;

    @Autowired(required = false)
    private MqttServerTemplate mqttServerTemplate;



    public void publish(String topic, int cmd, Map<String, Object> data) {
        try {
            String payload = objectMapper.writeValueAsString(Map.of(
                    "cmd", cmd,
                    "seq", IdUtil.getSnowflakeNextIdStr(),
                    "data", data
            ));
            publishRaw(topic, payload);
        } catch (JsonProcessingException e) {
            log.error("Failed to serialize MQTT message for {}", topic, e);
        }
    }

    public void publishRaw(String topic, String payload) {
        try {
            boolean ok = mqttServerTemplate.publishAll(
                    topic,
                    payload.getBytes(StandardCharsets.UTF_8)
            );
            log.info("MQTT publish topic={}, payloadLen={}, hasSubscribers={}", topic, payload.length(), ok);
        } catch (Exception e) {
            log.error("Failed to publish MQTT message to {}", topic, e);
        }
    }
}
