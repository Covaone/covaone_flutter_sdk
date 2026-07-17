import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'covaone_sdk_method_channel.dart';

abstract class CovaoneSdkPlatform extends PlatformInterface {
  /// Constructs a CovaoneSdkPlatform.
  CovaoneSdkPlatform() : super(token: _token);

  static final Object _token = Object();

  static CovaoneSdkPlatform _instance = MethodChannelCovaoneSdk();

  /// The default instance of [CovaoneSdkPlatform] to use.
  ///
  /// Defaults to [MethodChannelCovaoneSdk].
  static CovaoneSdkPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [CovaoneSdkPlatform] when
  /// they register themselves.
  static set instance(CovaoneSdkPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
