# covaone_chat Flutter SDK

A production-grade, BLoC-based Flutter SDK that embeds a full-featured customer-support chat widget into any Flutter app — including real-time messaging, broadcast announcements, FAQs, and WebRTC voice calls.

---

## Features

| Feature | Description |
|---------|-------------|
| 💬 Real-time chat | Socket.IO-backed messaging with typing indicators |
| 📢 Broadcasts | Popups and detail screens for announcements |
| ❓ FAQs | Searchable FAQ list with detail view |
| 📞 Voice calls | WebRTC audio calls with accept/decline/mute/end controls |
| 🎨 Theming | Theme colour sourced from server configuration |
| 📎 File upload | Images and documents, with in-chat preview |
| 😀 Emoji picker | 180-emoji picker with text insertion |
| 🌐 Platform support | iOS, Android, Web |
| 🚨 Host API issue prompts | Captures host-app API failures and shows a top support prompt |

---

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  covaone_sdk:
    path: ../   # or your package path / pub.dev reference
```

### Client app setup (required)

After adding the dependency, configure **your host app** (not this package) so calls, attachments, and mail links work. The OS only shows permission dialogs if these declarations exist.

---

#### 1. Android — `android/app/src/main/AndroidManifest.xml`

Open **your app’s** manifest (the one under `android/app/src/main/`, not a plugin folder).

Paste the block below **inside** the root `<manifest>…</manifest>` tag, **above** `<application>`:

```xml
<!-- ── Covaone Chat SDK ───────────────────────────────────────────────────── -->
<!-- Networking (API, Socket.IO, images) -->
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>

<!-- Voice calls (flutter_webrtc) -->
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS"/>
<uses-permission android:name="android.permission.CHANGE_NETWORK_STATE"/>

<!-- Chat camera attachments + flutter_webrtc -->
<uses-permission android:name="android.permission.CAMERA"/>

<!-- Bluetooth headsets during calls (Android 11 and below) -->
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30"/>
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30"/>

<!-- Optional hardware — keep required="false" so devices without a camera still install -->
<uses-feature android:name="android.hardware.microphone" android:required="false"/>
<uses-feature android:name="android.hardware.camera" android:required="false"/>
<uses-feature android:name="android.hardware.camera.autofocus" android:required="false"/>
```

**Notes for Android clients**

| Do | Don’t |
|----|--------|
| Keep these permissions (or rely on the plugin merge from `covaone_sdk`) | Add `READ_MEDIA_IMAGES` / `READ_EXTERNAL_STORAGE` for chat photos — not needed; system pickers are used |
| Rebuild the app after changing the manifest (`flutter clean` if merge looks wrong) | Put permissions inside `<application>` — they belong on `<manifest>` |

These entries are also declared in the SDK plugin manifest and usually **merge automatically**. Still add them explicitly if your app uses a custom merge strategy or you want the setup to be obvious in code review.

---

#### 2. iOS — `ios/Runner/Info.plist`

Open **your app’s** `ios/Runner/Info.plist` (Xcode → Runner → Info, or edit the file directly).

Paste this **inside** the top-level `<dict>…</dict>` (same level as `CFBundleName`, etc.):

```xml
<!-- ── Covaone Chat SDK ───────────────────────────────────────────────────── -->
<!-- Voice calls — shown when the user accepts a call -->
<key>NSMicrophoneUsageDescription</key>
<string>Required for voice calls with support agents</string>

<!-- Chat camera + call SDK — shown when taking a photo attachment -->
<key>NSCameraUsageDescription</key>
<string>Required to take photos for chat attachments and for the call SDK</string>

<!-- Photo library — required for App Store; used when attaching from Photos -->
<key>NSPhotoLibraryUsageDescription</key>
<string>Required to attach photos from your library in chat</string>

<!-- “Mail us directly” — required for mailto: / canLaunchUrl on iOS -->
<key>LSApplicationQueriesSchemes</key>
<array>
  <string>mailto</string>
</array>
```

You can customise the `<string>` purpose text for your brand, but **keep the `<key>` names exactly** as above. Missing keys cause silent failures or App Store rejection (`ITMS-90683`), not a Flutter error.

**After editing:** stop the app, run `cd ios && pod install`, then rebuild. A hot restart is not enough for Info.plist changes.

---

#### 3. What each permission unlocks

| Feature breaks without it | Client file | Key / permission | When the user is prompted |
|---------------------------|-------------|------------------|---------------------------|
| Voice calls (mic) | AndroidManifest + Info.plist | `RECORD_AUDIO` / `NSMicrophoneUsageDescription` | Accepting a call |
| Take photo in chat | AndroidManifest + Info.plist | `CAMERA` / `NSCameraUsageDescription` | Choosing **Camera** on attach |
| Pick photo from library | Info.plist only | `NSPhotoLibraryUsageDescription` | Choosing **Photo library** |
| Pick documents / files | — | *(none — system file picker)* | Choosing **Files** |
| API, sockets, images | AndroidManifest | `INTERNET`, `ACCESS_NETWORK_STATE` | Never (normal network) |
| Bluetooth headset on call | AndroidManifest | `BLUETOOTH` (+ `ADMIN`) ≤ API 30 | Rarely (older Android) |
| “Mail us directly” | Info.plist | `LSApplicationQueriesSchemes` → `mailto` | Never (opens Mail app) |

Ringtone and message chimes (`just_audio`) need **no** extra permissions.

---

#### 4. Audio assets (SDK package maintainers)

If you fork or ship this package, place freely-licensed MP3s in the SDK package:

```
assets/audio/notification.mp3   ← short chime (≤ 1 s)
assets/audio/ringtone.mp3       ← looping ringtone (2–5 s)
```

Placeholder silent files are included for development. Replace them before shipping. See `assets/audio/README.md` for recommended sources.

Host apps that only **depend** on `covaone_sdk` do not need to copy these assets — they ship inside the package.

---

## Quick start

### 1. Initialise once in `main()`

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await CovaoneChat.init(
    publicKey: 'your-public-key',
    // Optional — skip the in-chat lead-capture form when you already know
    // the signed-in user's identity:
    // userEmail: 'user@example.com',
    // userFullName: 'Jane Doe',
    // Optional: true by default. Enables automatic HttpClient monitoring.
    autoIntercept: true,
    // Optional: choose where the help card appears.
    helpCardPosition: CovaoneHelpCardPosition.top,
    // Optional: override the help-card colour. When omitted, the company
    // colour from get-single-session is used (falls back to black).
    // helpCardColor: Color(0xFF1A1A1A),
    // Optional: how long the help card stays visible (default 5 seconds).
    // helpCardDisplayDuration: Duration(seconds: 8),
  );

  runApp(const MyApp());
}
```

### 2. Insert the launcher widget

Place `CovaoneChat.launcher()` as the **last child** of a root `Stack` so it renders above all other UI:

```dart
@override
Widget build(BuildContext context) {
  return Stack(
    children: [
      MaterialApp(
        home: const HomePage(),
      ),
      CovaoneChat.launcher(),
    ],
  );
}
```

The launcher renders:
- A floating action button (FAB) with unread badge
- The slide-up chat panel containing Home / Conversations / FAQs tabs
- An incoming-call overlay when a WebRTC call arrives
- An active-call overlay once a call is accepted

### 3. (Optional) Provide the end-user identity

If your app already knows who is signed in, you can pass email and full name at init. The SDK will skip the in-chat email/name form and register the profile automatically when the user opens a conversation ("Send us a Message"):

```dart
await CovaoneChat.init(
  publicKey: 'your-public-key',
  userEmail: 'jane@example.com',
  userFullName: 'Jane Doe',
);
```

Both fields must be valid (email format, name ≥ 4 characters). If either is missing or invalid, the SDK falls back to the standard lead-capture form.

You can also set identity later (anywhere in your app lifecycle) and then sync:

```dart
// Assign now (e.g. after your own registration/login flow)
CovaoneChat.setUserProfile(
  email: 'jane@example.com',
  fullName: 'Jane Doe',
);

// Push to the active SDK session when ready
await CovaoneChat.syncUserProfile();

// Or one-step:
await CovaoneChat.pushUserProfile(
  email: 'jane@example.com',
  fullName: 'Jane Doe',
);
```

---

## Programmatic API

All methods are static on `CovaoneChat`.

### Panel control

```dart
CovaoneChat.open();    // open the chat panel
CovaoneChat.close();   // close the chat panel
CovaoneChat.toggle();  // toggle open/closed
```

### Call control

```dart
// Receive a callback whenever an incoming call arrives
CovaoneChat.onIncomingCall((callId, agentName) {
  print('Incoming call from $agentName');
});

// Programmatically end the active call
CovaoneChat.endCall();
```

### Session info

```dart
final info = CovaoneChat.getSessionInfo();
// SessionInfo(sessionId, initialized, unreadCount, currentTab)

print(CovaoneChat.version); // e.g. "1.0.0"
```

### User profile sync

```dart
// Set runtime identity (does not call API yet)
CovaoneChat.setUserProfile(
  email: 'jane@example.com',
  fullName: 'Jane Doe',
);

// Sync previously assigned identity
await CovaoneChat.syncUserProfile();

// One-step assign + sync
await CovaoneChat.pushUserProfile(
  email: 'jane@example.com',
  fullName: 'Jane Doe',
);

// Short aliases (same behavior)
await CovaoneChat.push(email: 'jane@example.com', fullName: 'Jane Doe');
await CovaoneChat.sync();
```

### Host-app API monitoring

The SDK supports 3 ways to capture host-app API issues (not SDK API calls):

1) **Automatic global interception** (`autoIntercept` in `CovaoneChat.init`)  
2) **Opt-in Dio interceptor** (`CovaoneChat.attachHostDioInterceptor`)  
3) **Explicit manual reporting** (`CovaoneChat.reportAppApiError`)  

All three paths feed the same internal error stream.

#### 1. Automatic global interception

Enabled by default during `CovaoneChat.init()` through:

```dart
await CovaoneChat.init(
  publicKey: 'your-public-key',
  autoIntercept: true, // default
);
```

This catches host-app HTTP errors for requests that go through `dart:io`
`HttpClient` (for example `http` package calls, and many Dio clients on mobile).

#### 2. Opt-in Dio interceptor (recommended for Dio clients)

Attach to each host-app Dio instance:

```dart
final dio = Dio(BaseOptions(baseUrl: 'https://api.yourapp.com/'));
CovaoneChat.attachHostDioInterceptor(dio);
```

The SDK interceptor captures non-success HTTP statuses (`3xx/4xx/5xx`) and network `DioException`s.

#### 3. Explicit manual reporting (for custom/native transports)

If your app uses another networking stack, report failures directly:

```dart
CovaoneChat.reportAppApiError(
  statusCode: 402,
  method: 'POST',
  uri: Uri.parse('https://api.yourapp.com/payments/charge'),
  message: 'Payment required',
);
```

#### Optional callback for your app analytics/logging

```dart
CovaoneChat.onAppApiError((event) {
  debugPrint(
    '[Host API Error] source=${event.source.name} '
    'status=${event.statusCode} method=${event.method} uri=${event.uri}',
  );
});
```

#### Prompt behavior in the SDK UI

When the SDK captures a host-app API error (`4xx` or `5xx`), it displays a support prompt card.

`Experiencing issues? Chat with support`

- Prompt stays visible for **5 seconds** by default.
- Tapping the prompt opens the SDK chat panel.
- Prompt re-trigger is throttled with a **25-second cooldown** minimum.
- Cooldown is shared across all 3 capture paths.

#### Configure the help card in `init`

Pass these optional parameters to `CovaoneChat.init(...)`:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `helpCardPosition` | `CovaoneHelpCardPosition` | `top` | Where the card appears (`top` or `bottom`) |
| `helpCardColor` | `Color?` | `null` | Optional colour override for the card |
| `helpCardDisplayDuration` | `Duration` | `5 seconds` | How long the card stays visible before auto-dismiss |

**Colour priority**

1. `helpCardColor` from `init` (if set)
2. Company colour from `get-single-session` (`configuration.color`)
3. Black

```dart
await CovaoneChat.init(
  publicKey: 'your-public-key',
  
  // Optional help-card settings:
  helpCardPosition: CovaoneHelpCardPosition.top,
  helpCardColor: const Color(0xFF1A1A1A), // omit to use company colour
  helpCardDisplayDuration: const Duration(seconds: 8), // default is 5s
);
```

### Teardown

```dart
// Soft teardown — keeps persisted session for the next init()
await CovaoneChat.destroy();

// Logout — wipe session so the next init() starts fresh
await CovaoneChat.destroy(clearSession: true);

// Disconnects socket, releases WebRTC, disposes audio players, resets DI.
// Call CovaoneChat.init() again to re-use.
```

---

## Host API error flow

```
Host app API call fails (e.g. 400 / 402 / 404 / 500)
  │
  ├─ Path A: Automatic global interception (HttpOverrides.global)
  │    └─ Captured by SDK monitor (excluding SDK-tagged internal requests)
  │
  ├─ Path B: Host Dio client + CovaoneChat.attachHostDioInterceptor(dio)
  │    └─ Captured in onResponse/onError interceptor hooks
  │
  └─ Path C: Host explicitly calls CovaoneChat.reportAppApiError(...)
       └─ Captured manually by SDK
  
All paths → AppApiErrorService
          → Emits onAppApiError callback
          → Triggers help prompt card (3s) if cooldown (25s) elapsed
          → Tap prompt opens Covaone chat
```

---

## Call flow

```
Agent → socket `call_invite` event
  ↓ CallBloc._handleInvite()
  ↓ IncomingCallEvent dispatched
  ↓ Panel opens automatically (if closed)
  ↓ AudioService.playRingtone()
  ↓ IncomingCallOverlay rendered

User taps "Accept"
  ↓ AcceptCallEvent
  ↓ AudioService.stopRingtone()
  ↓ WebRtcService.acceptCall() → getUserMedia + createPeerConnection
  ↓ socket `call_accept` + `call_answer` emitted
  ↓ ActiveCallOverlay rendered (live MM:SS timer)

User taps "End call"
  ↓ HangupCallEvent
  ↓ WebRtcService.teardown() → stop tracks + emit `call_end`
  ↓ CallStatus.ended (2 s) → CallStatus.idle
```

---

## Web support

On Web, `flutter_webrtc` uses the browser's native WebRTC API. Socket.IO defaults to WebSocket transport automatically. `SharedPreferences` uses `localStorage`. No extra configuration is required.

---

## Dependencies

| Package | Purpose |
|---------|---------|
| `flutter_bloc` | State management |
| `equatable` | Immutable models |
| `get_it` | Dependency injection |
| `dio` | REST API client |
| `socket_io_client` | WebSocket / Socket.IO |
| `flutter_webrtc` | WebRTC peer connections |
| `just_audio` | Audio playback |
| `shared_preferences` | Session persistence |
| `cached_network_image` | Network image caching |
| `file_picker` | Document attachment selection |
| `image_picker` | Photo library / camera attachments |
| `flutter_animate` | UI animations |
| `intl` | Date/time formatting |
| `url_launcher` | Open email clients |

---

## Licence

MIT — see `LICENSE` file.
