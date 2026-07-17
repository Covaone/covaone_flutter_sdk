part of '../../covaone_sdk.dart';

class Covaone {
  @visibleForTesting
  static VSdkPlatform? delegateInitializerProperty;

  String? get key => delegateInitializerProperty?.key;

  Session get initializerModel => _delegate.session;
  // IModel _iModel;

  static Covaone get instance {
    return Covaone._();
  }

  static VSdkPlatform get _delegate {
    return delegateInitializerProperty ??= VSdkPlatform.instance;
  }

  static Future<dynamic> initializeInterface(
      {String? name, String? publicKey}) async {
    VSdkPlatform _app =
        await _delegate.initializeInterface(name: name, publicKey: publicKey);

    return Covaone._(app: _app);
  }

  /// Call [initiate] function and supply the necessary data for verification
  ///
  /// All fields are required except for testing field which is set as false initially
  ///
  Future<dynamic> initiate(
    BuildContext context, {
    required String email,
    required String firstName,
    required String lastName,
    required String userRef,
    required Function onCancel,
    required Function onVerify,
    required Function onError,
  }) async {
    _checkInitialization();

    _checkEmailValidation(email);

    // print(_delegate.initializerModel);

    _delegate.firstName = firstName;
    _delegate.lastName = lastName;
    _delegate.userRef = userRef;
    _delegate.email = email;

    // Show loading indicator to initiate sdk

    Smart.loading(context);

    Session? m = await _delegate.init(context: context);

    print("biudiuwdgb");
    // print(m?.configuration?.color);
    print(_delegate.session.configuration);
    // return;

    Smart.showBottomDialogs(
      context,
      widget: BaseHomeScreen(),
    );

    // Smart.loading(context);

    InitializerService service = InitializerService();

    print('Hellidwdb');

    return;

    ApiResponse response = await service.initializer(
        _delegate.firstName,
        _delegate.lastName,
        _delegate.publicKey,
        _delegate.email,
        _delegate.userRef);

    if (response.status == Status.COMPLETED) {
      // _delegate.initializerModel = IModel.fromJson(response.data[0]);

      // Dispose the loading indicator and show the main start dialog
      Navigator.of(context).pop();
      // await Future.delayed(Duration(milliseconds: 50), () => Smart.dialog(context, widget: BaseHomeWidget()));
    } else {
      Navigator.of(context).pop();
    }
  }

  void callKey() async {
    print(_delegate.email);
  }

  _checkEmailValidation(String email) {
    RegExp myReg = RegExp(
        r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$');
    if (email.trim().isEmpty)
      return throw VException('Email Address cannot be empty');
    if (email.trim().length < 5)
      return throw VException('Email Address cannot be this short');
    if (!myReg.hasMatch(email.trim()))
      return throw VException('The email supplied is invalid');
  }

  _checkInitialization() {
    if (delegateInitializerProperty?.publicKey == null)
      throw NotInitializeException('Sdk has not been initialized');
  }

  Future<bool> _checkCameraPermission() async {
    return true;
    // if (await Permission.camera.request().isGranted) {
    //   debugPrint('CAMERA PERMISSION GRANTEDDD');
    //   return true;
    // } else {
    //   PermissionStatus _request = await Permission.camera.request();
    //   if (await Permission.camera.isPermanentlyDenied) {
    //     openAppSettings();
    //   }
    //
    //   return _request.isGranted;
    // }
  }

  Covaone._({VSdkPlatform? app});
}
