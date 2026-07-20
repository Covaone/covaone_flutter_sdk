import 'package:flutter/painting.dart';

import 'sync_policy.dart';
import 'constants.dart';

/// Immutable configuration supplied by the host app during [CovaoneChat.init].
enum CovaoneHelpCardPosition {
  top,
  bottom,
}

class CovaoneConfig {
  /// Merchant public key obtained from the Covaone dashboard.
  final String publicKey;

  /// Base URL for all REST API calls.
  ///
  /// Defaults to [CovaoneConstants.defaultApiBase]
  /// (`https://api.covaone.com/`).
  final String apiBase;

  /// WebSocket / Socket.IO server base URL.
  ///
  /// Defaults to [CovaoneConstants.defaultWsBase]
  /// (`https://sync-c.covaone.com/`).
  final String wsBase;

  /// End-user email supplied by the host app.
  ///
  /// When provided together with [userFullName], the SDK skips the in-chat
  /// lead-capture form and registers the profile automatically when the user
  /// opens a conversation.
  final String? userEmail;

  /// End-user full name supplied by the host app.
  ///
  /// Must be at least 4 characters when used with [userEmail].
  final String? userFullName;

  /// Screen position for the "Need help?" support card.
  final CovaoneHelpCardPosition helpCardPosition;

  /// Optional override for the "Experiencing issues? Chat with support" card.
  ///
  /// When set, this colour is used instead of the company colour from
  /// `get-single-session`. When omitted, the card uses the company colour
  /// (falling back to black if unavailable).
  final Color? helpCardColor;

  /// How long the help card stays visible before auto-dismissing.
  ///
  /// Defaults to [CovaoneConstants.hostApiPromptDisplayDuration] (5 seconds).
  final Duration helpCardDisplayDuration;

  /// How long a cached session may be used before [get-single-session] runs again.
  final Duration sessionCacheTtl;

  /// How long cached broadcasts may be shown before refreshing from the API.
  final Duration broadcastCacheTtl;

  const CovaoneConfig({
    required this.publicKey,
    this.apiBase = CovaoneConstants.defaultApiBase,
    this.wsBase = CovaoneConstants.defaultWsBase,
    this.userEmail,
    this.userFullName,
    this.helpCardPosition = CovaoneHelpCardPosition.top,
    this.helpCardColor,
    this.helpCardDisplayDuration =
        CovaoneConstants.hostApiPromptDisplayDuration,
    this.sessionCacheTtl = CovaoneConstants.defaultSessionCacheTtl,
    this.broadcastCacheTtl = CovaoneConstants.defaultBroadcastCacheTtl,
  });

  bool isSessionSyncExpired(DateTime? lastSync) =>
      SyncPolicy.isExpired(lastSync, sessionCacheTtl);

  bool isBroadcastSyncExpired(DateTime? lastSync) =>
      SyncPolicy.isExpired(lastSync, broadcastCacheTtl);

  /// Returns `true` when both [userEmail] and [userFullName] are present and
  /// pass basic validation — the SDK can register the profile on the host's
  /// behalf without showing the lead-capture form.
  bool get hasHostedUserProfile {
    final email = userEmail?.trim();
    final name = userFullName?.trim();
    if (email == null ||
        email.isEmpty ||
        name == null ||
        name.length < 4 ||
        !email.contains('@') ||
        !email.contains('.')) {
      return false;
    }
    return true;
  }

  /// Validated email ready for profile registration, or `null`.
  String? get hostedUserEmail =>
      hasHostedUserProfile ? userEmail!.trim() : null;

  /// Validated full name ready for profile registration, or `null`.
  String? get hostedUserFullName =>
      hasHostedUserProfile ? userFullName!.trim() : null;
}
