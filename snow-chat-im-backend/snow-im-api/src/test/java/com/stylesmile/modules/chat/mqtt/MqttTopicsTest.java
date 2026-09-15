package com.stylesmile.modules.chat.mqtt;

import com.stylesmile.chat.mqtt.MqttTopics;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;

class MqttTopicsTest {

    @Test
    void buildsUserTopic() {
        // MqttTopics.user 签名期望 Long
        assertEquals("chat/user/42", MqttTopics.user(42L));
    }

    @Test
    void buildsGroupTopic() {
        // MqttTopics.group 签名期望 Long
        assertEquals("chat/group/7", MqttTopics.group(7L));
    }
}
