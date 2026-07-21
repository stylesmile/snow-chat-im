/// WebSocket command codes matching the backend WsCmd constants
class WsCmd {
  // Client to Server (1001-1099)
  static const int login = 1001;
  static const int msgText = 1002;
  static const int msgImage = 1003;
  static const int msgVideo = 1004;
  static const int friendAddReq = 1006;
  static const int groupCreate = 1009;
  static const int readAck = 1012;
  // 接收方确认收到消息（Client→Server）
  static const int msgReceipt = 1013;
  // 进入聊天页面时请求未推送消息（Client→Server）
  static const int fetchUndelivered = 1014;

  // Server to Client (2001-2099)
  static const int msgPush = 2001;
  static const int friendReqNotify = 2002;
  static const int onlineStatus = 2003;
  static const int groupNotify = 2004;
  static const int msgAck = 2005;
  static const int friendAccepted = 2006;
  // 服务器回执给发送方确认已收到并推送（Server→Client）
  static const int msgReceiptAck = 2007;
  // 服务器推送未推送成功的消息列表（Server→Client）
  static const int fetchUndeliveredAck = 2008;
}
