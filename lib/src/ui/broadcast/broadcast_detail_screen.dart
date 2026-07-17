import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/broadcast/broadcast_bloc.dart';
import '../../data/models/broadcast_model.dart';
import '../shared/covaone_app_bar.dart';
import '../shared/platform_loader.dart';
import 'broadcast_content_view.dart';
import 'broadcast_detail_shimmer.dart';

/// Full broadcast detail view, pushed onto the local panel Navigator.
///
/// If the broadcast is already in [BroadcastLoaded.selectedBroadcast] it
/// renders immediately (after a simulated 1.5 s shimmer). Otherwise it waits
/// for [FetchSingleBroadcastEvent] to complete.
class BroadcastDetailScreen extends StatefulWidget {
  final String broadcastId;

  const BroadcastDetailScreen({super.key, required this.broadcastId});

  @override
  State<BroadcastDetailScreen> createState() => _BroadcastDetailScreenState();
}

class _BroadcastDetailScreenState extends State<BroadcastDetailScreen> {
  bool _shimmerDone = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _shimmerDone = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: const CovaoneAppBar(
        title: 'Announcement',
        backgroundColor: Color(0xFFF4F5F7),
      ),
      body: BlocBuilder<BroadcastBloc, BroadcastState>(
        builder: (context, state) {
          if (!_shimmerDone) {
            return const BroadcastDetailShimmer();
          }

          BroadcastModel? broadcast;
          if (state is BroadcastLoaded) {
            broadcast = state.selectedBroadcast ??
                _findInList(state, widget.broadcastId);
          }

          if (broadcast == null) {
            return const Center(child: PlatformLoader());
          }

          return BroadcastContentView(broadcast: broadcast);
        },
      ),
    );
  }

  BroadcastModel? _findInList(BroadcastLoaded state, String id) {
    final all = [
      ...state.inAppBroadcasts,
      if (state.widgetBroadcast != null) state.widgetBroadcast!,
    ];
    return all.where((b) => b.broadcastId == id).firstOrNull;
  }
}
