package com.stylesmile.chat.mqtt;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.annotation.PreDestroy;
import org.eclipse.paho.client.mqttv3.MqttClient;
import org.eclipse.paho.client.mqttv3.MqttConnectOptions;
import org.eclipse.paho.client.mqttv3.MqttMessage;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Service;

import java.nio.charset.StandardCharsets;
import java.util.Map;
import java.util.UUID;

@Service
public class MqttPushService {

    private static final Logger log = LoggerFactory.getLogger(MqttPushService.class);

    private final ObjectMapper objectMapper;

    @Value("${chat.mqtt.broker-url:tcp://127.0.0.1:1883}")
    private String brokerUrl;

    @Value("${chat.mqtt.username:}")
    private String username;

    @Value("${chat.mqtt.password:}")
    private String password;

    private MqttClient client;

    public MqttPushService(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }

    @EventListener(ApplicationReadyEvent.class)
    public void connect() {
        try {
            client = new MqttClient(brokerUrl, "snow-im-" + UUID.randomUUID());
            MqttConnectOptions options = new MqttConnectOptions();
            options.setAutomaticReconnect(true);
            options.setCleanSession(true);
            options.setConnectionTimeout(10);
            if (!username.isBlank()) {
                options.setUserName(username);
                options.setPassword(password.toCharArray());
            }
            client.connect(options);
            log.info("MQTT publisher connected to {}", brokerUrl);
        } catch (Exception e) {
            log.error("Failed to connect MQTT publisher to {}", brokerUrl, e);
        }
    }

    public void publish(String topic, int cmd, Map<String, Object> data) {
        if (client == null || !client.isConnected()) {
            log.warn("Skipping MQTT message because publisher is disconnected: {}", topic);
            return;
        }
        try {
            String payload = objectMapper.writeValueAsString(Map.of(
                    "cmd", cmd,
                    "seq", UUID.randomUUID().toString(),
                    "data", data
            ));
            MqttMessage message = new MqttMessage(payload.getBytes(StandardCharsets.UTF_8));
            message.setQos(1);
            message.setRetained(false);
            client.publish(topic, message);
        } catch (JsonProcessingException e) {
            log.error("Failed to serialize MQTT message for {}", topic, e);
        } catch (Exception e) {
            log.error("Failed to publish MQTT message to {}", topic, e);
        }
    }

    @PreDestroy
    public void disconnect() {
        if (client != null) {
            try {
                client.disconnect();
                client.close();
            } catch (Exception e) {
                log.warn("Failed to close MQTT publisher", e);
            }
        }
    }
}
