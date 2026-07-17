import 'package:covaone_sdk/src/model/initializer_model.dart';
import 'package:covaone_sdk/src/model/messages.dart';

class Session {
  String? id;
  String? email;
  String? name;
  Configuration? configuration;
  bool? isExpired;
  String? status;
  List<Messages>? messages = [];


  Session({this.id, this.email, this.name, this.configuration, this.isExpired, this.status, this.messages});


  factory Session.fromJson(Map<String, dynamic> json) {
    List messages = json['messages'] ?? [];
    Map<String, dynamic> config = json['configuration'];
    print(config);
    return Session(
        id: json['session_id'],
        email: json['email'],
        name: json['name'],
        configuration: Configuration.fromJson(json['configuration']),
        isExpired: json['is_expired'],
        status: json['status'],
        messages: messages.map((e) => Messages.fromJson(e)).toList()
    );
  }

}

class Configuration {
  String? configName;
  String? color;
  String? email;

  Configuration({this.configName, this.color, this.email});

  factory Configuration.fromJson(Map<String, dynamic> json) {
    print("Ileke");
    print(json);
    return Configuration(
        configName: json['config_name'],
        email: json['contact_email'],
        color: json['color']
    );
  }
}

