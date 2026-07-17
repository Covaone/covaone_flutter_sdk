#import "CovaoneSdkPlugin.h"
#if __has_include(<covaone_sdk/covaone_sdk-Swift.h>)
#import <covaone_sdk/covaone_sdk-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "covaone_sdk-Swift.h"
#endif

@implementation CovaoneSdkPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftCovaoneSdkPlugin registerWithRegistrar:registrar];
}
@end
