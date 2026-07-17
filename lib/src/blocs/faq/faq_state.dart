part of 'faq_bloc.dart';

abstract class FaqState extends Equatable {
  const FaqState();
  @override
  List<Object?> get props => [];
}

class FaqInitial extends FaqState {
  const FaqInitial();
}

class FaqLoading extends FaqState {
  const FaqLoading();
}

class FaqLoaded extends FaqState {
  /// Full unfiltered list as returned by the API.
  final List<FaqModel> all;

  /// Current search results; equals [all] when query is empty.
  final List<FaqModel> filtered;

  /// FAQ currently open in the detail view.
  final FaqModel? selected;

  const FaqLoaded({
    required this.all,
    required this.filtered,
    this.selected,
  });

  FaqLoaded copyWith({
    List<FaqModel>? all,
    List<FaqModel>? filtered,
    FaqModel? Function()? selected,
  }) =>
      FaqLoaded(
        all: all ?? this.all,
        filtered: filtered ?? this.filtered,
        selected: selected != null ? selected() : this.selected,
      );

  @override
  List<Object?> get props => [all, filtered, selected];
}

class FaqError extends FaqState {
  final String message;
  const FaqError({required this.message});
  @override
  List<Object?> get props => [message];
}
