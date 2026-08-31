// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'SnowChat';

  @override
  String get login => '로그인';

  @override
  String get username => '사용자 이름';

  @override
  String get password => '비밀번호';

  @override
  String get logout => '로그아웃';

  @override
  String get contacts => '연락처';

  @override
  String get chat => '채팅';

  @override
  String get profile => '프로필';

  @override
  String get addFriend => '친구 추가';

  @override
  String get sendFriendRequest => '친구 요청 보내기';

  @override
  String get accept => '수락';

  @override
  String get reject => '거절';

  @override
  String get groupName => '그룹 이름';

  @override
  String get createGroup => '그룹 만들기';

  @override
  String get groupMembers => '멤버';

  @override
  String get leaveGroup => '그룹 탈퇴';

  @override
  String get textMessage => '텍스트 메시지';

  @override
  String get imageMessage => '이미지';

  @override
  String get videoMessage => '동영상';

  @override
  String get recallMessage => '인쇄';

  @override
  String get searchUser => '검색';

  @override
  String get searchHint => '사용자 이름 또는 닉네임 입력';

  @override
  String get online => '온라인';

  @override
  String get offline => '오프라인';

  @override
  String get typing => '입력 중...';

  @override
  String get noMessages => '메시지 없음';

  @override
  String get noContacts => '연락처 없음';

  @override
  String get fileHelper => '파일 전송 어시스턴트';

  @override
  String get noGroups => '그룹 없음';

  @override
  String get settings => '설정';

  @override
  String get language => '언어';

  @override
  String get nickname => '닉네임';

  @override
  String get signature => '서명';

  @override
  String get avatar => '아바타';

  @override
  String get friendRequests => '친구 요청';

  @override
  String get pendingRequests => '대기 중인 요청';

  @override
  String get myFriends => '내 친구';

  @override
  String get myGroups => '내 그룹';

  @override
  String get messageSent => '메시지 전송됨';

  @override
  String get messageFailed => '메시지 전송 실패';

  @override
  String get messageRecalled => '메시지 취소됨';

  @override
  String get recallFailed => '취소 실패';

  @override
  String get selectForwardTarget => '전달 대상을 선택';

  @override
  String get loading => '로딩 중...';

  @override
  String get error => '오류';

  @override
  String get confirm => '확인';

  @override
  String get ok => 'OK';

  @override
  String get cancel => '취소';

  @override
  String get clearChat => '채팅 기록 지우기';

  @override
  String get clearChatConfirmTitle => '채팅 기록 지우기';

  @override
  String clearChatConfirmBody(Object name) {
    return '$name 님과의 채팅 기록을 지우시겠습니까? 실행 후 되돌릴 수 없습니다.';
  }

  @override
  String get clearChatDone => '채팅 기록을 지웠습니다';

  @override
  String get save => '저장';

  @override
  String get delete => '삭제';

  @override
  String get edit => '편집';

  @override
  String get back => '뒤로';

  @override
  String get done => '완료';

  @override
  String get unknown => '알 수 없음';

  @override
  String get you => '당신';

  @override
  String get inputMessage => '메시지 입력...';

  @override
  String get selectImage => '이미지 선택';

  @override
  String get selectVideo => '동영상 선택';

  @override
  String get takePhoto => '사진 찍기';

  @override
  String get takeVideo => '녹화';

  @override
  String get addMember => '멤버 추가';

  @override
  String get removeMember => '멤버 제거';

  @override
  String get invalidUsername => '사용자 이름을 입력하세요';

  @override
  String get invalidPassword => '비밀번호를 입력하세요';

  @override
  String get loginFailed => '로그인 실패, 다시 시도해주세요';

  @override
  String get friendRequestSent => '친구 요청을 보냈습니다';

  @override
  String get friendAdded => '친구를 추가했습니다';

  @override
  String get groupCreated => '그룹을 만들었습니다';

  @override
  String get profileUpdated => '프로필이 업데이트되었습니다';

  @override
  String get groupJoined => '그룹에 가입했습니다';

  @override
  String get leftGroup => '그룹에서 탈퇴했습니다';

  @override
  String get friendDeleted => '친구를 삭제했습니다';

  @override
  String get today => '오늘';

  @override
  String get yesterday => '어제';

  @override
  String get enterGroupName => '그룹 이름을 입력하세요';

  @override
  String get enterRemark => '참고 입력';

  @override
  String get enterMessage => '메시지를 입력하세요';

  @override
  String get systemWelcome => 'SnowChat에 오신 것을 환영합니다';

  @override
  String get joinedGroup => '그룹에 가입했습니다';

  @override
  String get wasRemoved => '그룹에서 제거되었습니다';

  @override
  String get newFriendRequest => '새로운 친구 요청';

  @override
  String get from => '로부터';

  @override
  String get remark => '참고';

  @override
  String get onlineUsers => '온라인 사용자';

  @override
  String get totalMembers => '총 멤버 수';

  @override
  String get chatList => '채팅';

  @override
  String get recentChats => '최근 채팅';

  @override
  String get allChats => '모든 채팅';

  @override
  String get noMoreMessages => '더 이상 메시지가 없습니다';

  @override
  String get pullToRefresh => '당겨서 새로고침';

  @override
  String get releaseToRefresh => '놓아서 새로고침';

  @override
  String get refreshing => '새로고침 중...';

  @override
  String get copied => '복사됨';

  @override
  String get copy => '복사';

  @override
  String get forward => '전송';

  @override
  String get reply => '답장';

  @override
  String get pin => '고정';

  @override
  String get mute => '음소거';

  @override
  String get unmute => '음소거 해제';

  @override
  String get topChat => '채팅 고정';

  @override
  String get untopChat => '채팅 고정 해제';

  @override
  String get selectContacts => '연락처 선택';

  @override
  String get selectAll => '모두 선택';

  @override
  String get deselectAll => '모두 선택 해제';

  @override
  String get privacy => '개인정보';

  @override
  String get blockedUsers => '차단 목록';

  @override
  String get readReceipts => '읽음回执';

  @override
  String get showOnlineStatus => '온라인 상태 표시';

  @override
  String get about => '정보';

  @override
  String get sqliteBrowser => 'SQLite Browser';

  @override
  String get total => 'Total';

  @override
  String get page => 'Page';

  @override
  String get noData => 'No data';

  @override
  String get version => '버전';

  @override
  String get checkUpdate => '업데이트 확인';

  @override
  String get clearCache => '캐시 정리';

  @override
  String get cacheCleared => '캐시가 지워졌습니다';

  @override
  String get networkError => '네트워크 오류';

  @override
  String get serverError => '서버 오류';

  @override
  String get timeoutError => '시간 초과';

  @override
  String get unknownError => '알 수 없는 오류';

  @override
  String get welcomeBack => '다시 오신 것을 환영합니다';

  @override
  String get pleaseLogin => '로그인해 주세요';

  @override
  String get register => '회원가입';

  @override
  String get email => '이메일';

  @override
  String get confirmPassword => '비밀번호 확인';

  @override
  String get invalidEmail => '유효한 이메일 주소를 입력하세요';

  @override
  String get passwordNotMatch => '비밀번호가 일치하지 않습니다';

  @override
  String get registerSuccess => '등록 성공';

  @override
  String get registerFailed => '등록에 실패했습니다. 다시 시도해주세요';

  @override
  String get confirmPasswordRequired => '비밀번호를 확인하세요';

  @override
  String get alreadyHaveAccount => '계정이 있으신가요? 로그인';

  @override
  String get noAccountYet => '계정이 없으신가요? 회원가입';

  @override
  String get deleteFriend => '친구 삭제';

  @override
  String get search => '검색';

  @override
  String get searchChatHistory => '채팅 기록';

  @override
  String get noSearchResult => '검색 결과가 없습니다';

  @override
  String get friendRequestAccepted => '친구 요청이 수락되었습니다';

  @override
  String get forgotPassword => '비밀번호 찾기';

  @override
  String get verificationCode => '인증 코드';

  @override
  String get sendCode => '코드 전송';

  @override
  String get codeSent => '인증 코드가 전송되었습니다. 이메일을 확인해주세요';

  @override
  String get codeSendFailed => '코드 전송에 실패했습니다. 다시 시도해주세요';

  @override
  String get codeExpired => '코드가 유효하지 않거나 만료되었습니다';

  @override
  String get resetPassword => '비밀번호 재설정';

  @override
  String get newPassword => '새 비밀번호';

  @override
  String get passwordResetSuccess => '비밀번호가 성공적으로 재설정되었습니다';

  @override
  String get backToLogin => '로그인으로 돌아가기';

  @override
  String get wallet => '지갑';

  @override
  String get encryptedAssets => '암호자산';

  @override
  String get winCard => 'WIN카드';

  @override
  String get usdtExchange => 'USDT 거래소 카드';

  @override
  String get favorites => '즐겨찾기';

  @override
  String get moments => '모멘츠';

  @override
  String get settingsMenu => '설정';

  @override
  String get attach => 'Attach';

  @override
  String get generalSettings => '일반';

  @override
  String get chatBackground => '채팅 배경';

  @override
  String get clearCacheDone => '캐시가 정리되었습니다';

  @override
  String get chooseFromAlbum => '앨범에서 선택';

  @override
  String get resetToDefault => '기본으로 복원';

  @override
  String get holdToTalk => '길게 눌러 말하기';

  @override
  String get releaseToSend => '놓아서 보내기';

  @override
  String get releaseToCancel => '손가락을 놓아 취소';

  @override
  String get recordingTooShort => '녹음이 너무 짧습니다';

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
  String get gender => '성별';

  @override
  String get genderMale => '남성';

  @override
  String get genderFemale => '여성';

  @override
  String get genderSelect => '성별 선택';

  @override
  String get favorite => '즐겨찾기';

  @override
  String get myFavorites => '내 즐겨찾기';

  @override
  String get removeFavorite => '즐겨찾기 해제';

  @override
  String get favoriteAdded => '즐겨찾기에 추가됨';

  @override
  String get alreadyFavorited => '이미 즐겨찾기한 메시지입니다';

  @override
  String get favoriteEmpty => '즐겨찾기가 없습니다';
}
