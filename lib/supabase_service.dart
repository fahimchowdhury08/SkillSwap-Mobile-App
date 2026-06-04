import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;
  static User? get currentUser => client.auth.currentUser;
  static String? get currentUserId => client.auth.currentUser?.id;

  static Future<void> sendNotification({
    required String userId,
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      await client.from('notifications').insert({
        'user_id': userId,
        'type': type,
        'title': title,
        'body': body,
        'data': data ?? {},
        'is_read': false,
      });
    } catch (e) {
      debugPrint('Notification error: $e');
    }
  }

  static Future<void> resetAvailability() async {
    try {
      if (currentUserId == null) return;
      await client
          .from('users')
          .update({'is_available_now': false})
          .eq('id', currentUserId!);
    } catch (e) {
      debugPrint('Availability reset error: $e');
    }
  }
}