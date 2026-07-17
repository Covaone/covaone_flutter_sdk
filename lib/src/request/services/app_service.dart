import 'dart:io';

mixin AppSdkService {
  final String baseUrl = 'https://api.covaone.com/';

  final Map<String, String> headers = {
    HttpHeaders.contentTypeHeader: 'application/json',
    HttpHeaders.acceptHeader: 'application/json',
  };
}
