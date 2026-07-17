import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

// import 'package:dio/dio.dart';
import 'package:covaone_sdk/src/model/api_response.dart';
import 'package:covaone_sdk/src/request/handlers/api_handlers.dart';
import 'package:covaone_sdk/src/request/helper/request_helper.dart';

import 'app_service.dart';

class InitializerService implements InitializerHandler {
  @override
  Future<dynamic> initializer(String firstName, String lastName,
      String merchantKey, String email, String userRef) async {
    ApiBaseHelper _baseHelper = ApiBaseHelper();

    try {
      Map<String, dynamic> data = {
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'merchant_key': merchantKey,
        'user_ref': userRef
      };

      Future<ApiResponse> response = _baseHelper.post(
        url: '',
        data: data,
      );

      debugPrint(">>>>>> data here <<<<<<");
      debugPrint(response.toString());

      return response;
    } catch (e) {
      debugPrint(e.toString());
      return ApiResponse.error('An unknown error happen please try again');
    }
  }

  @override
  Future<dynamic> initialize(String publicKey) async {
    ApiBaseHelper _baseHelper = ApiBaseHelper();

    try {
      Map<String, dynamic> data = {'public_key': publicKey};

      Future<ApiResponse> response = _baseHelper.post(
        url: 'initiate-session',
        data: data,
      );

      return response;
    } catch (e) {
      return ApiResponse.error('An unknown error happen please try again');
    }
  }

  @override
  Future getCurrentSession(String publicKey) async {
    ApiBaseHelper _baseHelper = ApiBaseHelper();

    try {
      Map<String, dynamic> data = {'session_id': publicKey};

      Future<ApiResponse> response = _baseHelper.post(
        url: 'get-single-session',
        data: data,
      );

      debugPrint(">>>>>> data here <<<<<<");
      debugPrint(response.toString());

      return response;
    } catch (e) {
      return ApiResponse.error('An unknown error happen please try again');
    }
  }

  // @override
  // Future<dynamic> verifyFaceBvn(String imagePath, String number, String token) async {
  //   ApiBaseHelper _baseHelper = ApiBaseHelper();
  //
  //   String imageData = await ImageEncExtension(imagePath).getImgBase64();
  //
  //   try {
  //     Map<String, dynamic> data = {'image': imageData, 'number': number, 'token': token};
  //
  //     Future<ApiResponse> response = _baseHelper.post(
  //       url: 'biometrics/merchant/data/verification/library/ng/bvn',
  //       data: data,
  //     );
  //
  //     print(">>>>>> data here <<<<<<");
  //     print(response);
  //
  //     return response;
  //
  //   } catch (e) {
  //     print(e);
  //     return ApiResponse.error('An unknow error happen please try again');
  //   }
  // }

  // @override
  // Future verifyFaceNin({ required String imagePath, String? number, required String token, XFile? uploadedImage}) async {
  //   ApiBaseHelper _baseHelper = ApiBaseHelper();
  //
  //   String? _uploadedImgData;
  //
  //   String imageData = await ImageEncExtension(imagePath).getImgBase64();
  //
  //   if ( uploadedImage != null ) {
  //     _uploadedImgData = await ImageEncExtension(uploadedImage.path).getImgBase64();
  //   }
  //
  //   try {
  //     Map<String, dynamic> data = {'image': imageData, 'mode': ( uploadedImage != null ) ? 'number' : 'image', 'number': number, 'token': token, 'id_front_image': _uploadedImgData};
  //
  //     Future<ApiResponse> response = _baseHelper.post(
  //       url: 'biometrics/merchant/data/verification/library/ng/nin',
  //       data: data,
  //     );
  //
  //     print(response);
  //
  //     return response;
  //
  //   } catch (e) {
  //     print(e);
  //     return ApiResponse.error('An unknow error happen please try again');
  //   }
  // }

  // @override
  // Future verifyFRSCPassport({ required String imagePath, required String token, XFile? uploadedImage}) async {
  //   ApiBaseHelper _baseHelper = ApiBaseHelper();
  //
  //   String? _uploadedImgData;
  //
  //   String imageData = await ImageEncExtension(imagePath).getImgBase64();
  //
  //   if ( uploadedImage != null ) {
  //     _uploadedImgData = await ImageEncExtension(uploadedImage.path).getImgBase64();
  //   }
  //
  //   try {
  //     Map<String, dynamic> data = {'image': imageData, 'token': token, 'id_front_image': _uploadedImgData};
  //
  //     Future<ApiResponse> response = _baseHelper.post(
  //       url: 'biometrics/merchant/data/verification/library/ng/dl',
  //       data: data,
  //     );
  //
  //     print(response);
  //
  //     return response;
  //
  //   } catch (e) {
  //     print(e);
  //     return ApiResponse.error('An unknow error happen please try again');
  //   }
  // }
}
