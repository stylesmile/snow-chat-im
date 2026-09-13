// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'SnowChat';

  @override
  String get login => 'Login';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get logout => 'Logout';

  @override
  String get contacts => 'Contacts';

  @override
  String get chat => 'Chat';

  @override
  String get profile => 'Profile';

  @override
  String get addFriend => 'Add Friend';

  @override
  String get sendFriendRequest => 'Send Friend Request';

  @override
  String get accept => 'Accept';

  @override
  String get reject => 'Reject';

  @override
  String get groupName => 'Group Name';

  @override
  String get createGroup => 'Create Group';

  @override
  String get groupMembers => 'Group Members';

  @override
  String get leaveGroup => 'Leave Group';

  @override
  String get textMessage => 'Text Message';

  @override
  String get imageMessage => 'Image';

  @override
  String get videoMessage => 'Video';

  @override
  String get recallMessage => 'Recall';

  @override
  String get searchUser => 'Search';

  @override
  String get searchHint => 'Enter username or nickname';

  @override
  String get online => 'Online';

  @override
  String get offline => 'Offline';

  @override
  String get typing => 'Typing...';

  @override
  String get noMessages => 'No messages yet';

  @override
  String get noContacts => 'No contacts yet';

  @override
  String get fileHelper => 'File Transfer Assistant';

  @override
  String get noGroups => 'No groups yet';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get nickname => 'Nickname';

  @override
  String get signature => 'Signature';

  @override
  String get avatar => 'Avatar';

  @override
  String get friendRequests => 'Friend Requests';

  @override
  String get pendingRequests => 'Pending Requests';

  @override
  String get myFriends => 'My Friends';

  @override
  String get myGroups => 'My Groups';

  @override
  String get messageSent => 'Message sent';

  @override
  String get messageFailed => 'Message failed';

  @override
  String get messageRecalled => 'Message recalled';

  @override
  String get recallFailed => 'Recall failed';

  @override
  String get selectForwardTarget => 'Select a chat';

  @override
  String get loading => 'Loading...';

  @override
  String get error => 'Error';

  @override
  String get confirm => 'Confirm';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Cancel';

  @override
  String get clearChat => 'Clear Chat History';

  @override
  String get clearChatConfirmTitle => 'Clear Chat History';

  @override
  String clearChatConfirmBody(Object name) {
    return 'Clear the chat history with $name? This cannot be undone.';
  }

  @override
  String get clearChatDone => 'Chat history cleared';

  @override
  String get chatSettings => 'Chat Settings';

  @override
  String get reportComplaint => 'Report';

  @override
  String get reportHint => 'Please describe the reason (optional)';

  @override
  String get reportSubmit => 'Submit';

  @override
  String get reportSubmitted => 'We received your report and will handle it soon';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get back => 'Back';

  @override
  String get done => 'Done';

  @override
  String get unknown => 'Unknown';

  @override
  String get userId => 'User ID';

  @override
  String get you => 'You';

  @override
  String get inputMessage => 'Type a message...';

  @override
  String get selectImage => 'Select Image';

  @override
  String get selectVideo => 'Select Video';

  @override
  String get takePhoto => 'Take Photo';

  @override
  String get takeVideo => 'Record Video';

  @override
  String get addMember => 'Add Member';

  @override
  String get removeMember => 'Remove Member';

  @override
  String get invalidUsername => 'Please enter username';

  @override
  String get invalidPassword => 'Please enter password';

  @override
  String get loginFailed => 'Login failed, please try again';

  @override
  String get friendRequestSent => 'Friend request sent';

  @override
  String get friendAdded => 'Friend added';

  @override
  String get groupCreated => 'Group created';

  @override
  String get profileUpdated => 'Profile updated';

  @override
  String get groupJoined => 'Joined group';

  @override
  String get leftGroup => 'Left group';

  @override
  String get friendDeleted => 'Friend deleted';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get enterGroupName => 'Enter group name';

  @override
  String get enterRemark => 'Enter remark';

  @override
  String get enterMessage => 'Enter message';

  @override
  String get systemWelcome => 'Welcome to SnowChat';

  @override
  String get joinedGroup => 'joined the group';

  @override
  String get wasRemoved => 'was removed from the group';

  @override
  String get newFriendRequest => 'New friend request';

  @override
  String get from => 'from';

  @override
  String get remark => 'Remark';

  @override
  String get onlineUsers => 'Online users';

  @override
  String get totalMembers => 'Total members';

  @override
  String get groupNotExist => 'Group not found';

  @override
  String get groupInfo => 'Group Info';

  @override
  String get groupSettings => 'Group Settings';

  @override
  String get remove => 'Remove';

  @override
  String get noAddableFriends => 'No friends can be added';

  @override
  String get selectMembersToAdd => 'Select members to add';

  @override
  String membersAdded(Object count) {
    return 'Added $count member(s)';
  }

  @override
  String removeMemberConfirm(Object name) {
    return 'Remove \"$name\" from the group?';
  }

  @override
  String memberRemoved(Object name) {
    return 'Removed \"$name\" from the group';
  }

  @override
  String peopleCount(Object count) {
    return '$count people';
  }

  @override
  String membersCount(Object count) {
    return 'Members ($count)';
  }

  @override
  String get add => 'Add';

  @override
  String addMembersCount(Object count) {
    return 'Add ($count)';
  }

  @override
  String get chatList => 'Chats';

  @override
  String get recentChats => 'Recent';

  @override
  String get allChats => 'All Chats';

  @override
  String get noMoreMessages => 'No more messages';

  @override
  String get pullToRefresh => 'Pull to refresh';

  @override
  String get releaseToRefresh => 'Release to refresh';

  @override
  String get refreshing => 'Refreshing...';

  @override
  String get copied => 'Copied';

  @override
  String get copy => 'Copy';

  @override
  String get forward => 'Forward';

  @override
  String get reply => 'Reply';

  @override
  String get pin => 'Pin';

  @override
  String get mute => 'Mute';

  @override
  String get unmute => 'Unmute';

  @override
  String get topChat => 'Pin chat';

  @override
  String get untopChat => 'Unpin chat';

  @override
  String get selectContacts => 'Select Contacts';

  @override
  String get selectAll => 'Select All';

  @override
  String get deselectAll => 'Deselect All';

  @override
  String get privacy => 'Privacy';

  @override
  String get blockedUsers => 'Blocked Users';

  @override
  String get readReceipts => 'Read Receipts';

  @override
  String get showOnlineStatus => 'Show Online Status';

  @override
  String get about => 'About';

  @override
  String get sqliteBrowser => 'SQLite Browser';

  @override
  String get total => 'Total';

  @override
  String get page => 'Page';

  @override
  String get noData => 'No data';

  @override
  String get version => 'Version';

  @override
  String get checkUpdate => 'Check for Updates';

  @override
  String get clearCache => 'Clear Cache';

  @override
  String get cacheCleared => 'Cache cleared';

  @override
  String get networkError => 'Network error';

  @override
  String get serverError => 'Server error';

  @override
  String get timeoutError => 'Request timeout';

  @override
  String get unknownError => 'Unknown error';

  @override
  String get welcomeBack => 'Welcome back';

  @override
  String get pleaseLogin => 'Please login';

  @override
  String get register => 'Register';

  @override
  String get email => 'Email';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get invalidEmail => 'Please enter a valid email address';

  @override
  String get passwordNotMatch => 'Passwords do not match';

  @override
  String get registerSuccess => 'Registration successful';

  @override
  String get registerFailed => 'Registration failed, please try again';

  @override
  String get confirmPasswordRequired => 'Please confirm password';

  @override
  String get alreadyHaveAccount => 'Already have an account? Sign in';

  @override
  String get noAccountYet => 'Don\'t have an account? Sign up';

  @override
  String get deleteFriend => 'Delete Friend';

  @override
  String get search => 'Search';

  @override
  String get searchChatHistory => 'Chat History';

  @override
  String get noSearchResult => 'No results found';

  @override
  String get findChatRecord => 'Search chat records';

  @override
  String get friendRequestAccepted => 'Friend request accepted';

  @override
  String get forgotPassword => 'Forgot Password';

  @override
  String get verificationCode => 'Verification Code';

  @override
  String get sendCode => 'Send Code';

  @override
  String get codeSent => 'Code sent, check your email';

  @override
  String get codeSendFailed => 'Failed to send code, please retry';

  @override
  String get codeExpired => 'Code expired or incorrect';

  @override
  String get resetPassword => 'Reset Password';

  @override
  String get newPassword => 'New Password';

  @override
  String get passwordResetSuccess => 'Password reset successfully';

  @override
  String get backToLogin => 'Back to Login';

  @override
  String get wallet => 'Wallet';

  @override
  String get encryptedAssets => 'Crypto Assets';

  @override
  String get winCard => 'WIN Card';

  @override
  String get usdtExchange => 'USDT Exchange Card';

  @override
  String get favorites => 'Favorites';

  @override
  String get moments => 'Moments';

  @override
  String get settingsMenu => 'Settings';

  @override
  String get attach => 'Attach';

  @override
  String get generalSettings => 'General';

  @override
  String get chatBackground => 'Chat Background';

  @override
  String get clearCacheDone => 'Cache cleared';

  @override
  String get chooseFromAlbum => 'Choose from Album';

  @override
  String get resetToDefault => 'Reset to Default';

  @override
  String get holdToTalk => 'Hold to Talk';

  @override
  String get releaseToSend => 'Release to Send';

  @override
  String get releaseToCancel => 'Release to cancel';

  @override
  String get recordingTooShort => 'Recording too short';

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
  String get gender => 'Gender';

  @override
  String get genderMale => 'Male';

  @override
  String get genderFemale => 'Female';

  @override
  String get genderSelect => 'Select Gender';

  @override
  String get favorite => 'Favorite';

  @override
  String get myFavorites => 'My Favorites';

  @override
  String get removeFavorite => 'Remove Favorite';

  @override
  String get favoriteAdded => 'Favorited';

  @override
  String get alreadyFavorited => 'Already favorited';

  @override
  String get favoriteEmpty => 'No favorites';

  @override
  String get scan => 'Scan';

  @override
  String get myQrCode => 'My QR Code';

  @override
  String get findUser => 'User found';

  @override
  String get addToContacts => 'Add to Contacts';

  @override
  String get requestSent => 'Friend request sent';

  @override
  String get invalidQr => 'Unrecognizable QR code';

  @override
  String get scanNotFound => 'User not found';

  @override
  String get scanNetworkError => 'Network error, please try again later';

  @override
  String get scanUserMissing => 'User does not exist';

  @override
  String get alreadyFriend => 'You are already friends';

  @override
  String get scanCameraDenied => 'Camera permission required to scan';

  @override
  String get cannotAddSelf => 'Cannot add yourself';
}
