part of 'broadcast_bloc.dart';

abstract class BroadcastEvent extends Equatable {
  const BroadcastEvent();
  @override
  List<Object?> get props => [];
}

/// Fetch all broadcasts for the widget channel, then split into
/// in-app and widget-popup categories.
class FetchBroadcastsEvent extends BroadcastEvent {
  final String sessionId;

  /// When `true`, only hydrates from local cache — never hits the network.
  final bool cacheOnly;

  /// When `true`, fetches from the network only if the broadcast cache TTL
  /// has expired. Otherwise serves the cached copy.
  final bool refreshIfStale;

  const FetchBroadcastsEvent({
    required this.sessionId,
    this.cacheOnly = false,
    this.refreshIfStale = false,
  });

  @override
  List<Object?> get props => [sessionId, cacheOnly, refreshIfStale];
}

/// Fetch (or look up locally) a single broadcast to display in the detail view.
class FetchSingleBroadcastEvent extends BroadcastEvent {
  final String broadcastId;
  const FetchSingleBroadcastEvent({required this.broadcastId});
  @override
  List<Object?> get props => [broadcastId];
}

/// Mark a broadcast as viewed in [SessionStorage] and update the in-memory
/// [viewedIds] set so the popup/list refreshes immediately.
class BroadcastViewedEvent extends BroadcastEvent {
  final String broadcastId;
  const BroadcastViewedEvent({required this.broadcastId});
  @override
  List<Object?> get props => [broadcastId];
}
