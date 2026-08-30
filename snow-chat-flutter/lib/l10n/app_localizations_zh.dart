// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'SnowChat';

  @override
  String get login => '登录';

  @override
  String get username => '用户名';

  @override
  String get password => '密码';

  @override
  String get logout => '退出登录';

  @override
  String get contacts => '通讯录';

  @override
  String get chat => '聊天';

  @override
  String get profile => '个人中心';

  @override
  String get addFriend => '添加好友';

  @override
  String get sendFriendRequest => '发送好友请求';

  @override
  String get accept => '接受';

  @override
  String get reject => '拒绝';

  @override
  String get groupName => '群名称';

  @override
  String get createGroup => '创建群组';

  @override
  String get groupMembers => '群成员';

  @override
  String get leaveGroup => '退出群聊';

  @override
  String get textMessage => '文本消息';

  @override
  String get imageMessage => '图片消息';

  @override
  String get videoMessage => '视频消息';

  @override
  String get recallMessage => '撤回消息';

  @override
  String get searchUser => '搜索用户';

  @override
  String get searchHint => '请输入用户名或昵称';

  @override
  String get online => '在线';

  @override
  String get offline => '离线';

  @override
  String get typing => '正在输入...';

  @override
  String get noMessages => '暂无消息';

  @override
  String get noContacts => '暂无联系人';

  @override
  String get fileHelper => '文件传输助手';

  @override
  String get noGroups => '暂无群组';

  @override
  String get settings => '设置';

  @override
  String get language => '语言';

  @override
  String get nickname => '昵称';

  @override
  String get signature => '个性签名';

  @override
  String get avatar => '头像';

  @override
  String get friendRequests => '好友请求';

  @override
  String get pendingRequests => '待处理请求';

  @override
  String get myFriends => '我的好友';

  @override
  String get myGroups => '我的群组';

  @override
  String get messageSent => '消息已发送';

  @override
  String get messageFailed => '消息发送失败';

  @override
  String get messageRecalled => '消息已撤回';

  @override
  String get recallFailed => '撤回失败';

  @override
  String get selectForwardTarget => '选择转发对象';

  @override
  String get loading => '加载中...';

  @override
  String get error => '错误';

  @override
  String get confirm => '确定';

  @override
  String get ok => '确定';

  @override
  String get cancel => '取消';

  @override
  String get clearChat => '清空聊天记录';

  @override
  String get clearChatConfirmTitle => '清空聊天记录';

  @override
  String clearChatConfirmBody(Object name) {
    return '确定清空与 $name 的聊天记录吗？清空后无法恢复。';
  }

  @override
  String get clearChatDone => '聊天记录已清空';

  @override
  String get save => '保存';

  @override
  String get delete => '删除';

  @override
  String get edit => '编辑';

  @override
  String get back => '返回';

  @override
  String get done => '完成';

  @override
  String get unknown => '未知';

  @override
  String get you => '你';

  @override
  String get inputMessage => '输入消息...';

  @override
  String get selectImage => '选择图片';

  @override
  String get selectVideo => '选择视频';

  @override
  String get takePhoto => '拍照';

  @override
  String get takeVideo => '录像';

  @override
  String get addMember => '添加成员';

  @override
  String get removeMember => '移除成员';

  @override
  String get invalidUsername => '请输入用户名';

  @override
  String get invalidPassword => '请输入密码';

  @override
  String get loginFailed => '登录失败，请重试';

  @override
  String get friendRequestSent => '好友请求已发送';

  @override
  String get friendAdded => '好友已添加';

  @override
  String get groupCreated => '群组已创建';

  @override
  String get profileUpdated => '个人资料已更新';

  @override
  String get groupJoined => '已加入群组';

  @override
  String get leftGroup => '已退出群组';

  @override
  String get friendDeleted => '好友已删除';

  @override
  String get today => '今天';

  @override
  String get yesterday => '昨天';

  @override
  String get enterGroupName => '请输入群名称';

  @override
  String get enterRemark => '请输入备注';

  @override
  String get enterMessage => '请输入消息内容';

  @override
  String get systemWelcome => '欢迎使用 SnowChat';

  @override
  String get joinedGroup => '加入了群组';

  @override
  String get wasRemoved => '被移出了群组';

  @override
  String get newFriendRequest => '新的好友请求';

  @override
  String get from => '来自';

  @override
  String get remark => '备注';

  @override
  String get onlineUsers => '在线人数';

  @override
  String get totalMembers => '总成员数';

  @override
  String get chatList => '会话';

  @override
  String get recentChats => '最近聊天';

  @override
  String get allChats => '全部会话';

  @override
  String get noMoreMessages => '没有更多消息了';

  @override
  String get pullToRefresh => '下拉刷新';

  @override
  String get releaseToRefresh => '释放刷新';

  @override
  String get refreshing => '正在刷新...';

  @override
  String get copied => '已复制';

  @override
  String get copy => '复制';

  @override
  String get forward => '转发';

  @override
  String get reply => '回复';

  @override
  String get pin => '置顶';

  @override
  String get mute => '免打扰';

  @override
  String get unmute => '关闭免打扰';

  @override
  String get topChat => '聊天置顶';

  @override
  String get untopChat => '聊天取消置顶';

  @override
  String get selectContacts => '选择联系人';

  @override
  String get selectAll => '全选';

  @override
  String get deselectAll => '取消全选';

  @override
  String get privacy => '隐私';

  @override
  String get blockedUsers => '黑名单';

  @override
  String get readReceipts => '已读回执';

  @override
  String get showOnlineStatus => '显示在线状态';

  @override
  String get about => '关于';

  @override
  String get sqliteBrowser => 'SQLite 浏览器';

  @override
  String get total => '共';

  @override
  String get page => '页';

  @override
  String get noData => '暂无数据';

  @override
  String get version => '版本';

  @override
  String get checkUpdate => '检查更新';

  @override
  String get clearCache => '清除缓存';

  @override
  String get cacheCleared => '缓存已清除';

  @override
  String get networkError => '网络连接异常';

  @override
  String get serverError => '服务器错误';

  @override
  String get timeoutError => '请求超时';

  @override
  String get unknownError => '未知错误';

  @override
  String get welcomeBack => '欢迎回来';

  @override
  String get pleaseLogin => '请登录';

  @override
  String get register => '注册';

  @override
  String get email => '邮箱';

  @override
  String get confirmPassword => '确认密码';

  @override
  String get invalidEmail => '请输入有效的邮箱地址';

  @override
  String get passwordNotMatch => '两次输入的密码不一致';

  @override
  String get registerSuccess => '注册成功';

  @override
  String get registerFailed => '注册失败，请重试';

  @override
  String get confirmPasswordRequired => '请确认密码';

  @override
  String get alreadyHaveAccount => '已有账号？去登录';

  @override
  String get noAccountYet => '还没有账号？去注册';

  @override
  String get deleteFriend => 'Delete Friend';

  @override
  String get search => '搜索';

  @override
  String get friendRequestAccepted => '已通过好友申请';

  @override
  String get forgotPassword => '忘记密码';

  @override
  String get verificationCode => '验证码';

  @override
  String get sendCode => '发送验证码';

  @override
  String get codeSent => '验证码已发送，请查收邮件';

  @override
  String get codeSendFailed => '验证码发送失败，请重试';

  @override
  String get codeExpired => '验证码错误或已过期';

  @override
  String get resetPassword => '重置密码';

  @override
  String get newPassword => '新密码';

  @override
  String get passwordResetSuccess => '密码重置成功';

  @override
  String get backToLogin => '返回登录';

  @override
  String get wallet => '钱包';

  @override
  String get encryptedAssets => '加密资产';

  @override
  String get winCard => 'WIN卡';

  @override
  String get usdtExchange => 'USDT 交易所卡';

  @override
  String get favorites => '收藏';

  @override
  String get moments => '朋友圈';

  @override
  String get settingsMenu => '设置';

  @override
  String get attach => '附件';

  @override
  String get emoji => '表情';

  @override
  String get image => '图片';

  @override
  String get video => '视频';

  @override
  String get file => '文件';

  @override
  String get send => '发送';

  @override
  String get chooseImageSource => '选择图片来源';

  @override
  String get chooseVideoSource => '选择视频来源';

  @override
  String get chooseFileSource => '选择文件来源';

  @override
  String get gallery => '相册';

  @override
  String get camera => '相机';

  @override
  String get pickImageFailed => '选择图片失败';

  @override
  String get pickVideoFailed => '选择视频失败';

  @override
  String get pickFileFailed => '选择文件失败';

  @override
  String get uploading => '上传中';

  @override
  String get uploadFailed => '上传失败';

  @override
  String get voice => '语音';

  @override
  String get voicePermissionDenied => '需要麦克风权限才能录音';

  @override
  String get voiceRecordFailed => '录音失败';

  @override
  String get voiceStopFailed => '停止录音失败';

  @override
  String get pickAssetFailed => '选择媒体失败';

  @override
  String get gender => '性别';

  @override
  String get genderMale => '男';

  @override
  String get genderFemale => '女';

  @override
  String get genderSelect => '选择性别';

  @override
  String get favorite => '收藏';

  @override
  String get myFavorites => '我的收藏';

  @override
  String get removeFavorite => '取消收藏';

  @override
  String get favoriteAdded => '已收藏';

  @override
  String get alreadyFavorited => '该消息已收藏';

  @override
  String get favoriteEmpty => '暂无收藏';
}

/// The translations for Chinese, as used in Taiwan (`zh_TW`).
class AppLocalizationsZhTw extends AppLocalizationsZh {
  AppLocalizationsZhTw(): super('zh_TW');

  @override
  String get appTitle => 'SnowChat';

  @override
  String get login => '登入';

  @override
  String get username => '使用者名稱';

  @override
  String get password => '密碼';

  @override
  String get logout => '登出';

  @override
  String get contacts => '通訊錄';

  @override
  String get chat => '聊天';

  @override
  String get profile => '個人中心';

  @override
  String get addFriend => '添加好友';

  @override
  String get sendFriendRequest => '發送好友請求';

  @override
  String get accept => '接受';

  @override
  String get reject => '拒絕';

  @override
  String get groupName => '群組名稱';

  @override
  String get createGroup => '建立群組';

  @override
  String get groupMembers => '群組成員';

  @override
  String get leaveGroup => '退出群組';

  @override
  String get textMessage => '文字訊息';

  @override
  String get imageMessage => '圖片訊息';

  @override
  String get videoMessage => '影片訊息';

  @override
  String get recallMessage => '撤回訊息';

  @override
  String get searchUser => '搜尋使用者';

  @override
  String get searchHint => '請輸入使用者名稱或暱稱';

  @override
  String get online => '線上';

  @override
  String get offline => '離線';

  @override
  String get typing => '正在輸入...';

  @override
  String get noMessages => '暫無訊息';

  @override
  String get noContacts => '暫無聯絡人';

  @override
  String get fileHelper => '檔案傳輸助手';

  @override
  String get noGroups => '暫無群組';

  @override
  String get settings => '設定';

  @override
  String get language => '語言';

  @override
  String get nickname => '暱稱';

  @override
  String get signature => '個性簽名';

  @override
  String get avatar => '頭像';

  @override
  String get friendRequests => '好友請求';

  @override
  String get pendingRequests => '待處理請求';

  @override
  String get myFriends => '我的好友';

  @override
  String get myGroups => '我的群組';

  @override
  String get messageSent => '訊息已發送';

  @override
  String get messageFailed => '訊息發送失敗';

  @override
  String get messageRecalled => '訊息已撤回';

  @override
  String get recallFailed => '撤回失敗';

  @override
  String get selectForwardTarget => '選擇轉發對象';

  @override
  String get loading => '載入中...';

  @override
  String get error => '錯誤';

  @override
  String get confirm => '確定';

  @override
  String get ok => '確定';

  @override
  String get cancel => '取消';

  @override
  String get clearChat => '清空聊天記錄';

  @override
  String get clearChatConfirmTitle => '清空聊天記錄';

  @override
  String clearChatConfirmBody(Object name) {
    return '確定清空與 $name 的聊天記錄嗎？清空後無法恢復。';
  }

  @override
  String get clearChatDone => '聊天記錄已清空';

  @override
  String get save => '儲存';

  @override
  String get delete => '刪除';

  @override
  String get edit => '編輯';

  @override
  String get back => '返回';

  @override
  String get done => '完成';

  @override
  String get unknown => '未知';

  @override
  String get you => '你';

  @override
  String get inputMessage => '輸入訊息...';

  @override
  String get selectImage => '選擇圖片';

  @override
  String get selectVideo => '選擇影片';

  @override
  String get takePhoto => '拍照';

  @override
  String get takeVideo => '錄影';

  @override
  String get addMember => '新增成員';

  @override
  String get removeMember => '移除成員';

  @override
  String get invalidUsername => '請輸入使用者名稱';

  @override
  String get invalidPassword => '請輸入密碼';

  @override
  String get loginFailed => '登入失敗，請重試';

  @override
  String get friendRequestSent => '好友請求已發送';

  @override
  String get friendAdded => '好友已新增';

  @override
  String get groupCreated => '群組已建立';

  @override
  String get profileUpdated => '個人資料已更新';

  @override
  String get groupJoined => '已加入群組';

  @override
  String get leftGroup => '已退出群組';

  @override
  String get friendDeleted => '好友已刪除';

  @override
  String get today => '今天';

  @override
  String get yesterday => '昨天';

  @override
  String get enterGroupName => '請輸入群組名稱';

  @override
  String get enterRemark => '請輸入備註';

  @override
  String get enterMessage => '請輸入訊息內容';

  @override
  String get systemWelcome => '歡迎使用 SnowChat';

  @override
  String get joinedGroup => '加入了群組';

  @override
  String get wasRemoved => '被移出了群組';

  @override
  String get newFriendRequest => '新的好友請求';

  @override
  String get from => '來自';

  @override
  String get remark => '備註';

  @override
  String get onlineUsers => '線上人數';

  @override
  String get totalMembers => '總成員數';

  @override
  String get chatList => '會話';

  @override
  String get recentChats => '最近聊天';

  @override
  String get allChats => '全部會話';

  @override
  String get noMoreMessages => '沒有更多訊息了';

  @override
  String get pullToRefresh => '下拉重新整理';

  @override
  String get releaseToRefresh => '釋放重新整理';

  @override
  String get refreshing => '正在重新整理...';

  @override
  String get copied => '已複製';

  @override
  String get copy => '複製';

  @override
  String get forward => '轉發';

  @override
  String get reply => '回覆';

  @override
  String get pin => '置頂';

  @override
  String get mute => '靜音';

  @override
  String get unmute => '取消靜音';

  @override
  String get topChat => '聊天置頂';

  @override
  String get untopChat => '聊天取消置頂';

  @override
  String get selectContacts => '選擇聯絡人';

  @override
  String get selectAll => '全選';

  @override
  String get deselectAll => '取消全選';

  @override
  String get privacy => '隱私';

  @override
  String get blockedUsers => '黑名單';

  @override
  String get readReceipts => '已讀回执';

  @override
  String get showOnlineStatus => '顯示線上狀態';

  @override
  String get about => '關於';

  @override
  String get version => '版本';

  @override
  String get checkUpdate => '檢查更新';

  @override
  String get clearCache => '清除快取';

  @override
  String get cacheCleared => '快取已清除';

  @override
  String get networkError => '網路連線異常';

  @override
  String get serverError => '伺服器錯誤';

  @override
  String get timeoutError => '請求逾時';

  @override
  String get unknownError => '未知錯誤';

  @override
  String get welcomeBack => '歡迎回來';

  @override
  String get pleaseLogin => '請登入';

  @override
  String get register => '註冊';

  @override
  String get email => '信箱';

  @override
  String get confirmPassword => '確認密碼';

  @override
  String get invalidEmail => '請輸入有效的信箱地址';

  @override
  String get passwordNotMatch => '兩次輸入的密碼不一致';

  @override
  String get registerSuccess => '註冊成功';

  @override
  String get registerFailed => '註冊失敗，請重試';

  @override
  String get confirmPasswordRequired => '請確認密碼';

  @override
  String get alreadyHaveAccount => '已有帳號？去登入';

  @override
  String get noAccountYet => '還沒有帳號？去註冊';

  @override
  String get deleteFriend => '刪除好友';

  @override
  String get search => '搜尋';

  @override
  String get friendRequestAccepted => '已通過好友申請';

  @override
  String get forgotPassword => '忘記密碼';

  @override
  String get verificationCode => '驗證碼';

  @override
  String get sendCode => '發送驗證碼';

  @override
  String get codeSent => '驗證碼已發送，請查收郵件';

  @override
  String get codeSendFailed => '驗證碼發送失敗，請重試';

  @override
  String get codeExpired => '驗證碼錯誤或已過期';

  @override
  String get resetPassword => '重置密碼';

  @override
  String get newPassword => '新密碼';

  @override
  String get passwordResetSuccess => '密碼重置成功';

  @override
  String get backToLogin => '返回登入';

  @override
  String get wallet => '錢包';

  @override
  String get encryptedAssets => '加密資產';

  @override
  String get winCard => 'WIN卡';

  @override
  String get usdtExchange => 'USDT 交易所卡';

  @override
  String get favorites => '收藏';

  @override
  String get moments => '朋友圈';

  @override
  String get settingsMenu => '設定';

  @override
  String get gender => '性別';

  @override
  String get genderMale => '男';

  @override
  String get genderFemale => '女';

  @override
  String get genderSelect => '選擇性別';

  @override
  String get favorite => '收藏';

  @override
  String get myFavorites => '我的收藏';

  @override
  String get removeFavorite => '取消收藏';

  @override
  String get favoriteAdded => '已收藏';

  @override
  String get alreadyFavorited => '該消息已收藏';

  @override
  String get favoriteEmpty => '暫無收藏';
}
