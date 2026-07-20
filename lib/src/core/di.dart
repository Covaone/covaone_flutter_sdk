import 'dart:async';

import 'package:get_it/get_it.dart';

import '../blocs/broadcast/broadcast_bloc.dart';
import '../blocs/call/call_bloc.dart';
import '../blocs/chat/chat_bloc.dart';
import '../blocs/faq/faq_bloc.dart';
import '../blocs/session/session_bloc.dart';
import '../data/local/session_storage.dart';
import '../data/remote/api_client.dart';
import '../data/repositories/broadcast_repository.dart';
import '../data/repositories/chat_repository.dart';
import '../data/repositories/faq_repository.dart';
import '../services/audio_service.dart';
import '../services/app_api_error_service.dart';
import '../services/socket_service.dart';
import '../services/turn_ice_service.dart';
import '../services/webrtc_service.dart';
import 'config.dart';

/// SDK-internal service locator (not exposed in the public barrel).
///
/// All registrations are singletons so that every BLoC and service shares the
/// same instances for the lifetime of the SDK. Call [setup] once inside
/// [CovaoneChat.init] and [reset] inside [CovaoneChat.destroy].
abstract final class CovaoneDI {
  static final GetIt sl = GetIt.asNewInstance();

  static Future<void> setup(CovaoneConfig config) async {
    // ── Core ────────────────────────────────────────────────────────────────
    sl.registerSingleton<CovaoneConfig>(config);

    // ── Infrastructure ───────────────────────────────────────────────────────
    sl.registerLazySingleton<SessionStorage>(() => SessionStorage());
    sl.registerLazySingleton<ApiClient>(() => ApiClient(config: sl()));
    sl.registerLazySingleton<SocketService>(() => SocketService());
    sl.registerLazySingleton<AudioService>(() => AudioService());
    sl.registerLazySingleton<AppApiErrorService>(() => AppApiErrorService());
    // Eagerly configure the platform audio session so it is ready before the
    // first incoming call or message notification fires.
    unawaited(sl<AudioService>().init());
    sl.registerLazySingleton<TurnIceService>(
      () => TurnIceService(
        apiClient: sl(),
        sessionStorage: sl(),
        config: sl(),
      ),
    );
    sl.registerLazySingleton<WebRtcService>(
      () => WebRtcService(
        socketService: sl(),
        turnIceService: sl(),
      ),
    );

    // ── Repositories ────────────────────────────────────────────────────────
    sl.registerLazySingleton<ChatRepository>(
        () => ChatRepository(apiClient: sl(), sessionStorage: sl()));
    sl.registerLazySingleton<BroadcastRepository>(
        () => BroadcastRepository(apiClient: sl()));
    sl.registerLazySingleton<FaqRepository>(
        () => FaqRepository(apiClient: sl()));

    // ── BLoCs ────────────────────────────────────────────────────────────────
    // Registered as singletons so BLoC state survives widget rebuilds.
    sl.registerSingleton<SessionBloc>(
      SessionBloc(
        chatRepository: sl(),
        sessionStorage: sl(),
        socketService: sl(),
        config: sl(),
      ),
    );

    sl.registerSingleton<ChatBloc>(
      ChatBloc(
        chatRepository: sl(),
        sessionStorage: sl(),
        socketService: sl(),
        audioService: sl(),
        sessionBloc: sl(),
      ),
    );

    sl.registerSingleton<BroadcastBloc>(
      BroadcastBloc(
        broadcastRepository: sl(),
        sessionStorage: sl(),
        config: sl(),
      ),
    );

    sl.registerSingleton<FaqBloc>(
      FaqBloc(faqRepository: sl()),
    );

    sl.registerSingleton<CallBloc>(
      CallBloc(
        socketService: sl(),
        audioService: sl(),
        webRtcService: sl(),
      ),
    );
  }

  static Future<void> reset() async {
    // Close BLoCs gracefully before wiping the locator.
    if (sl.isRegistered<SessionBloc>()) await sl<SessionBloc>().close();
    if (sl.isRegistered<ChatBloc>()) await sl<ChatBloc>().close();
    if (sl.isRegistered<BroadcastBloc>()) await sl<BroadcastBloc>().close();
    if (sl.isRegistered<FaqBloc>()) await sl<FaqBloc>().close();
    if (sl.isRegistered<CallBloc>()) await sl<CallBloc>().close();
    if (sl.isRegistered<SocketService>()) sl<SocketService>().dispose();
    if (sl.isRegistered<AudioService>()) await sl<AudioService>().dispose();
    if (sl.isRegistered<AppApiErrorService>()) {
      sl<AppApiErrorService>().dispose();
    }
    if (sl.isRegistered<TurnIceService>()) {
      sl<TurnIceService>().clearCache();
    }

    await sl.reset();
  }
}
