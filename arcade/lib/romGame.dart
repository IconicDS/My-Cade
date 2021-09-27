class RomGame {
  final String url;
  final String name;
  final String category;

  const RomGame({
    required this.url,
    required this.name,
    required this.category,
  });

  factory RomGame.fromJson(Map<String, dynamic> json) {
    return RomGame(
        name: json['name'] as String,
        category: json['category'] as String,
        url: json['url'] as String);
  }
}
