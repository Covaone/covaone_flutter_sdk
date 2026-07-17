import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/chat/chat_bloc.dart';
import '../../blocs/faq/faq_bloc.dart';
import '../../blocs/session/session_bloc.dart';
import '../../data/models/faq_model.dart';
import '../shared/empty_state.dart';
import '../shared/platform_loader.dart';
import '../shared/covaone_theme.dart';
import 'faq_detail_screen.dart';
import 'faq_row.dart';

/// FAQ tab: search bar with 1200 ms debounce + filtered FAQ list.
///
/// FAQs are fetched lazily — only when the user first navigates to this tab,
/// never at SDK/app startup.
class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  bool _isSearching = false;
  StreamSubscription<ChatState>? _tabSub;

  @override
  void initState() {
    super.initState();
    _scheduleFaqFetch();
  }

  /// Fetches FAQs only when the FAQ tab is active for the first time.
  /// Since [IndexedStack] mounts all tabs immediately, we must check the
  /// current tab and wait for the user to navigate here before fetching.
  void _scheduleFaqFetch() {
    final chatBloc = context.read<ChatBloc>();
    if (chatBloc.state.currentTab == ChatTab.faq) {
      _loadFaqs();
      return;
    }

    _tabSub = chatBloc.stream.listen((state) {
      if (state.currentTab == ChatTab.faq) {
        _loadFaqs();
        _tabSub?.cancel();
        _tabSub = null;
      }
    });
  }

  void _loadFaqs() {
    final sessionState = context.read<SessionBloc>().state;
    String? sessionId;
    if (sessionState is SessionLoaded) {
      sessionId = sessionState.session.sessionId;
    } else if (sessionState is SessionProfileFormVisible) {
      sessionId = sessionState.session.sessionId;
    }
    if (sessionId != null) {
      context.read<FaqBloc>().add(FetchFaqsEvent(sessionId: sessionId));
    }
  }

  void _onSearchChanged(String query) {
    // Show a brief loading indicator while debounce timer runs.
    setState(() => _isSearching = true);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() => _isSearching = false);
        context.read<FaqBloc>().add(SearchFaqEvent(query: query));
      }
    });
  }

  @override
  void dispose() {
    _tabSub?.cancel();
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Text('FAQ', style: CovaoneTheme.headingStyle()),
        ),

        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            style: CovaoneTheme.bodyStyle(),
            decoration: InputDecoration(
              hintText: 'Search for help',
              hintStyle: CovaoneTheme.captionStyle(),
              prefixIcon:
                  const Icon(Icons.search_rounded, color: Color(0xFFAAAAAA)),
              filled: true,
              fillColor: const Color(0xFFF8F8F8),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // List / loader
        Expanded(
          child: BlocBuilder<FaqBloc, FaqState>(
            builder: (context, state) {
              if (state is FaqLoading || _isSearching) {
                return const Center(child: PlatformLoader());
              }

              if (state is FaqError) {
                return Center(
                  child: Text(state.message,
                      style: CovaoneTheme.captionStyle()),
                );
              }

              if (state is FaqLoaded) {
                final list = state.filtered;
                if (list.isEmpty) {
                  return const EmptyState(
                    title: 'No results',
                    subtitle: 'Try a different search term.',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: list.length,
                  itemBuilder: (context, i) => FaqRow(
                    faq: list[i],
                    onTap: () => _openDetail(context, list[i]),
                  ),
                );
              }

              return const SizedBox.shrink();
            },
          ),
        ),
      ],
    );
  }

  void _openDetail(BuildContext context, FaqModel faq) {
    context.read<FaqBloc>().add(SelectFaqEvent(faqId: faq.faqId));
    Navigator.of(context).pushNamed(
      '/faq-detail',
      arguments: FaqDetailScreen(faqId: faq.faqId),
    );
  }
}
