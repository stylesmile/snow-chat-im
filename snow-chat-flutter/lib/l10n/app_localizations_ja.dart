// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'SnowChat';

  @override
  String get login => 'ログイン';

  @override
  String get username => 'ユーザー名';

  @override
  String get password => 'パスワード';

  @override
  String get logout => 'ログアウト';

  @override
  String get contacts => '連絡先';

  @override
  String get chat => 'チャット';

  @override
  String get profile => 'プロフィール';

  @override
  String get addFriend => '友達を追加';

  @override
  String get sendFriendRequest => '友達リクエストを送信';

  @override
  String get accept => '承諾';

  @override
  String get reject => '拒否';

  @override
  String get groupName => 'グループ名';

  @override
  String get createGroup => 'グループを作成';

  @override
  String get groupMembers => 'メンバー';

  @override
  String get leaveGroup => 'グループを退出';

  @override
  String get textMessage => 'テキストメッセージ';

  @override
  String get imageMessage => '画像';

  @override
  String get videoMessage => '動画';

  @override
  String get recallMessage => '取り消し';

  @override
  String get searchUser => '検索';

  @override
  String get searchHint => 'ユーザー名またはニックネームを入力';

  @override
  String get online => 'オンライン';

  @override
  String get offline => 'オフライン';

  @override
  String get typing => '入力中...';

  @override
  String get noMessages => 'メッセージなし';

  @override
  String get noContacts => '連絡先なし';

  @override
  String get fileHelper => 'ファイル転送アシスタント';

  @override
  String get noGroups => 'グループなし';

  @override
  String get settings => '設定';

  @override
  String get language => '言語';

  @override
  String get nickname => 'ニックネーム';

  @override
  String get signature => 'サイン';

  @override
  String get avatar => 'アバター';

  @override
  String get friendRequests => '友達リクエスト';

  @override
  String get pendingRequests => '保留中のリクエスト';

  @override
  String get myFriends => '私の友達';

  @override
  String get myGroups => '私のグループ';

  @override
  String get messageSent => 'メッセージ送信済み';

  @override
  String get messageFailed => 'メッセージ送信失敗';

  @override
  String get messageRecalled => 'メッセージ取り消し済み';

  @override
  String get recallFailed => '取り消し失敗';

  @override
  String get selectForwardTarget => '転送先を選択';

  @override
  String get loading => '読み込み中...';

  @override
  String get error => 'エラー';

  @override
  String get confirm => '確認';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'キャンセル';

  @override
  String get clearChat => 'チャット履歴を消去';

  @override
  String get clearChatConfirmTitle => 'チャット履歴を消去';

  @override
  String clearChatConfirmBody(Object name) {
    return '$name とのチャット履歴を消去しますか？この操作は取り消せません。';
  }

  @override
  String get clearChatDone => 'チャット履歴を消去しました';

  @override
  String get chatSettings => 'チャット設定';

  @override
  String get reportComplaint => '通報';

  @override
  String get reportHint => '通報理由を入力してください（任意）';

  @override
  String get reportSubmit => '通報を送信';

  @override
  String get reportSubmitted => '通報を受け付けました。すぐに確認します';

  @override
  String get save => '保存';

  @override
  String get delete => '削除';

  @override
  String get edit => '編集';

  @override
  String get back => '戻る';

  @override
  String get done => '完了';

  @override
  String get unknown => '不明';

  @override
  String get userId => 'ユーザーID';

  @override
  String get you => 'あなた';

  @override
  String get inputMessage => 'メッセージを入力...';

  @override
  String get selectImage => '画像を選択';

  @override
  String get selectVideo => '動画を選択';

  @override
  String get takePhoto => '写真を撮る';

  @override
  String get takeVideo => '動画を録画';

  @override
  String get addMember => 'メンバーを追加';

  @override
  String get removeMember => 'メンバーを削除';

  @override
  String get invalidUsername => 'ユーザー名を入力してください';

  @override
  String get invalidPassword => 'パスワードを入力してください';

  @override
  String get loginFailed => 'ログインに失敗しました。もう一度お試しください';

  @override
  String get friendRequestSent => '友達リクエストを送信しました';

  @override
  String get friendAdded => '友達を追加しました';

  @override
  String get groupCreated => 'グループを作成しました';

  @override
  String get profileUpdated => 'プロフィールを更新しました';

  @override
  String get groupJoined => 'グループに参加しました';

  @override
  String get leftGroup => 'グループを退出しました';

  @override
  String get friendDeleted => '友達を削除しました';

  @override
  String get today => '今日';

  @override
  String get yesterday => '昨日';

  @override
  String get enterGroupName => 'グループ名を入力してください';

  @override
  String get enterRemark => '備考を入力してください';

  @override
  String get enterMessage => 'メッセージを入力してください';

  @override
  String get systemWelcome => 'SnowChatへようこそ';

  @override
  String get joinedGroup => 'グループに参加しました';

  @override
  String get wasRemoved => 'グループから削除されました';

  @override
  String get newFriendRequest => '新しい友達リクエスト';

  @override
  String get from => 'からの';

  @override
  String get remark => '備考';

  @override
  String get onlineUsers => 'オンラインユーザー';

  @override
  String get totalMembers => '総メンバー数';

  @override
  String get groupNotExist => 'グループが存在しません';

  @override
  String get groupInfo => 'グループ情報';

  @override
  String get groupSettings => 'グループ設定';

  @override
  String get remove => '削除';

  @override
  String get noAddableFriends => '追加できる友達がいません';

  @override
  String get selectMembersToAdd => '追加するメンバーを選択';

  @override
  String membersAdded(Object count) {
    return '$count 人を追加しました';
  }

  @override
  String removeMemberConfirm(Object name) {
    return '\"$name\" をグループから削除しますか？';
  }

  @override
  String memberRemoved(Object name) {
    return '\"$name\" をグループから削除しました';
  }

  @override
  String peopleCount(Object count) {
    return '$count 人';
  }

  @override
  String membersCount(Object count) {
    return 'メンバー ($count)';
  }

  @override
  String get add => '追加';

  @override
  String addMembersCount(Object count) {
    return '追加 ($count)';
  }

  @override
  String get chatList => 'チャット';

  @override
  String get recentChats => '最近のチャット';

  @override
  String get allChats => 'すべてのチャット';

  @override
  String get noMoreMessages => 'これ以上のメッセージはありません';

  @override
  String get pullToRefresh => 'プルして更新';

  @override
  String get releaseToRefresh => 'リリースして更新';

  @override
  String get refreshing => '更新中...';

  @override
  String get copied => 'コピーしました';

  @override
  String get copy => 'コピー';

  @override
  String get forward => '転送';

  @override
  String get reply => '返信';

  @override
  String get pin => 'ピン留め';

  @override
  String get mute => 'ミュート';

  @override
  String get unmute => 'ミュート解除';

  @override
  String get topChat => 'チャットをピン留め';

  @override
  String get untopChat => 'チャットのピン留めを解除';

  @override
  String get selectContacts => '連絡先を選択';

  @override
  String get selectAll => 'すべて選択';

  @override
  String get deselectAll => 'すべて選択解除';

  @override
  String get privacy => 'プライバシー';

  @override
  String get blockedUsers => 'ブロックリスト';

  @override
  String get readReceipts => '既読回执';

  @override
  String get showOnlineStatus => 'オンライン状態を表示';

  @override
  String get about => 'について';

  @override
  String get sqliteBrowser => 'SQLite Browser';

  @override
  String get total => 'Total';

  @override
  String get page => 'Page';

  @override
  String get noData => 'No data';

  @override
  String get version => 'バージョン';

  @override
  String get checkUpdate => 'アップデートを確認';

  @override
  String get clearCache => 'キャッシュをクリア';

  @override
  String get cacheCleared => 'キャッシュをクリアしました';

  @override
  String get networkError => 'ネットワークエラー';

  @override
  String get serverError => 'サーバーエラー';

  @override
  String get timeoutError => 'タイムアウト';

  @override
  String get unknownError => '不明なエラー';

  @override
  String get welcomeBack => 'おかえりなさい';

  @override
  String get pleaseLogin => 'ログインしてください';

  @override
  String get register => '登録';

  @override
  String get email => 'メールアドレス';

  @override
  String get confirmPassword => 'パスワード確認';

  @override
  String get invalidEmail => '有効なメールアドレスを入力してください';

  @override
  String get passwordNotMatch => 'パスワードが一致しません';

  @override
  String get registerSuccess => '登録に成功しました';

  @override
  String get registerFailed => '登録に失敗しました。もう一度お試しください';

  @override
  String get confirmPasswordRequired => 'パスワードを確認してください';

  @override
  String get alreadyHaveAccount => 'アカウントをお持ちですか？サインイン';

  @override
  String get noAccountYet => 'アカウントがありませんか？サインアップ';

  @override
  String get deleteFriend => 'フレンド削除';

  @override
  String get search => '検索';

  @override
  String get searchChatHistory => 'チャット履歴';

  @override
  String get noSearchResult => '該当する結果がありません';

  @override
  String get findChatRecord => 'チャット履歴を検索';

  @override
  String get friendRequestAccepted => '友達リクエストが承認されました';

  @override
  String get forgotPassword => 'パスワードを忘れた';

  @override
  String get verificationCode => '認証コード';

  @override
  String get sendCode => 'コードを送信';

  @override
  String get codeSent => '認証コードを送信しました。メールを確認してください';

  @override
  String get codeSendFailed => 'コードの送信に失敗しました。もう一度お試しください';

  @override
  String get codeExpired => 'コードが無効または期限切れです';

  @override
  String get resetPassword => 'パスワードをリセット';

  @override
  String get newPassword => '新しいパスワード';

  @override
  String get passwordResetSuccess => 'パスワードのリセットに成功しました';

  @override
  String get backToLogin => 'ログインに戻る';

  @override
  String get wallet => 'ウォレット';

  @override
  String get encryptedAssets => '暗号資産';

  @override
  String get winCard => 'WINカード';

  @override
  String get usdtExchange => 'USDT取引所カード';

  @override
  String get favorites => 'お気に入り';

  @override
  String get moments => 'モーメンツ';

  @override
  String get settingsMenu => '設定';

  @override
  String get attach => 'Attach';

  @override
  String get generalSettings => '一般';

  @override
  String get chatBackground => 'チャット背景';

  @override
  String get clearCacheDone => 'キャッシュをクリアしました';

  @override
  String get chooseFromAlbum => 'アルバムから選択';

  @override
  String get resetToDefault => 'デフォルトに戻す';

  @override
  String get holdToTalk => '長押しで話す';

  @override
  String get releaseToSend => '離して送信';

  @override
  String get releaseToCancel => '指を離してキャンセル';

  @override
  String get recordingTooShort => '録音が短すぎます';

  @override
  String get emoji => 'Emoji';

  @override
  String get image => 'Image';

  @override
  String get video => 'Video';

  @override
  String get file => 'File';

  @override
  String get send => 'Send';

  @override
  String get chooseImageSource => 'Choose image source';

  @override
  String get chooseVideoSource => 'Choose video source';

  @override
  String get chooseFileSource => 'Choose file source';

  @override
  String get gallery => 'Gallery';

  @override
  String get camera => 'Camera';

  @override
  String get pickImageFailed => 'Failed to pick image';

  @override
  String get pickVideoFailed => 'Failed to pick video';

  @override
  String get pickFileFailed => 'Failed to pick file';

  @override
  String get uploading => 'Uploading';

  @override
  String get uploadFailed => 'Upload failed';

  @override
  String get voice => 'Voice';

  @override
  String get voicePermissionDenied => 'Microphone permission required to record';

  @override
  String get voiceRecordFailed => 'Recording failed';

  @override
  String get voiceStopFailed => 'Stop recording failed';

  @override
  String get pickAssetFailed => 'Failed to pick media';

  @override
  String get gender => '性別';

  @override
  String get genderMale => '男性';

  @override
  String get genderFemale => '女性';

  @override
  String get genderSelect => '性別を選択';

  @override
  String get favorite => 'お気に入り';

  @override
  String get myFavorites => 'マイお気に入り';

  @override
  String get removeFavorite => 'お気に入り解除';

  @override
  String get favoriteAdded => 'お気に入りに追加しました';

  @override
  String get alreadyFavorited => 'このメッセージは既にお気に入りです';

  @override
  String get favoriteEmpty => 'お気に入りはありません';

  @override
  String get scan => 'スキャン';

  @override
  String get myQrCode => 'マイQRコード';

  @override
  String get findUser => 'ユーザーが見つかりました';

  @override
  String get addToContacts => '連絡先に追加';

  @override
  String get requestSent => '友達リクエストを送信しました';

  @override
  String get invalidQr => '認識できないQRコード';

  @override
  String get scanNotFound => '該当ユーザーが見つかりません';

  @override
  String get scanNetworkError => 'ネットワークエラーです。後でもう一度お試しください';

  @override
  String get scanUserMissing => 'ユーザーは存在しません';

  @override
  String get alreadyFriend => 'すでに友達です';

  @override
  String get scanCameraDenied => 'スキャンにはカメラ権限が必要です';

  @override
  String get cannotAddSelf => '自分を追加することはできません';
}
