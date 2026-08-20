/// WebSocket 指令码，与后端 [WsCmd] 常量一一对应
/// WebSocket command codes, matching the backend WsCmd constants one-to-one.
class WsCmd {
  // -------------------------------------------------------------------------
  // 客户端 → 服务端（编号范围 1001–1099）
  // Client → Server (range 1001–1099)

  /// 用户登录
  /// User login
  static const int login = 1001;

  /// 发送文本消息
  /// Send text message
  static const int msgText = 1002;

  /// 发送图片消息
  /// Send image message
  static const int msgImage = 1003;

  /// 发送视频消息
  /// Send video message
  static const int msgVideo = 1004;

  /// 发送好友申请
  /// Send friend request
  static const int friendAddReq = 1006;

  /// 创建群组
  /// Create group
  static const int groupCreate = 1009;

  /// 消息已读回执
  /// Message read acknowledgment
  static const int readAck = 1012;

  /// 接收方确认收到消息（Client → Server）
  /// Receiver confirms message received (Client → Server)
  static const int msgReceipt = 1013;

  /// 进入聊天页面时请求未推送消息（Client → Server）
  /// Request undelivered messages when entering chat page (Client → Server)
  static const int fetchUndelivered = 1014;

  // -------------------------------------------------------------------------
  // 服务端 → 客户端（编号范围 2001–2099）
  // Server → Client (range 2001–2099)

  /// 服务器主动推送消息
  /// Server-initiated message push
  static const int msgPush = 2001;

  /// 好友申请通知
  /// Friend request notification
  static const int friendReqNotify = 2002;

  /// 在线状态变更
  /// Online status change
  static const int onlineStatus = 2003;

  /// 群组变动通知
  /// Group change notification
  static const int groupNotify = 2004;

  /// 消息发送成功回执
  /// Message sent acknowledgment
  static const int msgAck = 2005;

  /// 好友申请被接受
  /// Friend request accepted
  static const int friendAccepted = 2006;

  /// 服务器回执给发送方，确认已收到并推送（Server → Client）
  /// Server acknowledges receipt and push to sender (Server → Client)
  static const int msgReceiptAck = 2007;

  /// 服务器推送未推送成功的消息列表（Server → Client）
  /// Server pushes list of undelivered messages (Server → Client)
  static const int fetchUndeliveredAck = 2008;
}
