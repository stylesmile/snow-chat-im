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
    return FriendModel(
      userId: json['id'] as int? ?? 0,
      nickname: json['nickname'] as String? ?? '',
      avatar: json['avatar'] as String? ?? '',
      remark: json['remark'] as String? ?? '',
      status: json['status'] as String? ?? 'offline',
    );
  }
}
