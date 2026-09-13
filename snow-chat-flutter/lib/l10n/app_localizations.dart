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

  /// App title
  ///
  /// In en, this message translates to:
  /// **'SnowChat'**
  String get appTitle;

  /// Login button
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// Username field
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// Password field
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// Logout button
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// Contacts tab
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get contacts;

  /// Chat tab
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chat;

  /// Profile tab
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// Add friend
  ///
  /// In en, this message translates to:
  /// **'Add Friend'**
  String get addFriend;

  /// Send friend request
  ///
  /// In en, this message translates to:
  /// **'Send Friend Request'**
  String get sendFriendRequest;

  /// Accept
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// Reject
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// Group name
  ///
  /// In en, this message translates to:
  /// **'Group Name'**
  String get groupName;

  /// Create group
  ///
  /// In en, this message translates to:
  /// **'Create Group'**
  String get createGroup;

  /// Group members
  ///
  /// In en, this message translates to:
  /// **'Group Members'**
  String get groupMembers;

  /// Leave group
  ///
  /// In en, this message translates to:
  /// **'Leave Group'**
  String get leaveGroup;

  /// Text message type
  ///
  /// In en, this message translates to:
  /// **'Text Message'**
  String get textMessage;

  /// Image message type
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get imageMessage;

  /// Video message type
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get videoMessage;

  /// Recall message
  ///
  /// In en, this message translates to:
  /// **'Recall'**
  String get recallMessage;

  /// Search users
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchUser;

  /// Search hint
  ///
  /// In en, this message translates to:
  /// **'Enter username or nickname'**
  String get searchHint;

  /// Online status
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// Offline status
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// User is typing
  ///
  /// In en, this message translates to:
  /// **'Typing...'**
  String get typing;

  /// No messages
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get noMessages;

  /// No contacts
  ///
  /// In en, this message translates to:
  /// **'No contacts yet'**
  String get noContacts;

  /// File transfer assistant entry title
  ///
  /// In en, this message translates to:
  /// **'File Transfer Assistant'**
  String get fileHelper;

  /// No groups
  ///
  /// In en, this message translates to:
  /// **'No groups yet'**
  String get noGroups;

  /// Settings
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Language setting
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Nickname
  ///
  /// In en, this message translates to:
  /// **'Nickname'**
  String get nickname;

  /// Personal signature
  ///
  /// In en, this message translates to:
  /// **'Signature'**
  String get signature;

  /// Avatar
  ///
  /// In en, this message translates to:
  /// **'Avatar'**
  String get avatar;

  /// Friend requests
  ///
  /// In en, this message translates to:
  /// **'Friend Requests'**
  String get friendRequests;

  /// Pending friend requests
  ///
  /// In en, this message translates to:
  /// **'Pending Requests'**
  String get pendingRequests;

  /// My friends list
  ///
  /// In en, this message translates to:
  /// **'My Friends'**
  String get myFriends;

  /// My groups list
  ///
  /// In en, this message translates to:
  /// **'My Groups'**
  String get myGroups;

  /// Message sent successfully
  ///
  /// In en, this message translates to:
  /// **'Message sent'**
  String get messageSent;

  /// Message send failed
  ///
  /// In en, this message translates to:
  /// **'Message failed'**
  String get messageFailed;

  /// Message recalled
  ///
  /// In en, this message translates to:
  /// **'Message recalled'**
  String get messageRecalled;

  /// Recall failed
  ///
  /// In en, this message translates to:
  /// **'Recall failed'**
  String get recallFailed;

  /// Forward target picker title
  ///
  /// In en, this message translates to:
  /// **'Select a chat'**
  String get selectForwardTarget;

  /// Loading state
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// Error
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// Confirm button
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// OK button
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// Cancel button
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Clear chat history action
  ///
  /// In en, this message translates to:
  /// **'Clear Chat History'**
  String get clearChat;

  /// Clear chat history confirmation title
  ///
  /// In en, this message translates to:
  /// **'Clear Chat History'**
  String get clearChatConfirmTitle;

  /// Clear chat history confirmation body, {name} is the conversation name
  ///
  /// In en, this message translates to:
  /// **'Clear the chat history with {name}? This cannot be undone.'**
  String clearChatConfirmBody(Object name);

  /// Clear success toast
  ///
  /// In en, this message translates to:
  /// **'Chat history cleared'**
  String get clearChatDone;

  /// Single chat settings page title
  ///
  /// In en, this message translates to:
  /// **'Chat Settings'**
  String get chatSettings;

  /// Complaint entry
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get reportComplaint;

  /// Report dialog input hint
  ///
  /// In en, this message translates to:
  /// **'Please describe the reason (optional)'**
  String get reportHint;

  /// Submit report button
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get reportSubmit;

  /// Report submitted success toast
  ///
  /// In en, this message translates to:
  /// **'We received your report and will handle it soon'**
  String get reportSubmitted;

  /// Save button
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Delete button
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Edit button
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// Back button
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// Done button
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// Unknown
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// User ID label
  ///
  /// In en, this message translates to:
  /// **'User ID'**
  String get userId;

  /// Self reference
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get you;

  /// Message input hint
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get inputMessage;

  /// Select image
  ///
  /// In en, this message translates to:
  /// **'Select Image'**
  String get selectImage;

  /// Select video
  ///
  /// In en, this message translates to:
  /// **'Select Video'**
  String get selectVideo;

  /// Take photo
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get takePhoto;

  /// Record video
  ///
  /// In en, this message translates to:
  /// **'Record Video'**
  String get takeVideo;

  /// Add group member
  ///
  /// In en, this message translates to:
  /// **'Add Member'**
  String get addMember;

  /// Remove group member
  ///
  /// In en, this message translates to:
  /// **'Remove Member'**
  String get removeMember;

  /// Invalid username
  ///
  /// In en, this message translates to:
  /// **'Please enter username'**
  String get invalidUsername;

  /// Invalid password
  ///
  /// In en, this message translates to:
  /// **'Please enter password'**
  String get invalidPassword;

  /// Login failed
  ///
  /// In en, this message translates to:
  /// **'Login failed, please try again'**
  String get loginFailed;

  /// Friend request sent successfully
  ///
  /// In en, this message translates to:
  /// **'Friend request sent'**
  String get friendRequestSent;

  /// Friend added successfully
  ///
  /// In en, this message translates to:
  /// **'Friend added'**
  String get friendAdded;

  /// Group created successfully
  ///
  /// In en, this message translates to:
  /// **'Group created'**
  String get groupCreated;

  /// Profile updated successfully
  ///
  /// In en, this message translates to:
  /// **'Profile updated'**
  String get profileUpdated;

  /// Joined group successfully
  ///
  /// In en, this message translates to:
  /// **'Joined group'**
  String get groupJoined;

  /// Left group successfully
  ///
  /// In en, this message translates to:
  /// **'Left group'**
  String get leftGroup;

  /// Friend deleted successfully
  ///
  /// In en, this message translates to:
  /// **'Friend deleted'**
  String get friendDeleted;

  /// Today
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// Yesterday
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// Group name input hint
  ///
  /// In en, this message translates to:
  /// **'Enter group name'**
  String get enterGroupName;

  /// Remark input hint
  ///
  /// In en, this message translates to:
  /// **'Enter remark'**
  String get enterRemark;

  /// Message input hint
  ///
  /// In en, this message translates to:
  /// **'Enter message'**
  String get enterMessage;

  /// System welcome message
  ///
  /// In en, this message translates to:
  /// **'Welcome to SnowChat'**
  String get systemWelcome;

  /// Joined group system message
  ///
  /// In en, this message translates to:
  /// **'joined the group'**
  String get joinedGroup;

  /// Removed from group system message
  ///
  /// In en, this message translates to:
  /// **'was removed from the group'**
  String get wasRemoved;

  /// New friend request notification
  ///
  /// In en, this message translates to:
  /// **'New friend request'**
  String get newFriendRequest;

  /// From someone
  ///
  /// In en, this message translates to:
  /// **'from'**
  String get from;

  /// Remark
  ///
  /// In en, this message translates to:
  /// **'Remark'**
  String get remark;

  /// Online user count
  ///
  /// In en, this message translates to:
  /// **'Online users'**
  String get onlineUsers;

  /// Total member count
  ///
  /// In en, this message translates to:
  /// **'Total members'**
  String get totalMembers;

  /// No description provided for @groupNotExist.
  ///
  /// In en, this message translates to:
  /// **'Group not found'**
  String get groupNotExist;

  /// No description provided for @groupInfo.
  ///
  /// In en, this message translates to:
  /// **'Group Info'**
  String get groupInfo;

  /// No description provided for @groupSettings.
  ///
  /// In en, this message translates to:
  /// **'Group Settings'**
  String get groupSettings;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @noAddableFriends.
  ///
  /// In en, this message translates to:
  /// **'No friends can be added'**
  String get noAddableFriends;

  /// No description provided for @selectMembersToAdd.
  ///
  /// In en, this message translates to:
  /// **'Select members to add'**
  String get selectMembersToAdd;

  /// No description provided for @membersAdded.
  ///
  /// In en, this message translates to:
  /// **'Added {count} member(s)'**
  String membersAdded(Object count);

  /// No description provided for @removeMemberConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{name}\" from the group?'**
  String removeMemberConfirm(Object name);

  /// No description provided for @memberRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed \"{name}\" from the group'**
  String memberRemoved(Object name);

  /// No description provided for @peopleCount.
  ///
  /// In en, this message translates to:
  /// **'{count} people'**
  String peopleCount(Object count);

  /// No description provided for @membersCount.
  ///
  /// In en, this message translates to:
  /// **'Members ({count})'**
  String membersCount(Object count);

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @addMembersCount.
  ///
  /// In en, this message translates to:
  /// **'Add ({count})'**
  String addMembersCount(Object count);

  /// Chat list title
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get chatList;

  /// Recent chats
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get recentChats;

  /// All chats
  ///
  /// In en, this message translates to:
  /// **'All Chats'**
  String get allChats;

  /// All messages loaded
  ///
  /// In en, this message translates to:
  /// **'No more messages'**
  String get noMoreMessages;

  /// Pull to refresh hint
  ///
  /// In en, this message translates to:
  /// **'Pull to refresh'**
  String get pullToRefresh;

  /// Release to refresh hint
  ///
  /// In en, this message translates to:
  /// **'Release to refresh'**
  String get releaseToRefresh;

  /// Refreshing
  ///
  /// In en, this message translates to:
  /// **'Refreshing...'**
  String get refreshing;

  /// Copy successful
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// Copy action
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// Forward action
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get forward;

  /// Reply action
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get reply;

  /// Pin action
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get pin;

  /// Mute notifications
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get mute;

  /// Unmute notifications
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get unmute;

  /// Pin chat
  ///
  /// In en, this message translates to:
  /// **'Pin chat'**
  String get topChat;

  /// Unpin chat
  ///
  /// In en, this message translates to:
  /// **'Unpin chat'**
  String get untopChat;

  /// Select contacts
  ///
  /// In en, this message translates to:
  /// **'Select Contacts'**
  String get selectContacts;

  /// Select all
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get selectAll;

  /// Deselect all
  ///
  /// In en, this message translates to:
  /// **'Deselect All'**
  String get deselectAll;

  /// Privacy settings
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// Blocked users list
  ///
  /// In en, this message translates to:
  /// **'Blocked Users'**
  String get blockedUsers;

  /// Read receipts toggle
  ///
  /// In en, this message translates to:
  /// **'Read Receipts'**
  String get readReceipts;

  /// Show online status toggle
  ///
  /// In en, this message translates to:
  /// **'Show Online Status'**
  String get showOnlineStatus;

  /// About page
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// SQLite browser title
  ///
  /// In en, this message translates to:
  /// **'SQLite Browser'**
  String get sqliteBrowser;

  /// Total row count
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// Pagination label
  ///
  /// In en, this message translates to:
  /// **'Page'**
  String get page;

  /// No data placeholder
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get noData;

  /// Version number
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// Check for updates
  ///
  /// In en, this message translates to:
  /// **'Check for Updates'**
  String get checkUpdate;

  /// Settings page clear cache entry
  ///
  /// In en, this message translates to:
  /// **'Clear Cache'**
  String get clearCache;

  /// Cache cleared successfully
  ///
  /// In en, this message translates to:
  /// **'Cache cleared'**
  String get cacheCleared;

  /// Network error
  ///
  /// In en, this message translates to:
  /// **'Network error'**
  String get networkError;

  /// Server error
  ///
  /// In en, this message translates to:
  /// **'Server error'**
  String get serverError;

  /// Timeout
  ///
  /// In en, this message translates to:
  /// **'Request timeout'**
  String get timeoutError;

  /// Unknown error
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get unknownError;

  /// Welcome back after login
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get welcomeBack;

  /// Please login prompt
  ///
  /// In en, this message translates to:
  /// **'Please login'**
  String get pleaseLogin;

  /// Register button
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// Email input label
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// Confirm password input label
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// Invalid email format hint
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address'**
  String get invalidEmail;

  /// Password mismatch hint
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordNotMatch;

  /// Registration success hint
  ///
  /// In en, this message translates to:
  /// **'Registration successful'**
  String get registerSuccess;

  /// Registration failure hint
  ///
  /// In en, this message translates to:
  /// **'Registration failed, please try again'**
  String get registerFailed;

  /// Confirm password required hint
  ///
  /// In en, this message translates to:
  /// **'Please confirm password'**
  String get confirmPasswordRequired;

  /// Redirect to sign in
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get alreadyHaveAccount;

  /// Redirect to sign up
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? Sign up'**
  String get noAccountYet;

  /// Delete friend confirmation
  ///
  /// In en, this message translates to:
  /// **'Delete Friend'**
  String get deleteFriend;

  /// Search button
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// Chat history group title in search screen
  ///
  /// In en, this message translates to:
  /// **'Chat History'**
  String get searchChatHistory;

  /// Empty search result message
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noSearchResult;

  /// Single chat settings find chat records entry
  ///
  /// In en, this message translates to:
  /// **'Search chat records'**
  String get findChatRecord;

  /// Friend request accepted notification
  ///
  /// In en, this message translates to:
  /// **'Friend request accepted'**
  String get friendRequestAccepted;

  /// Forgot password link on login screen
  ///
  /// In en, this message translates to:
  /// **'Forgot Password'**
  String get forgotPassword;

  /// Verification code input label
  ///
  /// In en, this message translates to:
  /// **'Verification Code'**
  String get verificationCode;

  /// Send verification code button
  ///
  /// In en, this message translates to:
  /// **'Send Code'**
  String get sendCode;

  /// Verification code sent success hint
  ///
  /// In en, this message translates to:
  /// **'Code sent, check your email'**
  String get codeSent;

  /// Verification code send failure hint
  ///
  /// In en, this message translates to:
  /// **'Failed to send code, please retry'**
  String get codeSendFailed;

  /// Verification code invalid hint
  ///
  /// In en, this message translates to:
  /// **'Code expired or incorrect'**
  String get codeExpired;

  /// Reset password screen title
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get resetPassword;

  /// New password input label
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get newPassword;

  /// Password reset success hint
  ///
  /// In en, this message translates to:
  /// **'Password reset successfully'**
  String get passwordResetSuccess;

  /// Back to login button
  ///
  /// In en, this message translates to:
  /// **'Back to Login'**
  String get backToLogin;

  /// Profile - Wallet menu
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get wallet;

  /// Wallet subtitle text
  ///
  /// In en, this message translates to:
  /// **'Crypto Assets'**
  String get encryptedAssets;

  /// Profile - WIN Card menu
  ///
  /// In en, this message translates to:
  /// **'WIN Card'**
  String get winCard;

  /// WIN Card subtitle text
  ///
  /// In en, this message translates to:
  /// **'USDT Exchange Card'**
  String get usdtExchange;

  /// Profile - Favorites menu
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// Profile - Moments menu
  ///
  /// In en, this message translates to:
  /// **'Moments'**
  String get moments;

  /// Profile - Settings menu
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsMenu;

  /// Attach button tooltip
  ///
  /// In en, this message translates to:
  /// **'Attach'**
  String get attach;

  /// Settings page general group title
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get generalSettings;

  /// Settings page chat background entry
  ///
  /// In en, this message translates to:
  /// **'Chat Background'**
  String get chatBackground;

  /// Clear cache success toast
  ///
  /// In en, this message translates to:
  /// **'Cache cleared'**
  String get clearCacheDone;

  /// Chat background - choose from album
  ///
  /// In en, this message translates to:
  /// **'Choose from Album'**
  String get chooseFromAlbum;

  /// Chat background - reset to default
  ///
  /// In en, this message translates to:
  /// **'Reset to Default'**
  String get resetToDefault;

  /// Hold-to-talk button label
  ///
  /// In en, this message translates to:
  /// **'Hold to Talk'**
  String get holdToTalk;

  /// Hint to release and send while recording
  ///
  /// In en, this message translates to:
  /// **'Release to Send'**
  String get releaseToSend;

  /// Swipe up to cancel recording hint
  ///
  /// In en, this message translates to:
  /// **'Release to cancel'**
  String get releaseToCancel;

  /// Recording duration too short toast
  ///
  /// In en, this message translates to:
  /// **'Recording too short'**
  String get recordingTooShort;

  /// Emoji button tooltip
  ///
  /// In en, this message translates to:
  /// **'Emoji'**
  String get emoji;

  /// Image option
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get image;

  /// Video option
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get video;

  /// File option
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get file;

  /// Send button
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// Image source dialog title
  ///
  /// In en, this message translates to:
  /// **'Choose image source'**
  String get chooseImageSource;

  /// Video source dialog title
  ///
  /// In en, this message translates to:
  /// **'Choose video source'**
  String get chooseVideoSource;

  /// File source dialog title
  ///
  /// In en, this message translates to:
  /// **'Choose file source'**
  String get chooseFileSource;

  /// Gallery option
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// Camera option
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get camera;

  /// Image pick failure hint
  ///
  /// In en, this message translates to:
  /// **'Failed to pick image'**
  String get pickImageFailed;

  /// Video pick failure hint
  ///
  /// In en, this message translates to:
  /// **'Failed to pick video'**
  String get pickVideoFailed;

  /// File pick failure hint
  ///
  /// In en, this message translates to:
  /// **'Failed to pick file'**
  String get pickFileFailed;

  /// Uploading progress hint
  ///
  /// In en, this message translates to:
  /// **'Uploading'**
  String get uploading;

  /// Upload failure hint
  ///
  /// In en, this message translates to:
  /// **'Upload failed'**
  String get uploadFailed;

  /// Voice button tooltip
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get voice;

  /// Recording permission denied hint
  ///
  /// In en, this message translates to:
  /// **'Microphone permission required to record'**
  String get voicePermissionDenied;

  /// Recording failure hint
  ///
  /// In en, this message translates to:
  /// **'Recording failed'**
  String get voiceRecordFailed;

  /// Stop recording failure hint
  ///
  /// In en, this message translates to:
  /// **'Stop recording failed'**
  String get voiceStopFailed;

  /// wechat_assets_picker pick failure prompt
  ///
  /// In en, this message translates to:
  /// **'Failed to pick media'**
  String get pickAssetFailed;

  /// Gender field label
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get gender;

  /// Gender option: male
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get genderMale;

  /// Gender option: female
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get genderFemale;

  /// Gender selection page title
  ///
  /// In en, this message translates to:
  /// **'Select Gender'**
  String get genderSelect;

  /// Favorite action
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get favorite;

  /// Favorites list title
  ///
  /// In en, this message translates to:
  /// **'My Favorites'**
  String get myFavorites;

  /// Unfavorite action
  ///
  /// In en, this message translates to:
  /// **'Remove Favorite'**
  String get removeFavorite;

  /// Favorite success toast
  ///
  /// In en, this message translates to:
  /// **'Favorited'**
  String get favoriteAdded;

  /// Duplicate favorite toast
  ///
  /// In en, this message translates to:
  /// **'Already favorited'**
  String get alreadyFavorited;

  /// Empty favorites hint
  ///
  /// In en, this message translates to:
  /// **'No favorites'**
  String get favoriteEmpty;

  /// Profile center scan entry
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get scan;

  /// My QR code page title
  ///
  /// In en, this message translates to:
  /// **'My QR Code'**
  String get myQrCode;

  /// Scan result preview title
  ///
  /// In en, this message translates to:
  /// **'User found'**
  String get findUser;

  /// Preview page add friend button
  ///
  /// In en, this message translates to:
  /// **'Add to Contacts'**
  String get addToContacts;

  /// Scan add friend request sent successfully
  ///
  /// In en, this message translates to:
  /// **'Friend request sent'**
  String get requestSent;

  /// Invalid scanned QR code hint
  ///
  /// In en, this message translates to:
  /// **'Unrecognizable QR code'**
  String get invalidQr;

  /// Scanned user not found hint
  ///
  /// In en, this message translates to:
  /// **'User not found'**
  String get scanNotFound;

  /// Fail to fetch scanned user hint
  ///
  /// In en, this message translates to:
  /// **'Network error, please try again later'**
  String get scanNetworkError;

  /// Scanned user missing
  ///
  /// In en, this message translates to:
  /// **'User does not exist'**
  String get scanUserMissing;

  /// Scanned target is already friend
  ///
  /// In en, this message translates to:
  /// **'You are already friends'**
  String get alreadyFriend;

  /// Camera permission denied hint
  ///
  /// In en, this message translates to:
  /// **'Camera permission required to scan'**
  String get scanCameraDenied;

  /// Hint when scanning your own QR code
  ///
  /// In en, this message translates to:
  /// **'Cannot add yourself'**
  String get cannotAddSelf;
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
