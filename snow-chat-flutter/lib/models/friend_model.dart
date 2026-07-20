class FriendModel {
  final int userId;
  final String nickname;
  final String avatar;
  final String remark;
  final String status;

  FriendModel({
    required this.userId,
    required this.nickname,
    this.avatar = '',
    this.remark = '',
    this.status = 'offline',
  });

  factory FriendModel.fromJson(Map<String, dynamic> json) {
    // 后端 ChatFriend 使用 friend_id/friendId 表示好友用户ID，id 是关系记录ID。
    final friendId = json['friendId'] as int? ?? json['friend_id'] as int? ?? json['id'] as int? ?? 0;
    return FriendModel(
      userId: friendId,
      nickname: json['nickname'] as String? ?? '',
      avatar: json['avatar'] as String? ?? '',
      remark: json['remark'] as String? ?? '',
      status: json['status'] as String? ?? 'offline',
    );
  }
}
