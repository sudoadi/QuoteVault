class AppConstants {
  // Supabase Configuration
  static const String supabaseUrl = 'https://ehsyawhjbydmwhsyuqpf.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVoc3lhd2hqYnlkbXdoc3l1cXBmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgyNDc1NDcsImV4cCI6MjA4MzgyMzU0N30.fe1NlAlRTyNql9oMsP0rC3awZgPEo1L-b1VQW-MHl0k';

  // Deep Links
  static const String callbackUrlScheme = 'com.adikr.quotevault';

  // Storage Buckets
  static const String bucketAvatars = 'avatars';

  // Table Names
  static const String tableQuotes = 'quotes';
  static const String tableProfiles = 'profiles';
  static const String tablePosters = 'posters';
  static const String tableSavedQuotes = 'saved_quotes';

  // Notification Channels
  static const String notificationChannelId = 'daily_quote_channel';
  static const String notificationChannelName = 'Daily Quotes';
  static const String notificationChannelDesc = 'Daily notification for the quote of the day';
}