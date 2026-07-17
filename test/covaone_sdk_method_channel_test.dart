import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:covaone_sdk/covaone_sdk_method_channel.dart';

void main() {
  MethodChannelCovaoneSdk platform = MethodChannelCovaoneSdk();
  const MethodChannel channel = MethodChannel('covaone_sdk');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return '42';
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
