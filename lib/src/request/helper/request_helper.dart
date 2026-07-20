import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:covaone_sdk/src/common/exceptions.dart';
import 'package:covaone_sdk/src/model/api_response.dart';
import 'package:covaone_sdk/src/request/services/app_service.dart';

class ApiBaseHelper with AppSdkService {
  Future<ApiResponse> get({required String url}) async {
    var responseJson;
    // Dio dio = Dio();

    try {
      final response = await http.get(Uri.parse(baseUrl + url));
      responseJson = _returnResponse(response);
    } on SocketException {
      throw FetchDataException('No Internet connection');
    }
    return responseJson;
  }

  Future<ApiResponse> post({required String url, required Map data}) async {
    var responseJson;
    // Dio dio = Dio();

    try {
      final response = await http.post(
        Uri.parse(baseUrl + url),
        body: jsonEncode(data),
        headers: headers,
      );
      responseJson = _returnResponse(response);

      // }  on DioError catch (e) {
      //   if (e.response != null) {
      //     print(e.response?.data);
      //     // print(e.response.statusCode);
      //     print(e.response?.headers);
      //   } else {
      //     // Something happened in setting up or sending the request that triggered an Error
      //     print(e.message);
      //   }
      //   return e.response;
    } on SocketException {
      throw FetchDataException('No Internet connection');
    }
    return responseJson;
  }

  dynamic _returnResponse(http.Response response) {
    switch (response.statusCode) {
      case 200:
        var responseJson = json.decode(response.body);
        return ApiResponse.completed(responseJson);
      case 400:
        throw BadRequestException(response.body.toString());
      case 401:
      case 403:
        throw UnauthorisedException(response.body.toString());
      case 500:
      default:
        throw FetchDataException(
            'Error occurred while Communication with Server with StatusCode : ${response.statusCode}');
    }
  }
}
