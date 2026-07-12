class GroupModel {
  final int id;
  final String name;
  final String avatar;
  final int ownerId;
  final int memberCount;

  GroupModel({
    required this.id,
    required this.name,
    this.avatar = '',
    required this.ownerId,
    this.memberCount = 0,
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      avatar: json['avatar'] as String? ?? '',
      ownerId: json['owner_id'] as int? ?? 0,
      memberCount: json['member_count'] as int? ?? 0,
    );
  }
}
