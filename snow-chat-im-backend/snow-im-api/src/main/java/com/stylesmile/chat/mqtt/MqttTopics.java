package com.stylesmile.chat.mqtt;

public final class MqttTopics {

    private MqttTopics() {
    }

    /**
     * 获取用户 topic
     * @param userId 用户id
     * @return String
     */
    public static String user(Long userId) {
        return "chat/user/" + userId;
    }

    /**
     * 获取群topic
     * @param groupId 群id
     * @return String
     */
    public static String group(Long groupId) {
        return "chat/group/" + groupId;
    }
}
