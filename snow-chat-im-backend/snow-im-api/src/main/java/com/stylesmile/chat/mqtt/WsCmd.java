package com.stylesmile.chat.mqtt;

/**
 * MQTT 消息命令常量，与 Flutter 端 ws_cmd.dart 保持一致
 */
public final class WsCmd {

    private WsCmd() {
    }

    // ==================== Client → Server (1001-1099) ====================
    /** 登录 */
    public static final int LOGIN = 1001;
    /** 文本消息 */
    public static final int MSG_TEXT = 1002;
    /** 图片消息 */
    public static final int MSG_IMAGE = 1003;
    /** 视频消息 */
    public static final int MSG_VIDEO = 1004;
    /** 好友添加请求 */
    public static final int FRIEND_ADD_REQ = 1006;
    /** 创建群组 */
    public static final int GROUP_CREATE = 1009;
    /** 已读回执 */
    public static final int READ_ACK = 1012;
    /** 接收方确认收到消息（Client→Server） */
    public static final int MSG_RECEIPT = 1013;
    /** 进入聊天页面时请求未推送消息（Client→Server） */
    public static final int FETCH_UNDELIVERED = 1014;

    // ==================== Server → Client (2001-2099) ====================
    /** 消息推送 */
    public static final int MSG_PUSH = 2001;
    /** 好友请求通知 */
    public static final int FRIEND_REQ_NOTIFY = 2002;
    /** 在线状态 */
    public static final int ONLINE_STATUS = 2003;
    /** 群组通知 */
    public static final int GROUP_NOTIFY = 2004;
    /** 消息确认 */
    public static final int MSG_ACK = 2005;
    /** 好友已接受 */
    public static final int FRIEND_ACCEPTED = 2006;
    /** 服务器回执给发送方确认已收到并推送（Server→Client） */
    public static final int MSG_RECEIPT_ACK = 2007;
    /** 服务器推送未推送成功的消息列表（Server→Client） */
    public static final int FETCH_UNDELIVERED_ACK = 2008;
}
