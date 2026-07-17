import 'package:flutter/widgets.dart';

import '../../../data/models/message_model.dart';
import 'agent_message_bubble.dart';
import 'call_log_bubble.dart';
import 'user_message_bubble.dart';

/// Decides which bubble widget to render for a given [MessageModel].
abstract final class MessageBubbleFactory {
  static Widget build(MessageModel message, Color themeColor) {
    if (message.isCallLog) {
      return CallLogBubble(message: message);
    }
    if (message.messageType == MessageType.REPLY ||
        !message.isFromCustomer) {
      return AgentMessageBubble(message: message);
    }
    return UserMessageBubble(message: message, themeColor: themeColor);
  }
}
