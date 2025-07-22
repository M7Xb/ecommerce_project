class Category {
  final String id;
  final String name;
  final String icon;
  final DateTime createdAt;

  Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.createdAt,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'].toString(),
      name: json['name'],
      icon: json['icon'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

