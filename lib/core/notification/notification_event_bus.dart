import 'dart:async';

class NotificationActionEvent {
  final String actionId;
  final String? activityId;
  NotificationActionEvent({required this.actionId, this.activityId});
}

class NotificationEventBus {
  NotificationEventBus._internal();
  static final NotificationEventBus instance = NotificationEventBus._internal();

  final StreamController<NotificationActionEvent> _controller =
      StreamController<NotificationActionEvent>.broadcast();

  Stream<NotificationActionEvent> get stream => _controller.stream;

  void emit(NotificationActionEvent event) {
    if (!_controller.isClosed) {
      _controller.add(event);
    }
  }

  void dispose() {
    _controller.close();
  }
}

String? extractActivityIdFromPayload(String? payload) {
  if (payload == null) return null;
  if (payload.startsWith('activity:')) {
    return payload.substring('activity:'.length);
  }
  return null;
}
