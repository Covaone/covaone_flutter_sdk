part of 'broadcast_bloc.dart';

abstract class BroadcastState extends Equatable {
  const BroadcastState();
  @override
  List<Object?> get props => [];
}

class BroadcastInitial extends BroadcastState {
  const BroadcastInitial();
}

class BroadcastLoading extends BroadcastState {
  const BroadcastLoading();
}

class BroadcastLoaded extends BroadcastState {
  /// Active broadcasts with category `"In-App"` or `"App"` — shown in the
  /// home-screen broadcast list.
  final List<BroadcastModel> inAppBroadcasts;

  /// First active `"Widget"` category broadcast, if any. Drives the floating
  /// popup above the FAB.
  final BroadcastModel? widgetBroadcast;

  /// Broadcast currently open in the detail view.
  final BroadcastModel? selectedBroadcast;

  /// IDs the user has acknowledged; persisted via [SessionStorage].
  final Set<String> viewedIds;

  const BroadcastLoaded({
    required this.inAppBroadcasts,
    this.widgetBroadcast,
    this.selectedBroadcast,
    required this.viewedIds,
  });

  /// Returns true when [widgetBroadcast] exists and has not been viewed yet.
  bool get hasUnseenWidget =>
      widgetBroadcast != null &&
      !viewedIds.contains(widgetBroadcast!.broadcastId);

  BroadcastLoaded copyWith({
    List<BroadcastModel>? inAppBroadcasts,
    BroadcastModel? Function()? widgetBroadcast,
    BroadcastModel? Function()? selectedBroadcast,
    Set<String>? viewedIds,
  }) =>
      BroadcastLoaded(
        inAppBroadcasts: inAppBroadcasts ?? this.inAppBroadcasts,
        widgetBroadcast:
            widgetBroadcast != null ? widgetBroadcast() : this.widgetBroadcast,
        selectedBroadcast: selectedBroadcast != null
            ? selectedBroadcast()
            : this.selectedBroadcast,
        viewedIds: viewedIds ?? this.viewedIds,
      );

  @override
  List<Object?> get props =>
      [inAppBroadcasts, widgetBroadcast, selectedBroadcast, viewedIds];
}

class BroadcastError extends BroadcastState {
  final String message;
  const BroadcastError({required this.message});
  @override
  List<Object?> get props => [message];
}
