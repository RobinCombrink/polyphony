class ApiServer {
  const ApiServer({
    required this.id,
    required this.name,
    required this.ownerSubject,
  });

  final String id;
  final String name;
  final String ownerSubject;

  factory ApiServer.fromJson(Map<String, dynamic> json) {
    return ApiServer(
      id: json["id"] as String,
      name: json["name"] as String,
      ownerSubject: json["owner_subject"] as String,
    );
  }
}

class ApiChannel {
  const ApiChannel({
    required this.id,
    required this.serverId,
    required this.name,
  });

  final String id;
  final String serverId;
  final String name;

  factory ApiChannel.fromJson(Map<String, dynamic> json) {
    return ApiChannel(
      id: json["id"] as String,
      serverId: json["server_id"] as String,
      name: json["name"] as String,
    );
  }
}

class ApiMessage {
  const ApiMessage({
    required this.id,
    required this.channelId,
    required this.authorSubject,
    required this.content,
  });

  final String id;
  final String channelId;
  final String authorSubject;
  final String content;

  factory ApiMessage.fromJson(Map<String, dynamic> json) {
    return ApiMessage(
      id: json["id"] as String,
      channelId: json["channel_id"] as String,
      authorSubject: json["author_subject"] as String,
      content: json["content"] as String,
    );
  }
}
