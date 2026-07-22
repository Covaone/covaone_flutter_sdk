import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/broadcast/broadcast_bloc.dart';
import '../../blocs/call/call_bloc.dart';
import '../../blocs/chat/chat_bloc.dart';
import '../../blocs/faq/faq_bloc.dart';
import '../../blocs/session/session_bloc.dart';
import '../../core/chat_controller.dart';
import '../../core/config.dart';
import '../../core/di.dart';
import '../../core/constants.dart';
import '../../data/models/session_model.dart';
import '../../services/app_api_error_service.dart';
import '../broadcast/widget_broadcast_popup.dart';
import '../call/active_call_overlay.dart';
import '../call/incoming_call_overlay.dart';
import '../chat/chat_screen.dart';
import '../chat/widgets/incoming_message_alert.dart';
import '../conversations/conversations_screen.dart';
import '../faq/faq_screen.dart';
import '../home/home_screen.dart';
import '../shared/covaone_bottom_nav.dart';
import '../shared/covaone_theme.dart';

/// The top-level overlay widget. Insert it at the root of the host app's
/// widget tree (as the last child of a Stack wrapping MaterialApp).
class CovaoneLauncher extends StatefulWidget {
  const CovaoneLauncher({super.key});

  @override
  State<CovaoneLauncher> createState() => _CovaoneLauncherState();
}

class _CovaoneLauncherState extends State<CovaoneLauncher> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  AppApiErrorService? _apiErrorService;
  OverlayEntry? _apiPromptOverlayEntry;

  bool _sheetShowing = false;
  bool _launchIntoChat = false;
  StreamSubscription<SessionState>? _sessionSub;
  DateTime? _lastApiPromptShownAt;
  Timer? _promptTimer;

  @override
  void initState() {
    super.initState();
    CovaoneChatController.panelOpen.addListener(_handlePanelChange);
    _hydrateBroadcastCache();
    _listenForHostApiPrompts();
  }

  /// Hydrates broadcasts from local cache only so the widget popup can render
  /// without a network call on cold start.
  void _hydrateBroadcastCache() {
    final sessionBloc = CovaoneDI.sl<SessionBloc>();
    final sessionId = _extractSessionId(sessionBloc.state);

    if (sessionId != null) {
      _dispatchBroadcastCacheHydration(sessionId);
      return;
    }

    _sessionSub = sessionBloc.stream.listen((state) {
      final id = _extractSessionId(state);
      if (id != null) {
        _dispatchBroadcastCacheHydration(id);
        _sessionSub?.cancel();
        _sessionSub = null;
      }
    });
  }

  void _dispatchBroadcastCacheHydration(String sessionId) {
    CovaoneDI.sl<BroadcastBloc>().add(
      FetchBroadcastsEvent(sessionId: sessionId, cacheOnly: true),
    );
  }

  void _refreshStaleDataOnPanelOpen() {
    final sessionBloc = CovaoneDI.sl<SessionBloc>();
    final sessionId =
        _extractSessionId(sessionBloc.state) ?? sessionBloc.currentSessionId;
    if (sessionId == null) return;

    // Session still respects TTL; broadcasts always refresh when the panel opens
    // (same eager pattern as FAQ on tab open).
    sessionBloc.add(const RefreshSessionIfStaleEvent());
    CovaoneDI.sl<BroadcastBloc>().add(
      FetchBroadcastsEvent(sessionId: sessionId),
    );
  }

  /// Returns a sessionId from any state that has one, null otherwise.
  String? _extractSessionId(SessionState state) =>
      _extractSession(state)?.sessionId;

  void _listenForHostApiPrompts() {
    if (!CovaoneDI.sl.isRegistered<AppApiErrorService>()) return;
    _apiErrorService = CovaoneDI.sl<AppApiErrorService>();
    _apiErrorService!.eventTick.addListener(_onApiErrorTick);
  }

  void _onApiErrorTick() {
    final event = _apiErrorService?.latestEvent;
    if (event == null) return;
    _showApiPrompt(event);
  }

  void _showApiPrompt(AppApiErrorEvent event) {
    if (!mounted) return;
    if (CovaoneChatController.panelOpen.value) return;
    if (!_isClientOrServerError(event.statusCode)) return;
    if (!_passesCooldown(event.timestamp)) return;

    _promptTimer?.cancel();
    _lastApiPromptShownAt = event.timestamp;
    _showApiPromptOverlay();
    _promptTimer = Timer(
      CovaoneDI.sl<CovaoneConfig>().helpCardDisplayDuration,
      () {
        _removeApiPromptOverlay();
      },
    );
  }

  bool _passesCooldown(DateTime now) {
    final last = _lastApiPromptShownAt;
    if (last == null) return true;
    return now.difference(last) >= CovaoneConstants.hostApiPromptCooldown;
  }

  bool _isClientOrServerError(int? statusCode) {
    if (statusCode == null) return false;
    return statusCode >= 400 && statusCode < 600;
  }

  void _showApiPromptOverlay() {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    final config = CovaoneDI.sl<CovaoneConfig>();
    final cardPosition = config.helpCardPosition;
    final backgroundColor = _resolveHelpCardColor(config);

    _removeApiPromptOverlay();
    _apiPromptOverlayEntry = OverlayEntry(
      builder: (ctx) => Positioned(
        top: cardPosition == CovaoneHelpCardPosition.top ? 0 : null,
        bottom: cardPosition == CovaoneHelpCardPosition.bottom ? 0 : null,
        left: 12,
        right: 12,
        child: _ApiIssuePromptBanner(
          onTap: _onPromptTap,
          position: cardPosition,
          backgroundColor: backgroundColor,
        ),
      ),
    );
    overlay.insert(_apiPromptOverlayEntry!);
  }

  /// Resolves the help-card colour:
  /// 1. [CovaoneConfig.helpCardColor] from init (optional override)
  /// 2. Company colour from `get-single-session` configuration
  /// 3. Black as the final fallback
  Color _resolveHelpCardColor(CovaoneConfig config) {
    final override = config.helpCardColor;
    if (override != null) return override;

    final session = _extractSession(CovaoneDI.sl<SessionBloc>().state);
    final hex = session?.configuration.color.trim();
    if (hex != null && hex.isNotEmpty) {
      try {
        final cleaned = hex.replaceFirst('#', '');
        final value = int.parse(
          cleaned.length == 6 ? 'FF$cleaned' : cleaned,
          radix: 16,
        );
        return Color(value);
      } catch (_) {
        // Fall through to black.
      }
    }
    return const Color(0xFF000000);
  }

  /// Returns a [SessionModel] from any state that has one, null otherwise.
  SessionModel? _extractSession(SessionState state) {
    if (state is SessionLoaded) return state.session;
    if (state is SessionProfileFormVisible) return state.session;
    if (state is SessionSettingProfile) return state.session;
    return null;
  }

  void _removeApiPromptOverlay() {
    _apiPromptOverlayEntry?.remove();
    _apiPromptOverlayEntry = null;
  }

  void _onPromptTap() {
    _promptTimer?.cancel();
    _removeApiPromptOverlay();
    CovaoneChatController.open();
  }

  void _handlePanelChange() {
    if (!mounted) return;
    final shouldOpen = CovaoneChatController.panelOpen.value;
    if (shouldOpen && !_sheetShowing) {
      _refreshStaleDataOnPanelOpen();
      _promptTimer?.cancel();
      _removeApiPromptOverlay();
      // Defer to the next frame so we're not in the middle of a build/listener.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openSheet();
      });
    } else if (!shouldOpen && _sheetShowing) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  /// Opens the SDK panel and navigates straight into the chat conversation.
  void _openChatFromAlert() {
    final chatBloc = CovaoneDI.sl<ChatBloc>();
    // Reset so the panel can observe a fresh false→true open.
    if (chatBloc.state.isChatOpen) {
      chatBloc.add(const CloseChatEvent());
    }
    _launchIntoChat = true;
    CovaoneChatController.open();
  }

  Future<void> _openSheet() async {
    if (!mounted || _sheetShowing) return;
    _sheetShowing = true;
    final openChatOnMount = _launchIntoChat;
    _launchIntoChat = false;

    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      isDismissible: true,
      builder: (sheetCtx) => _SheetContent(
        navigatorKey: _navigatorKey,
        openChatOnMount: openChatOnMount,
      ),
    );

    _sheetShowing = false;
    // Leaving the panel should leave chat too, so the next open starts clean.
    final chatBloc = CovaoneDI.sl<ChatBloc>();
    if (chatBloc.state.isChatOpen) {
      chatBloc.add(const CloseChatEvent());
    }
    // Sync controller if the sheet was dismissed by the user (swipe / tap barrier).
    if (CovaoneChatController.panelOpen.value) {
      CovaoneChatController.close();
    }
  }

  @override
  void dispose() {
    CovaoneChatController.panelOpen.removeListener(_handlePanelChange);
    _sessionSub?.cancel();
    _apiErrorService?.eventTick.removeListener(_onApiErrorTick);
    _promptTimer?.cancel();
    _removeApiPromptOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: CovaoneDI.sl<SessionBloc>()),
          BlocProvider.value(value: CovaoneDI.sl<ChatBloc>()),
          BlocProvider.value(value: CovaoneDI.sl<BroadcastBloc>()),
          BlocProvider.value(value: CovaoneDI.sl<FaqBloc>()),
          BlocProvider.value(value: CovaoneDI.sl<CallBloc>()),
        ],
        child: Theme(
          data: CovaoneTheme.themeData(),
          child: ValueListenableBuilder<bool>(
          valueListenable: CovaoneChatController.panelOpen,
          builder: (context, isOpen, _) {
            return Stack(
              fit: StackFit.expand,
              children: [
                // ── Widget broadcast popup ─────────────────────────────
                if (!isOpen)
                  BlocBuilder<BroadcastBloc, BroadcastState>(
                    builder: (context, bState) {
                      if (bState is BroadcastLoaded && bState.hasUnseenWidget) {
                        return Positioned(
                          bottom: 40,
                          left: 16,
                          right: 16,
                          child: WidgetBroadcastPopup(
                            broadcast: bState.widgetBroadcast!,
                            onClose: () => context.read<BroadcastBloc>().add(
                                BroadcastViewedEvent(
                                    broadcastId:
                                        bState.widgetBroadcast!.broadcastId)),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),

                // ── Incoming message alert (panel closed) ──────────────
                if (!isOpen)
                  BlocBuilder<BroadcastBloc, BroadcastState>(
                    builder: (context, bState) {
                      final hasBroadcast = bState is BroadcastLoaded &&
                          bState.hasUnseenWidget;
                      return BlocBuilder<ChatBloc, ChatState>(
                        buildWhen: (prev, curr) =>
                            prev.pendingMessageAlerts !=
                            curr.pendingMessageAlerts,
                        builder: (context, chatState) {
                          final alerts = chatState.pendingMessageAlerts;
                          if (alerts.isEmpty) return const SizedBox.shrink();
                          return Positioned(
                            left: 0,
                            right: 0,
                            bottom: hasBroadcast ? 130 : 0,
                            child: IncomingMessageAlert(
                              messages: alerts,
                              onOpen: _openChatFromAlert,
                              onDismiss: () => context
                                  .read<ChatBloc>()
                                  .add(const DismissMessageAlertEvent()),
                            ),
                          );
                        },
                      );
                    },
                  ),
              ],
            );
          },
        ),
        ),
      ),
    );
  }
}

class _ApiIssuePromptBanner extends StatefulWidget {
  final VoidCallback onTap;
  final CovaoneHelpCardPosition position;
  final Color backgroundColor;

  const _ApiIssuePromptBanner({
    required this.onTap,
    required this.position,
    required this.backgroundColor,
  });

  @override
  State<_ApiIssuePromptBanner> createState() => _ApiIssuePromptBannerState();
}

class _ApiIssuePromptBannerState extends State<_ApiIssuePromptBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    final curve = CurvedAnimation(
      parent: _entrance,
      curve: Curves.easeOutCubic,
    );
    _fade = curve;
    _slide = Tween<Offset>(
      begin: Offset(
        0,
        widget.position == CovaoneHelpCardPosition.top ? -0.28 : 0.28,
      ),
      end: Offset.zero,
    ).animate(curve);
    _scale = Tween<double>(begin: 0.94, end: 1).animate(curve);
    _entrance.forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mid = widget.backgroundColor;
    final light = Color.lerp(mid, Colors.white, 0.12)!;
    final dark = Color.lerp(mid, Colors.black, 0.22)!;
    final isTop = widget.position == CovaoneHelpCardPosition.top;

    return SafeArea(
      top: isTop,
      bottom: !isTop,
      child: Padding(
        padding: EdgeInsets.only(
          top: isTop ? 10 : 0,
          bottom: isTop ? 0 : 10,
        ),
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: ScaleTransition(
              scale: _scale,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onTap,
                  borderRadius: BorderRadius.circular(22),
                  splashColor: Colors.white.withValues(alpha: 0.12),
                  highlightColor: Colors.white.withValues(alpha: 0.06),
                  child: Ink(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [light, mid, dark],
                        stops: const [0.0, 0.48, 1.0],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: mid.withValues(alpha: 0.38),
                          blurRadius: 28,
                          offset: const Offset(0, 12),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Stack(
                        children: [
                          // Soft top sheen for a glass edge.
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: 28,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.white.withValues(alpha: 0.16),
                                    Colors.white.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Subtle right-side glow behind the chevron.
                          Positioned(
                            right: -18,
                            top: -24,
                            bottom: -24,
                            width: 88,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0.10),
                                    Colors.white.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 18, 14, 18),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: _SupportAvatar(brand: mid),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Experiencing issues?',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: CovaoneTheme.textStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.72),
                                          fontWeight: FontWeight.w500,
                                          fontSize: 12.2,
                                          letterSpacing: 0.15,
                                          height: 1.2,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Chat with support',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: CovaoneTheme.textStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16.2,
                                          letterSpacing: 0.05,
                                          height: 1.2,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Something went wrong on our end. '
                                        'Tap to talk with an agent — we\'re '
                                        'online and ready to help.',
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: CovaoneTheme.textStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.78),
                                          fontWeight: FontWeight.w400,
                                          fontSize: 12.2,
                                          height: 1.35,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF4ADE80),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              'Support online  ·  Instant help',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: CovaoneTheme.textStyle(
                                                color: Colors.white
                                                    .withValues(alpha: 0.68),
                                                fontWeight: FontWeight.w500,
                                                fontSize: 11.2,
                                                height: 1.2,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: Colors.white
                                          .withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.2),
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 17,
                                      color: Colors.white
                                          .withValues(alpha: 0.95),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SupportAvatar extends StatefulWidget {
  final Color brand;

  const _SupportAvatar({required this.brand});

  @override
  State<_SupportAvatar> createState() => _SupportAvatarState();
}

class _SupportAvatarState extends State<_SupportAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.22),
                  Colors.white.withValues(alpha: 0.08),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.28),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.support_agent_rounded,
              size: 23,
              color: Colors.white,
            ),
          ),
          Positioned(
            right: -1,
            bottom: -1,
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) {
                final t = _pulse.value;
                return Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color.lerp(
                      const Color(0xFF22C55E),
                      const Color(0xFF4ADE80),
                      t,
                    ),
                    border: Border.all(color: widget.brand, width: 1.8),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF22C55E)
                            .withValues(alpha: 0.25 + (0.35 * t)),
                        blurRadius: 4 + (3 * t),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Modal bottom-sheet content ────────────────────────────────────────────────

/// Provides blocs and renders the full SDK panel inside the modal sheet.
class _SheetContent extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final bool openChatOnMount;

  const _SheetContent({
    required this.navigatorKey,
    this.openChatOnMount = false,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: CovaoneDI.sl<SessionBloc>()),
        BlocProvider.value(value: CovaoneDI.sl<ChatBloc>()),
        BlocProvider.value(value: CovaoneDI.sl<BroadcastBloc>()),
        BlocProvider.value(value: CovaoneDI.sl<FaqBloc>()),
        BlocProvider.value(value: CovaoneDI.sl<CallBloc>()),
      ],
      child: _SheetPanel(
        navigatorKey: navigatorKey,
        openChatOnMount: openChatOnMount,
      ),
    );
  }
}

class _SheetPanel extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final bool openChatOnMount;

  const _SheetPanel({
    required this.navigatorKey,
    this.openChatOnMount = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isNarrow = screenSize.width < 465;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    // On narrow screens fill the screen; on wide screens show a centred
    // 360 × 620 card that slides up from the bottom.
    final double height =
        isNarrow ? screenSize.height * 0.92 : 620.0 + bottomPadding;

    final double width = isNarrow ? screenSize.width : 360.0;

    Widget panel = Material(
      color: Colors.transparent,
      child: Theme(
        data: CovaoneTheme.themeData(),
        child: Container(
        width: width,
        height: height,
        decoration: CovaoneTheme.panelDecoration(isNarrow),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            Stack(
              children: [
                Positioned.fill(
                  child: _PanelBody(
                    navigatorKey: navigatorKey,
                    isNarrow: isNarrow,
                    openChatOnMount: openChatOnMount,
                  ),
                ),
                Positioned(
                  top: 0,
                  left: width / 2 - 20,
                  // height: 40,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDDDDDD),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),

            // ── Call overlays (ringing / active) ────────────────────────
            BlocBuilder<CallBloc, CallState>(
              buildWhen: (prev, curr) => prev.status != curr.status,
              builder: (context, callState) {
                if (callState.status == CallStatus.ringing) {
                  return const IncomingCallOverlay();
                }
                if (callState.status == CallStatus.connecting ||
                    callState.status == CallStatus.active) {
                  return const ActiveCallOverlay();
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
        ),
      ),
    );

    // On wide screens, align the panel to the bottom-right to match the
    // original floating-panel aesthetic.
    if (!isNarrow) {
      panel = Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: panel,
        ),
      );
    }

    return panel;
  }
}

// ── Panel body ────────────────────────────────────────────────────────────────

class _PanelBody extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final bool isNarrow;
  final bool openChatOnMount;

  const _PanelBody({
    required this.navigatorKey,
    required this.isNarrow,
    this.openChatOnMount = false,
  });

  @override
  State<_PanelBody> createState() => _PanelBodyState();
}

class _PanelBodyState extends State<_PanelBody> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.openChatOnMount) {
        context.read<ChatBloc>().add(const OpenChatEvent(isNew: false));
        return;
      }
      _openChatIfNeeded();
    });
  }

  void _openChatIfNeeded() {
    if (!mounted) return;
    if (!context.read<ChatBloc>().state.isChatOpen) return;
    final nav = widget.navigatorKey.currentState;
    if (nav == null || nav.canPop()) return;
    nav.pushNamed('/chat');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          if (widget.navigatorKey.currentState?.canPop() ?? false) {
            widget.navigatorKey.currentState!.pop();
          } else {
            CovaoneChatController.close();
          }
        }
      },
      child: Column(
        children: [
          Expanded(
            child: BlocListener<ChatBloc, ChatState>(
              listenWhen: (prev, curr) => prev.isChatOpen != curr.isChatOpen,
              listener: (context, state) {
                final nav = widget.navigatorKey.currentState;
                if (nav == null) return;
                if (state.isChatOpen) {
                  if (!nav.canPop()) {
                    nav.pushNamed('/chat');
                  }
                } else if (nav.canPop()) {
                  nav.popUntil((route) => route.isFirst);
                }
              },
              child: Navigator(
                key: widget.navigatorKey,
                initialRoute: '/',
                onGenerateRoute: (settings) {
                  switch (settings.name) {
                    case '/':
                      return _fadeRoute(const _TabLayout());
                    case '/broadcast-detail':
                      return _slideRoute(settings.arguments as Widget? ??
                          const SizedBox.shrink());
                    case '/faq-detail':
                      return _slideRoute(settings.arguments as Widget? ??
                          const SizedBox.shrink());
                    case '/chat':
                      return _slideRoute(const ChatScreen());
                    default:
                      return _fadeRoute(const _TabLayout());
                  }
                },
              ),
            ),
          ),

          // Bottom nav (hidden when chat is open).
          BlocBuilder<ChatBloc, ChatState>(
            buildWhen: (prev, curr) => prev.isChatOpen != curr.isChatOpen,
            builder: (context, state) => AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: state.isChatOpen
                  ? const SizedBox.shrink()
                  : const CovaoneBottomNav(),
            ),
          ),

          // Footer.
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              'Powered by Covaone',
              style: CovaoneTheme.textStyle(
                  fontSize: 10, color: const Color(0xFFBBBBBB)),
            ),
          ),
        ],
      ),
    );
  }

  PageRoute<T> _fadeRoute<T>(Widget page) => PageRouteBuilder<T>(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: Duration.zero,
      );

  PageRoute<T> _slideRoute<T>(Widget page) => PageRouteBuilder<T>(
        pageBuilder: (_, animation, ___) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: page,
        ),
        transitionDuration: const Duration(milliseconds: 250),
      );
}

// ── Tab IndexedStack ─────────────────────────────────────────────────────────

class _TabLayout extends StatelessWidget {
  const _TabLayout();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatBloc, ChatState>(
      buildWhen: (prev, curr) => prev.currentTab != curr.currentTab,
      builder: (context, state) => IndexedStack(
        index: state.currentTab.index,
        children: const [HomeScreen(), ConversationsScreen(), FaqScreen()],
      ),
    );
  }
}
