import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/faq/faq_bloc.dart';
import '../../data/models/faq_model.dart';
import '../shared/covaone_app_bar.dart';
import '../shared/covaone_theme.dart';
import '../shared/platform_loader.dart';
import 'faq_detail_shimmer.dart';

/// FAQ detail screen. Content is sourced entirely from the local [FaqBloc]
/// state — no extra network call is needed.
class FaqDetailScreen extends StatefulWidget {
  final String faqId;

  const FaqDetailScreen({super.key, required this.faqId});

  @override
  State<FaqDetailScreen> createState() => _FaqDetailScreenState();
}

class _FaqDetailScreenState extends State<FaqDetailScreen> {
  bool _shimmerDone = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1500),
        () => mounted ? setState(() => _shimmerDone = true) : null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CovaoneAppBar(title: ''),
      body: BlocBuilder<FaqBloc, FaqState>(
        builder: (context, state) {
          if (!_shimmerDone) {
            return const SingleChildScrollView(child: FaqDetailShimmer());
          }

          FaqModel? faq;
          if (state is FaqLoaded) {
            faq = state.selected ??
                state.all.where((f) => f.faqId == widget.faqId).firstOrNull;
          }

          if (faq == null) {
            return const Center(child: PlatformLoader());
          }

          return _FaqContent(faq: faq);
        },
      ),
    );
  }
}

class _FaqContent extends StatelessWidget {
  final FaqModel faq;
  const _FaqContent({required this.faq});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (faq.image != null)
            CachedNetworkImage(
              imageUrl: faq.image!,
              width: double.infinity,
              height: 240,
              fit: BoxFit.cover,
              placeholder: (_, __) =>
                  Container(height: 240, color: const Color(0xFFEEEEEE)),
              errorWidget: (_, __, ___) =>
                  Container(height: 120, color: const Color(0xFFEEEEEE)),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(faq.title, style: CovaoneTheme.headingStyle()),
                const SizedBox(height: 12),
                Text(faq.description,
                    style: CovaoneTheme.bodyStyle()
                        .copyWith(fontSize: 16, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
