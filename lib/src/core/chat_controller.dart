import 'package:flutter/foundation.dart';

/// Package-internal controller for the chat panel open/close state.
/// Accessible by both [CovaoneChat] (lib/covaone_chat.dart) and
/// [CovaoneLauncher] (lib/src/ui/launcher/) without leaking the notifier
/// through the public API.
final class CovaoneChatController {
  CovaoneChatController._();

  static final ValueNotifier<bool> panelOpen = ValueNotifier<bool>(false);

  static void open() => panelOpen.value = true;
  static void close() => panelOpen.value = false;
  static void toggle() => panelOpen.value = !panelOpen.value;
}
