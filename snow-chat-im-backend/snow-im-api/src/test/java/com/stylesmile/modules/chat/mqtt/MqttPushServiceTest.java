package com.stylesmile.modules.chat.mqtt;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.stylesmile.chat.mqtt.MqttPushService;
import net.dreamlu.iot.mqtt.spring.server.MqttServerTemplate;
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
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * MqttPushService 单元测试。
 * <p>
 * 实现已从 paho MqttClient 重构为 mica-mqtt 的 MqttServerTemplate，
 * 因此测试改为 mock MqttServerTemplate，验证 publishAll 调用入参。
 */
@ExtendWith(MockitoExtension.class)
class MqttPushServiceTest {

    // 模拟 mica-mqtt 服务端模板，替代原 paho MqttClient
    @Mock
    private MqttServerTemplate mqttServerTemplate;

    private MqttPushService service;

    @BeforeEach
    void setUp() throws Exception {
        service = new MqttPushService();
        // 注入真实 ObjectMapper，用于将消息信封序列化为 JSON
        ReflectionTestUtils.setField(service, "objectMapper", new ObjectMapper());
        // 注入模拟的 MqttServerTemplate（实现中字段名为 mqttServerTemplate）
        ReflectionTestUtils.setField(service, "mqttServerTemplate", mqttServerTemplate);
    }

    @Test
    void publishesJsonEnvelopeToAllSubscribers() throws Exception {
        // publishAll 返回 true 表示至少有一个订阅者收到了消息
        when(mqttServerTemplate.publishAll(eq("chat/user/42"), any(byte[].class)))
                .thenReturn(true);

        // 调用 publish，内部会序列化为 JSON 信封并调用 publishAll
        service.publish("chat/user/42", 2001, Map.of(
                "fromUserId", 8,
                "content", "hello"
        ));

        // 捕获 publishAll 的 payload 字节数组，用于验证序列化后的 JSON 内容
        ArgumentCaptor<byte[]> captor = ArgumentCaptor.forClass(byte[].class);
        verify(mqttServerTemplate).publishAll(eq("chat/user/42"), captor.capture());

        // 解析 payload 为 JSON 节点，验证信封结构
        JsonNode packet = new ObjectMapper().readTree(
                new String(captor.getValue(), StandardCharsets.UTF_8));
        // cmd 字段必须为 2001
        assertEquals(2001, packet.get("cmd").asInt());
        // seq 为字符串类型（雪花 ID）
        assertTrue(packet.get("seq").isTextual());
        // data.fromUserId 必须为 8
        assertEquals(8, packet.get("data").get("fromUserId").asInt());
        // data.content 必须为 "hello"
        assertEquals("hello", packet.get("data").get("content").asText());
    }
}
