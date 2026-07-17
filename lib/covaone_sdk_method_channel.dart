import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'covaone_sdk_platform_interface.dart';

/// An implementation of [CovaoneSdkPlatform] that uses method channels.
class MethodChannelCovaoneSdk extends CovaoneSdkPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('covaone_sdk');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
