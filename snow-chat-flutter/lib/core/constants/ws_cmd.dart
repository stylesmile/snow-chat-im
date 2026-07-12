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

  // Server to Client (2001-2099)
  static const int msgPush = 2001;
  static const int friendReqNotify = 2002;
  static const int onlineStatus = 2003;
  static const int groupNotify = 2004;
  static const int msgAck = 2005;
}
