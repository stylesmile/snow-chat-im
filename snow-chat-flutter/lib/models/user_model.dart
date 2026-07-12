class UserModel {
  final int id;
  final String username;
  final String nickname;
  final String avatar;
  final String signature;
  final String status;

  UserModel({
    required this.id,
    required this.username,
    required this.nickname,
    this.avatar = '',
    this.signature = '',
    this.status = 'offline',
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int? ?? 0,
      username: json['username'] as String? ?? '',
      nickname: json['nickname'] as String? ?? '',
      avatar: json['avatar'] as String? ?? '',
      signature: json['signature'] as String? ?? '',
      status: json['status'] as String? ?? 'offline',
    );
  }
}
