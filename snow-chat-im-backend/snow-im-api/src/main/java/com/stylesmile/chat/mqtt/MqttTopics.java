package com.stylesmile.chat.mqtt;

public final class MqttTopics {

    private MqttTopics() {
    }

    public static String user(Integer userId) {
        return "chat/user/" + userId;
    }

    public static String group(Integer groupId) {
        return "chat/group/" + groupId;
    }
}
