package com.stylesmile.modules.chat.mqtt;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.stylesmile.chat.mqtt.MqttPushService;
import org.eclipse.paho.client.mqttv3.MqttClient;
import org.eclipse.paho.client.mqttv3.MqttMessage;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.nio.charset.StandardCharsets;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class MqttPushServiceTest {

    @Mock
    private MqttClient client;

    private MqttPushService service;

    @BeforeEach
    void setUp() throws Exception {
        service = new MqttPushService(new ObjectMapper());
        ReflectionTestUtils.setField(service, "client", client);
        when(client.isConnected()).thenReturn(true);
    }

    @Test
    void publishesJsonEnvelopeWithQosOne() throws Exception {
        service.publish("chat/user/42", 2001, Map.of(
                "fromUserId", 8,
                "content", "hello"
        ));

        ArgumentCaptor<MqttMessage> captor = ArgumentCaptor.forClass(MqttMessage.class);
        verify(client).publish(eq("chat/user/42"), captor.capture());

        MqttMessage message = captor.getValue();
        JsonNode packet = new ObjectMapper().readTree(
                new String(message.getPayload(), StandardCharsets.UTF_8));
        assertEquals(2001, packet.get("cmd").asInt());
        assertTrue(packet.get("seq").isTextual());
        assertEquals(8, packet.get("data").get("fromUserId").asInt());
        assertEquals("hello", packet.get("data").get("content").asText());
        assertEquals(1, message.getQos());
        assertFalse(message.isRetained());
    }
}
