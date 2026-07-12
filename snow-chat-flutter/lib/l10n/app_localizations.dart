import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
    Locale('ko'),
    Locale('zh'),
    Locale('zh', 'TW')
  ];

  /// 应用标题
  ///
  /// In zh, this message translates to:
  /// **'SnowChat'**
  String get appTitle;

  /// 登录按钮文字
  ///
  /// In zh, this message translates to:
  /// **'登录'**
  String get login;

  /// 用户名输入框标签
  ///
  /// In zh, this message translates to:
  /// **'用户名'**
  String get username;

  /// 密码输入框标签
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get password;

  /// 退出登录按钮
  ///
  /// In zh, this message translates to:
  /// **'退出登录'**
  String get logout;

  /// 通讯录 tab
  ///
  /// In zh, this message translates to:
  /// **'通讯录'**
  String get contacts;

  /// 聊天 tab
  ///
  /// In zh, this message translates to:
  /// **'聊天'**
  String get chat;

  /// 个人中心 tab
  ///
  /// In zh, this message translates to:
  /// **'个人中心'**
  String get profile;

  /// 添加好友
  ///
  /// In zh, this message translates to:
  /// **'添加好友'**
  String get addFriend;

  /// 发送好友请求
  ///
  /// In zh, this message translates to:
  /// **'发送好友请求'**
  String get sendFriendRequest;

  /// 接受
  ///
  /// In zh, this message translates to:
  /// **'接受'**
  String get accept;

  /// 拒绝
  ///
  /// In zh, this message translates to:
  /// **'拒绝'**
  String get reject;

  /// 群名称
  ///
  /// In zh, this message translates to:
  /// **'群名称'**
  String get groupName;

  /// 创建群组
  ///
  /// In zh, this message translates to:
  /// **'创建群组'**
  String get createGroup;

  /// 群成员
  ///
  /// In zh, this message translates to:
  /// **'群成员'**
  String get groupMembers;

  /// 退出群聊
  ///
  /// In zh, this message translates to:
  /// **'退出群聊'**
  String get leaveGroup;

  /// 文本消息类型
  ///
  /// In zh, this message translates to:
  /// **'文本消息'**
  String get textMessage;

  /// 图片消息类型
  ///
  /// In zh, this message translates to:
  /// **'图片消息'**
  String get imageMessage;

  /// 视频消息类型
  ///
  /// In zh, this message translates to:
  /// **'视频消息'**
  String get videoMessage;

  /// 撤回消息
  ///
  /// In zh, this message translates to:
  /// **'撤回消息'**
  String get recallMessage;

  /// 搜索用户
  ///
  /// In zh, this message translates to:
  /// **'搜索用户'**
  String get searchUser;

  /// 搜索输入框提示文字
  ///
  /// In zh, this message translates to:
  /// **'请输入用户名或昵称'**
  String get searchHint;

  /// 在线状态
  ///
  /// In zh, this message translates to:
  /// **'在线'**
  String get online;

  /// 离线状态
  ///
  /// In zh, this message translates to:
  /// **'离线'**
  String get offline;

  /// 对方正在输入
  ///
  /// In zh, this message translates to:
  /// **'正在输入...'**
  String get typing;

  /// 无消息时的提示
  ///
  /// In zh, this message translates to:
  /// **'暂无消息'**
  String get noMessages;

  /// 无联系人时的提示
  ///
  /// In zh, this message translates to:
  /// **'暂无联系人'**
  String get noContacts;

  /// 无群组时的提示
  ///
  /// In zh, this message translates to:
  /// **'暂无群组'**
  String get noGroups;

  /// 设置
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// 语言设置
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get language;

  /// 昵称
  ///
  /// In zh, this message translates to:
  /// **'昵称'**
  String get nickname;

  /// 个性签名
  ///
  /// In zh, this message translates to:
  /// **'个性签名'**
  String get signature;

  /// 头像
  ///
  /// In zh, this message translates to:
  /// **'头像'**
  String get avatar;

  /// 好友请求
  ///
  /// In zh, this message translates to:
  /// **'好友请求'**
  String get friendRequests;

  /// 待处理的好友请求
  ///
  /// In zh, this message translates to:
  /// **'待处理请求'**
  String get pendingRequests;

  /// 我的好友列表
  ///
  /// In zh, this message translates to:
  /// **'我的好友'**
  String get myFriends;

  /// 我的群组列表
  ///
  /// In zh, this message translates to:
  /// **'我的群组'**
  String get myGroups;

  /// 消息发送成功
  ///
  /// In zh, this message translates to:
  /// **'消息已发送'**
  String get messageSent;

  /// 消息发送失败
  ///
  /// In zh, this message translates to:
  /// **'消息发送失败'**
  String get messageFailed;

  /// 消息撤回提示
  ///
  /// In zh, this message translates to:
  /// **'消息已撤回'**
  String get messageRecalled;

  /// 加载状态
  ///
  /// In zh, this message translates to:
  /// **'加载中...'**
  String get loading;

  /// 错误提示
  ///
  /// In zh, this message translates to:
  /// **'错误'**
  String get error;

  /// 确认按钮
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get confirm;

  /// 取消按钮
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// 保存按钮
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

  /// 删除按钮
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get delete;

  /// 编辑按钮
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get edit;

  /// 返回按钮
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get back;

  /// 完成按钮
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get done;

  /// 未知
  ///
  /// In zh, this message translates to:
  /// **'未知'**
  String get unknown;

  /// 自己
  ///
  /// In zh, this message translates to:
  /// **'你'**
  String get you;

  /// 消息输入框提示
  ///
  /// In zh, this message translates to:
  /// **'输入消息...'**
  String get inputMessage;

  /// 选择图片
  ///
  /// In zh, this message translates to:
  /// **'选择图片'**
  String get selectImage;

  /// 选择视频
  ///
  /// In zh, this message translates to:
  /// **'选择视频'**
  String get selectVideo;

  /// 拍照
  ///
  /// In zh, this message translates to:
  /// **'拍照'**
  String get takePhoto;

  /// 录像
  ///
  /// In zh, this message translates to:
  /// **'录像'**
  String get takeVideo;

  /// 添加群成员
  ///
  /// In zh, this message translates to:
  /// **'添加成员'**
  String get addMember;

  /// 移除群成员
  ///
  /// In zh, this message translates to:
  /// **'移除成员'**
  String get removeMember;

  /// 用户名无效提示
  ///
  /// In zh, this message translates to:
  /// **'请输入用户名'**
  String get invalidUsername;

  /// 密码无效提示
  ///
  /// In zh, this message translates to:
  /// **'请输入密码'**
  String get invalidPassword;

  /// 登录失败提示
  ///
  /// In zh, this message translates to:
  /// **'登录失败，请重试'**
  String get loginFailed;

  /// 好友请求发送成功
  ///
  /// In zh, this message translates to:
  /// **'好友请求已发送'**
  String get friendRequestSent;

  /// 好友添加成功
  ///
  /// In zh, this message translates to:
  /// **'好友已添加'**
  String get friendAdded;

  /// 群组创建成功
  ///
  /// In zh, this message translates to:
  /// **'群组已创建'**
  String get groupCreated;

  /// 个人资料更新成功
  ///
  /// In zh, this message translates to:
  /// **'个人资料已更新'**
  String get profileUpdated;

  /// 加入群组成功
  ///
  /// In zh, this message translates to:
  /// **'已加入群组'**
  String get groupJoined;

  /// 退出群组成功
  ///
  /// In zh, this message translates to:
  /// **'已退出群组'**
  String get leftGroup;

  /// 好友删除成功
  ///
  /// In zh, this message translates to:
  /// **'好友已删除'**
  String get friendDeleted;

  /// 今天
  ///
  /// In zh, this message translates to:
  /// **'今天'**
  String get today;

  /// 昨天
  ///
  /// In zh, this message translates to:
  /// **'昨天'**
  String get yesterday;

  /// 群名称输入提示
  ///
  /// In zh, this message translates to:
  /// **'请输入群名称'**
  String get enterGroupName;

  /// 备注输入提示
  ///
  /// In zh, this message translates to:
  /// **'请输入备注'**
  String get enterRemark;

  /// 消息内容输入提示
  ///
  /// In zh, this message translates to:
  /// **'请输入消息内容'**
  String get enterMessage;

  /// 系统欢迎消息
  ///
  /// In zh, this message translates to:
  /// **'欢迎使用 SnowChat'**
  String get systemWelcome;

  /// 加入群组系统消息
  ///
  /// In zh, this message translates to:
  /// **'加入了群组'**
  String get joinedGroup;

  /// 被移出群组系统消息
  ///
  /// In zh, this message translates to:
  /// **'被移出了群组'**
  String get wasRemoved;

  /// 新好友请求通知
  ///
  /// In zh, this message translates to:
  /// **'新的好友请求'**
  String get newFriendRequest;

  /// 来自某人的请求
  ///
  /// In zh, this message translates to:
  /// **'来自'**
  String get from;

  /// 备注
  ///
  /// In zh, this message translates to:
  /// **'备注'**
  String get remark;

  /// 在线人数统计
  ///
  /// In zh, this message translates to:
  /// **'在线人数'**
  String get onlineUsers;

  /// 总成员数
  ///
  /// In zh, this message translates to:
  /// **'总成员数'**
  String get totalMembers;

  /// 会话列表标题
  ///
  /// In zh, this message translates to:
  /// **'会话'**
  String get chatList;

  /// 最近聊天
  ///
  /// In zh, this message translates to:
  /// **'最近聊天'**
  String get recentChats;

  /// 全部会话
  ///
  /// In zh, this message translates to:
  /// **'全部会话'**
  String get allChats;

  /// 加载完所有历史消息
  ///
  /// In zh, this message translates to:
  /// **'没有更多消息了'**
  String get noMoreMessages;

  /// 下拉刷新提示
  ///
  /// In zh, this message translates to:
  /// **'下拉刷新'**
  String get pullToRefresh;

  /// 释放刷新提示
  ///
  /// In zh, this message translates to:
  /// **'释放刷新'**
  String get releaseToRefresh;

  /// 刷新中
  ///
  /// In zh, this message translates to:
  /// **'正在刷新...'**
  String get refreshing;

  /// 复制成功提示
  ///
  /// In zh, this message translates to:
  /// **'已复制'**
  String get copied;

  /// 复制操作
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get copy;

  /// 转发操作
  ///
  /// In zh, this message translates to:
  /// **'转发'**
  String get forward;

  /// 回复操作
  ///
  /// In zh, this message translates to:
  /// **'回复'**
  String get reply;

  /// 置顶操作
  ///
  /// In zh, this message translates to:
  /// **'置顶'**
  String get pin;

  /// 免打扰开关
  ///
  /// In zh, this message translates to:
  /// **'免打扰'**
  String get mute;

  /// 关闭免打扰
  ///
  /// In zh, this message translates to:
  /// **'关闭免打扰'**
  String get unmute;

  /// 聊天置顶
  ///
  /// In zh, this message translates to:
  /// **'聊天置顶'**
  String get topChat;

  /// 聊天取消置顶
  ///
  /// In zh, this message translates to:
  /// **'聊天取消置顶'**
  String get untopChat;

  /// 选择联系人
  ///
  /// In zh, this message translates to:
  /// **'选择联系人'**
  String get selectContacts;

  /// 全选
  ///
  /// In zh, this message translates to:
  /// **'全选'**
  String get selectAll;

  /// 取消全选
  ///
  /// In zh, this message translates to:
  /// **'取消全选'**
  String get deselectAll;

  /// 隐私设置
  ///
  /// In zh, this message translates to:
  /// **'隐私'**
  String get privacy;

  /// 黑名单
  ///
  /// In zh, this message translates to:
  /// **'黑名单'**
  String get blockedUsers;

  /// 已读回执开关
  ///
  /// In zh, this message translates to:
  /// **'已读回执'**
  String get readReceipts;

  /// 显示在线状态开关
  ///
  /// In zh, this message translates to:
  /// **'显示在线状态'**
  String get showOnlineStatus;

  /// 关于页面
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get about;

  /// 版本号
  ///
  /// In zh, this message translates to:
  /// **'版本'**
  String get version;

  /// 检查更新
  ///
  /// In zh, this message translates to:
  /// **'检查更新'**
  String get checkUpdate;

  /// 清除缓存
  ///
  /// In zh, this message translates to:
  /// **'清除缓存'**
  String get clearCache;

  /// 缓存清除成功
  ///
  /// In zh, this message translates to:
  /// **'缓存已清除'**
  String get cacheCleared;

  /// 网络错误提示
  ///
  /// In zh, this message translates to:
  /// **'网络连接异常'**
  String get networkError;

  /// 服务器错误提示
  ///
  /// In zh, this message translates to:
  /// **'服务器错误'**
  String get serverError;

  /// 超时提示
  ///
  /// In zh, this message translates to:
  /// **'请求超时'**
  String get timeoutError;

  /// 未知错误提示
  ///
  /// In zh, this message translates to:
  /// **'未知错误'**
  String get unknownError;

  /// 登录成功欢迎语
  ///
  /// In zh, this message translates to:
  /// **'欢迎回来'**
  String get welcomeBack;

  /// 请登录提示
  ///
  /// In zh, this message translates to:
  /// **'请登录'**
  String get pleaseLogin;

  /// 注册按钮
  ///
  /// In zh, this message translates to:
  /// **'注册'**
  String get register;

  /// 邮箱输入框标签
  ///
  /// In zh, this message translates to:
  /// **'邮箱'**
  String get email;

  /// 确认密码输入框标签
  ///
  /// In zh, this message translates to:
  /// **'确认密码'**
  String get confirmPassword;

  /// 邮箱格式无效提示
  ///
  /// In zh, this message translates to:
  /// **'请输入有效的邮箱地址'**
  String get invalidEmail;

  /// 密码不一致提示
  ///
  /// In zh, this message translates to:
  /// **'两次输入的密码不一致'**
  String get passwordNotMatch;

  /// 注册成功提示
  ///
  /// In zh, this message translates to:
  /// **'注册成功'**
  String get registerSuccess;

  /// 注册失败提示
  ///
  /// In zh, this message translates to:
  /// **'注册失败，请重试'**
  String get registerFailed;

  /// 确认密码必填提示
  ///
  /// In zh, this message translates to:
  /// **'请确认密码'**
  String get confirmPasswordRequired;

  /// 已有账号跳转登录
  ///
  /// In zh, this message translates to:
  /// **'已有账号？去登录'**
  String get alreadyHaveAccount;

  /// 没有账号跳转注册
  ///
  /// In zh, this message translates to:
  /// **'还没有账号？去注册'**
  String get noAccountYet;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'ja', 'ko', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {

  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'zh': {
  switch (locale.countryCode) {
    case 'TW': return AppLocalizationsZhTw();
   }
  break;
   }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'ja': return AppLocalizationsJa();
    case 'ko': return AppLocalizationsKo();
    case 'zh': return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
