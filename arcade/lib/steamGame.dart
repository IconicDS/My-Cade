class SteamGame {
  final int appId;
  final String name;

  const SteamGame({
    required this.appId,
    required this.name,
  });

  factory SteamGame.fromJson(Map<String, dynamic> json) {
    return SteamGame(appId: json['appid'] as int, name: json['name'] as String);
  }
}
