class Messages {
  String? message;
  String? author;
  String? time;
  String? messageType;
  String? authorType;

  Messages({this.message, this.author, this.time, this.messageType, this.authorType});

  factory Messages.fromJson(Map<String, dynamic> json) {
    return Messages(
      message: json['message'],
      author: json['author'],
      time: json['time_created'],
      messageType: json['message_type'],
      authorType: json['author_type']
    );
  }
}