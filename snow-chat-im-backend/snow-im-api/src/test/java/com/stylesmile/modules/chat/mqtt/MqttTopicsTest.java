package com.stylesmile.modules.chat.mqtt;

import com.stylesmile.chat.mqtt.MqttTopics;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;

class MqttTopicsTest {

    @Test
    void buildsUserTopic() {
        assertEquals("chat/user/42", MqttTopics.user(42));
    }

    @Test
    void buildsGroupTopic() {
        assertEquals("chat/group/7", MqttTopics.group(7));
    }
}
