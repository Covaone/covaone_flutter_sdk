part of 'faq_bloc.dart';

abstract class FaqEvent extends Equatable {
  const FaqEvent();
  @override
  List<Object?> get props => [];
}

/// Fetch all FAQs for the current session from the remote API.
class FetchFaqsEvent extends FaqEvent {
  final String sessionId;
  const FetchFaqsEvent({required this.sessionId});
  @override
  List<Object?> get props => [sessionId];
}

/// Client-side filter of the already-loaded FAQ list. Emits a new [filtered]
/// list after debounce is handled by the UI (FaqScreen posts this event after
/// a 1200 ms debounce timer fires).
class SearchFaqEvent extends FaqEvent {
  final String query;
  const SearchFaqEvent({required this.query});
  @override
  List<Object?> get props => [query];
}

/// Select a FAQ to display in the detail view.
class SelectFaqEvent extends FaqEvent {
  final String faqId;
  const SelectFaqEvent({required this.faqId});
  @override
  List<Object?> get props => [faqId];
}
