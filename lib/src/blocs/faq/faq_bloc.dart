import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/faq_model.dart';
import '../../data/repositories/faq_repository.dart';

part 'faq_event.dart';
part 'faq_state.dart';

class FaqBloc extends Bloc<FaqEvent, FaqState> {
  final FaqRepository _faqRepository;

  FaqBloc({required FaqRepository faqRepository})
      : _faqRepository = faqRepository,
        super(const FaqInitial()) {
    on<FetchFaqsEvent>(_onFetch);
    on<SearchFaqEvent>(_onSearch);
    on<SelectFaqEvent>(_onSelect);
  }

  Future<void> _onFetch(
      FetchFaqsEvent event, Emitter<FaqState> emit) async {
    emit(const FaqLoading());
    try {
      final faqs = await _faqRepository.getAllFaqs(event.sessionId);
      emit(FaqLoaded(all: faqs, filtered: faqs));
    } catch (e) {
      emit(FaqError(message: e.toString().replaceFirst('Exception: ', '')));
    }
  }

  void _onSearch(SearchFaqEvent event, Emitter<FaqState> emit) {
    final current = state;
    if (current is! FaqLoaded) return;

    final q = event.query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? current.all
        : current.all
            .where((f) => f.title.toLowerCase().contains(q))
            .toList();

    emit(current.copyWith(filtered: filtered));
  }

  void _onSelect(SelectFaqEvent event, Emitter<FaqState> emit) {
    final current = state;
    if (current is! FaqLoaded) return;

    final faq = current.all.where((f) => f.faqId == event.faqId).firstOrNull;
    emit(current.copyWith(selected: () => faq));
  }
}
