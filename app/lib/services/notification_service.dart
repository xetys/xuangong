import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io' show Platform;

class NotificationService {
  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  static const String _channelId = 'practice_timer';
  static const String _channelName = 'Practice Timer';
  static const String _channelDescription =
      'Notifications for ongoing practice sessions';
  static const int _notificationId = 1;

  /// Initialize the notification service
  /// Only works on Android and iOS (not on web)
  Future<void> initialize() async {
    // Don't initialize notifications on web
    if (kIsWeb) {
      _initialized = true;
      return;
    }

    try {
      // Android initialization
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS initialization
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: false, // We handle sound via AudioService
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Request permissions on iOS
      if (!kIsWeb && Platform.isIOS) {
        await _notifications
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: false,
            );
      }

      _initialized = true;
    } catch (e) {
      print('Error initializing notification service: $e');
      _initialized = false;
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    // User tapped notification - app should already be in foreground
    // or will be brought to foreground automatically
    print('Notification tapped: ${response.payload}');
  }

  /// Show or update the practice timer notification
  /// Shows live countdown in notification bar when app is backgrounded
  Future<void> showTimerNotification({
    required String exerciseName,
    required int remainingSeconds,
    required int currentExercise,
    required int totalExercises,
  }) async {
    if (!_initialized || kIsWeb) {
      return;
    }

    try {
      final minutes = remainingSeconds ~/ 60;
      final seconds = remainingSeconds % 60;
      final timeDisplay =
          '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

      // Android notification details
      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.low, // Low importance = no sound/vibration
        priority: Priority.low,
        ongoing: true, // Can't be dismissed by user
        autoCancel: false,
        showWhen: false,
        icon: '@mipmap/ic_launcher',
        color: const Color(0xFF9B1C1C), // Burgundy color
        // Show progress
        progress: currentExercise,
        maxProgress: totalExercises,
        // Large text for easy reading
        styleInformation: BigTextStyleInformation(
          '$timeDisplay remaining',
          contentTitle: exerciseName,
          summaryText: 'Exercise $currentExercise of $totalExercises',
        ),
      );

      // iOS notification details
      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: false,
        subtitle: 'Exercise $currentExercise of $totalExercises',
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        _notificationId,
        exerciseName,
        '$timeDisplay remaining',
        notificationDetails,
        payload: 'practice_timer',
      );
    } catch (e) {
      print('Error showing timer notification: $e');
    }
  }

  /// Show notification for rest phase
  Future<void> showRestNotification({
    required int remainingSeconds,
    required int currentExercise,
    required int totalExercises,
  }) async {
    if (!_initialized || kIsWeb) {
      return;
    }

    try {
      final minutes = remainingSeconds ~/ 60;
      final seconds = remainingSeconds % 60;
      final timeDisplay =
          '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

      // Android notification details
      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        showWhen: false,
        icon: '@mipmap/ic_launcher',
        color: const Color(0xFF9B1C1C),
        progress: currentExercise,
        maxProgress: totalExercises,
        styleInformation: BigTextStyleInformation(
          '$timeDisplay remaining',
          contentTitle: 'Rest',
          summaryText: 'Exercise $currentExercise of $totalExercises',
        ),
      );

      // iOS notification details
      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: false,
        subtitle: 'Exercise $currentExercise of $totalExercises',
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        _notificationId,
        'Rest',
        '$timeDisplay remaining',
        notificationDetails,
        payload: 'practice_rest',
      );
    } catch (e) {
      print('Error showing rest notification: $e');
    }
  }

  /// Show notification for repetition-based exercise
  Future<void> showRepetitionNotification({
    required String exerciseName,
    int? repetitions,
    required int currentExercise,
    required int totalExercises,
  }) async {
    if (!_initialized || kIsWeb) {
      return;
    }

    try {
      final subtitle = repetitions != null
          ? '$repetitions repetitions'
          : 'Complete when ready';

      // Android notification details
      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        showWhen: false,
        icon: '@mipmap/ic_launcher',
        color: const Color(0xFF9B1C1C),
        progress: currentExercise,
        maxProgress: totalExercises,
        styleInformation: BigTextStyleInformation(
          subtitle,
          contentTitle: exerciseName,
          summaryText: 'Exercise $currentExercise of $totalExercises',
        ),
      );

      // iOS notification details
      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: false,
        subtitle: 'Exercise $currentExercise of $totalExercises',
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        _notificationId,
        exerciseName,
        subtitle,
        notificationDetails,
        payload: 'practice_repetition',
      );
    } catch (e) {
      print('Error showing repetition notification: $e');
    }
  }

  /// Clear all notifications
  Future<void> clearNotifications() async {
    if (!_initialized || kIsWeb) {
      return;
    }

    try {
      await _notifications.cancel(_notificationId);
    } catch (e) {
      print('Error clearing notifications: $e');
    }
  }

  /// Check if notifications are supported on this platform
  bool get isSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
}
