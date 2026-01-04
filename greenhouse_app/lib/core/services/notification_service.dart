import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../constants/api_constants.dart';
import 'api_service.dart';

// Background notification handler (before app opens)
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling background message: ${message.messageId}');
  print('Title: ${message.notification?.title}');
  print('Body: ${message.notification?.body}');
}

class NotificationService {
  final ApiService _apiService;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  NotificationService(this._apiService);

  // Initialize Firebase and request permissions
  Future<void> initialize() async {
    try {
      // Initialize Firebase
      await Firebase.initializeApp();

      // Request user permission for notifications
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        carryForwardNotificationSettings: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('✅ User granted notification permission');
      } else if (settings.authorizationStatus ==
          AuthorizationStatus.provisional) {
        print('⚠️ Provisional notification permission');
      } else {
        print('❌ User denied notification permission');
      }

      // Handle foreground messages (when app is open)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _handleForegroundMessage(message);
      });

      // Handle notification tap (when app is in background/closed)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleNotificationTap(message);
      });

      // Set background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Get and register FCM token
      await _registerFCMToken();

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen(_onTokenRefresh);
    } catch (e) {
      print('❌ Notification initialization failed: $e');
    }
  }

  // Get FCM token and send to backend
  Future<void> _registerFCMToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        print('FCM Token: $token');
        // Send token to backend
        await _apiService.post(ApiConstants.registerFCMToken, {
          'fcmToken': token,
        });
      }
    } catch (e) {
      print('❌ Failed to register FCM token: $e');
    }
  }

  // Handle token refresh
  Future<void> _onTokenRefresh(String token) async {
    print('🔄 FCM Token refreshed: $token');
    try {
      await _apiService.post(ApiConstants.registerFCMToken, {
        'fcmToken': token,
      });
    } catch (e) {
      print('❌ Failed to update FCM token: $e');
    }
  }

  // Handle foreground notifications (app open)
  void _handleForegroundMessage(RemoteMessage message) {
    print('📬 Foreground message received');
    print('Title: ${message.notification?.title}');
    print('Body: ${message.notification?.body}');

    // Show notification even when app is open
    if (message.notification != null) {
      _showLocalNotification(
        title: message.notification!.title ?? 'Notification',
        body: message.notification!.body ?? '',
        data: message.data,
      );
    }
  }

  // Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    print('📲 Notification tapped');
    print('Data: ${message.data}');

    // Navigate based on notification data
    if (message.data['type'] == 'device_alert') {
      final deviceId = message.data['deviceId'];
      // Navigate to device detail screen
      print('Navigate to device: $deviceId');
    }
  }

  // Show local notification (when app is open)
  void _showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) {
    print('🔔 Showing local notification: $title - $body');
    // This would use flutter_local_notifications package
    // For now, just print
  }

  // Get all notifications history
  Future<List<Map<String, dynamic>>> getNotifications() async {
    try {
      final response = await _apiService.get(ApiConstants.notifications);
      if (response.success && response.data != null) {
        final List<dynamic> notificationsJson = response.data;
        return notificationsJson.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      print('❌ Failed to fetch notifications: $e');
    }
    return [];
  }

  // Mark notification as read
  Future<bool> markNotificationAsRead(int notificationId) async {
    try {
      final response = await _apiService.post(
        '${ApiConstants.notifications}/$notificationId/read',
        {},
      );
      return response.success;
    } catch (e) {
      print('❌ Failed to mark notification as read: $e');
      return false;
    }
  }

  // Enable/disable alerts for a device
  Future<bool> setDeviceAlerts(
    String deviceId,
    Map<String, dynamic> rules,
  ) async {
    try {
      final response = await _apiService.post(
        '${ApiConstants.devices}/$deviceId/alert-rules',
        rules,
      );
      return response.success;
    } catch (e) {
      print('❌ Failed to set alert rules: $e');
      return false;
    }
  }

  // Get alert rules for a device
  Future<Map<String, dynamic>?> getDeviceAlertRules(String deviceId) async {
    try {
      final response = await _apiService.get(
        '${ApiConstants.devices}/$deviceId/alert-rules',
      );
      if (response.success && response.data != null) {
        return response.data as Map<String, dynamic>;
      }
    } catch (e) {
      print('❌ Failed to fetch alert rules: $e');
    }
    return null;
  }
}
