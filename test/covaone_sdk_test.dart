import 'package:flutter_test/flutter_test.dart';
import 'package:covaone_sdk/covaone_sdk_platform_interface.dart';
import 'package:covaone_sdk/covaone_sdk_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockCovaoneSdkPlatform
    with MockPlatformInterfaceMixin
    implements CovaoneSdkPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final CovaoneSdkPlatform initialPlatform = CovaoneSdkPlatform.instance;

  test('$MethodChannelCovaoneSdk is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelCovaoneSdk>());
  });

  test('getPlatformVersion', () async {
    // CovaoneSdk covaoneSdkPlugin = CovaoneSdk();
    // MockCovaoneSdkPlatform fakePlatform = MockCovaoneSdkPlatform();
    // CovaoneSdkPlatform.instance = fakePlatform;
    //
    // expect(await covaoneSdkPlugin.getPlatformVersion(), '42');
  });
}
