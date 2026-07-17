
import 'package:flutter/cupertino.dart';
import 'package:covaone_sdk/src/common/app_storage.dart';
import 'package:covaone_sdk/src/model/api_response.dart';
import 'package:covaone_sdk/src/model/initializer_model.dart';
import 'package:covaone_sdk/src/model/session.dart';
import 'package:covaone_sdk/src/request/services/initializer.dart';

class VSdkPlatform  {
  String? _key;
  late String _email;
  String? _publicKey;
  late String _firstName;
  late String _lastName;
  late String _userRef;
  // late Session _initializerModel;
  late Session _session;
  // FaceScan? _faceScan;

  String get email => _email;
  String get publicKey => _publicKey!;
  String get firstName => _firstName;
  String get lastName => _lastName;
  String get userRef => _userRef;

  // Session get initializerModel => _initializerModel;
  Session get session => _session;

  set email(String value) => _email = value;

  set publicKey(String value) => _publicKey = value;

  set firstName(String value) => _firstName = value;

  set lastName(String value) => _lastName = value;

  set userRef(String value) => _userRef = value;

  // set initializerModel(Session value) => _initializerModel = value;
  set session(Session value) => _session = value;

  // static VerificationPlatform get instance {
  //   VerificationPlatform _appInstance = VerificationPlatform();
  //   return _appInstance;
  // }

  AppStorage storage = AppStorage();

  String? get key {
    // TODO: implement key
    throw UnimplementedError();
  }

  static VSdkPlatform get instance {
    return VSdkPlatform._();
  }

  // static set instance(VerificationPlatform instance) {
  //   _instance = instance;
  // }

  List<VSdkPlatform> get apps {
    throw UnimplementedError('apps has not been implemented.');
  }

  /// Initializes a new [VSdkPlatform] with [name] and merchant [publicKey].
  Future<VSdkPlatform> initializeInterface({
    String? name,
    String? publicKey
  }) async {
    _publicKey = publicKey;
    return VSdkPlatform._();

    // return VerificationPlatform._();
    // throw UnimplementedError('initializeInterface() has not been implemented.');
  }

  Future<Session?> init({required BuildContext context, String? publicKey}) async {
    if(publicKey == null && _publicKey == null) return null;

    InitializerService service = InitializerService();

    bool exists = await storage.doesExists(key: '_xc_covaone_ilp');

    String? key = publicKey ?? _publicKey;

    print(exists);

    if (!exists) {
      print(key);
      ApiResponse response = await service.initialize(key!);

      if( response.status == Status.COMPLETED ) {
        IModel _initializerModel = IModel.fromJson(response.data);
        storage.saveKey(key: '_xc_covaone_ilp', value: (_initializerModel.sessionId)!);
        _session = (await getSession(id: _key))!;

        Navigator.of(context).pop();

        return _session;
      } else {
        Navigator.of(context).pop();
        return null;
      }
    } else {
      String? key = await storage.get(key: '_xc_covaone_ilp');
      _session = (await getSession(id: key))!;
      Navigator.of(context).pop();
      return _session;
    }
  }

  Future<Session?> getSession({String? id}) async {
    try {
      InitializerService service = InitializerService();

      ApiResponse response = await service.getCurrentSession(id!);

      print(response.data);

      if( response.status == Status.COMPLETED ) {
        _session = Session.fromJson(response.data);
        // print(_session);
        // print(_session?.configuration?.color);
        // print(_session?.messages?.length);
        // storage.saveKey(key: '_xc_covaone_ilp', value: _initializerModel.sessionId!);
        // return _initializerModel;
        return _session;
      } else {
        return null;
      }
    } catch (e) {
      print("Error $e");
      return null;
    }
  }

  VSdkPlatform._();
}