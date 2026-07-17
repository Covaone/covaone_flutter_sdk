import 'app_api_error_service.dart';

void installHostHttpMonitoring({
  required AppApiErrorService service,
  required Uri sdkApiBaseUri,
}) {
  // No-op on platforms where dart:io HttpOverrides is unavailable.
}

void uninstallHostHttpMonitoring() {
  // No-op on platforms where dart:io HttpOverrides is unavailable.
}

T runWithHostHttpMonitoring<T>(T Function() body) {
  return body();
}
