class IModel {
  Configuration? configuration;
  String? sessionId;
  bool? status;

  IModel({this.configuration, this.sessionId, this.status});

  factory IModel.fromJson(Map<String, dynamic> json) {
    return IModel(
        configuration: Configuration.fromJson(json['configuration']),
        sessionId: json['session_id'],
        status: json['status']
    );
  }
}

class Configuration {
  String? displayName;
  String? supportName;
  String? themeColor;
  String? email;

  Configuration({this.displayName, this.supportName,
    this.themeColor, this.email,});


  factory Configuration.fromJson(Map<String, dynamic> json) {
    return Configuration(
        displayName: json['config_name'],
        supportName: json['support_name'],
        themeColor: json['color'],
        email: json['contact_email'],
    );
  }
}