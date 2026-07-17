import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/config.dart';
import '../../data/local/session_storage.dart';
import '../../data/models/broadcast_model.dart';
import '../../data/repositories/broadcast_repository.dart';

part 'broadcast_event.dart';
part 'broadcast_state.dart';

class BroadcastBloc extends Bloc<BroadcastEvent, BroadcastState> {
  final BroadcastRepository _broadcastRepository;
  final SessionStorage _sessionStorage;
  final CovaoneConfig _config;

  BroadcastBloc({
    required BroadcastRepository broadcastRepository,
    required SessionStorage sessionStorage,
    required CovaoneConfig config,
  })  : _broadcastRepository = broadcastRepository,
        _sessionStorage = sessionStorage,
        _config = config,
        super(const BroadcastInitial()) {
    on<FetchBroadcastsEvent>(_onFetch);
    on<FetchSingleBroadcastEvent>(_onFetchSingle);
    on<BroadcastViewedEvent>(_onViewed);
  }

  Future<void> _onFetch(
      FetchBroadcastsEvent event, Emitter<BroadcastState> emit) async {
    final cached = await _sessionStorage.getCachedBroadcasts();
    final lastSync = await _sessionStorage.getBroadcastSyncAt();
    final cacheFresh = cached != null && !_config.isBroadcastSyncExpired(lastSync);

    if (event.cacheOnly) {
      if (cached != null) {
        await _emitBroadcasts(cached, emit);
      }
      return;
    }

    if (event.refreshIfStale && cacheFresh) {
      if (state is! BroadcastLoaded) {
        await _emitBroadcasts(cached, emit);
      }
      return;
    }

    if (!event.refreshIfStale && cacheFresh) {
      await _emitBroadcasts(cached, emit);
      return;
    }

    emit(const BroadcastLoading());
    try {
      final results = await Future.wait([
        _broadcastRepository.getBroadcasts(event.sessionId),
        _sessionStorage.getViewedBroadcastIds(),
      ]);

      final broadcasts = results[0] as List<BroadcastModel>;
      final viewedIds = results[1] as Set<String>;

      await _sessionStorage.saveCachedBroadcasts(broadcasts);
      await _sessionStorage.saveBroadcastSyncAt(DateTime.now());

      _emitLoadedFromList(broadcasts, viewedIds, emit);
    } catch (e) {
      if (cached != null) {
        await _emitBroadcasts(cached, emit);
        return;
      }
      emit(BroadcastError(message: _msg(e)));
    }
  }

  Future<void> _emitBroadcasts(
      List<BroadcastModel> broadcasts, Emitter<BroadcastState> emit) async {
    final viewedIds = await _sessionStorage.getViewedBroadcastIds();
    _emitLoadedFromList(broadcasts, viewedIds, emit);
  }

  void _emitLoadedFromList(
    List<BroadcastModel> broadcasts,
    Set<String> viewedIds,
    Emitter<BroadcastState> emit,
  ) {
    final inApp = broadcasts
        .where((b) =>
            b.isActive &&
            (b.broadcastCategory == 'In-App' || b.broadcastCategory == 'App'))
        .toList();

    final widget = broadcasts
        .where((b) => b.isActive && b.broadcastCategory == 'Widget')
        .firstOrNull;

    emit(BroadcastLoaded(
      inAppBroadcasts: inApp,
      widgetBroadcast: widget,
      viewedIds: viewedIds,
    ));
  }

  Future<void> _onFetchSingle(
      FetchSingleBroadcastEvent event, Emitter<BroadcastState> emit) async {
    final current = state;
    if (current is! BroadcastLoaded) return;

    // Check the in-memory list first to avoid a redundant network call.
    final allKnown = [
      ...current.inAppBroadcasts,
      if (current.widgetBroadcast != null) current.widgetBroadcast!,
    ];

    final cached = allKnown
        .where((b) => b.broadcastId == event.broadcastId)
        .firstOrNull;

    if (cached != null) {
      emit(current.copyWith(selectedBroadcast: () => cached));
      return;
    }

    try {
      final broadcast =
          await _broadcastRepository.getSingleBroadcast(event.broadcastId);
      emit(current.copyWith(selectedBroadcast: () => broadcast));
    } catch (e) {
      // Non-fatal: leave the existing state, the detail screen will show error.
    }
  }

  Future<void> _onViewed(
      BroadcastViewedEvent event, Emitter<BroadcastState> emit) async {
    await _sessionStorage.markBroadcastViewed(event.broadcastId);
    final current = state;
    if (current is BroadcastLoaded) {
      emit(current.copyWith(
        viewedIds: {...current.viewedIds, event.broadcastId},
      ));
    }
  }

  String _msg(Object e) => e.toString().replaceFirst('Exception: ', '');
}
