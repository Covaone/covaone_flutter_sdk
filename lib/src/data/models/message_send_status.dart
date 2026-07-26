/// Delivery lifecycle for an outbound customer message.
enum MessageSendStatus {
  /// Optimistic local row; waiting for Socket.IO ACK.
  pending,

  /// Realtime server acknowledged the send.
  sent,

  /// ACK timed out, socket was disconnected, or server returned an error.
  failed;

  static MessageSendStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'pending':
        return MessageSendStatus.pending;
      case 'failed':
        return MessageSendStatus.failed;
      case 'sent':
      default:
        return MessageSendStatus.sent;
    }
  }

  String get value => name;
}
