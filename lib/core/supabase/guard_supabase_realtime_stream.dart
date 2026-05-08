import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Wraps a Supabase Postgres `.stream()` so transient Realtime failures do
/// not reach the Dart zone as **unhandled** exceptions.
///
/// When the WebSocket drops or the channel errors, the client emits
/// [RealtimeSubscribeException] via `addError` on a **broadcast** stream.
/// If any listener does not fully handle that error, Flutter logs the stack
/// you see in `SupabaseStreamBuilder._addException`.
///
/// This helper converts those errors in the wrapped stream so they are
/// considered handled (logged in debug only). The underlying Supabase stream
/// may still close; the UI typically keeps the last good snapshot until the
/// user navigates away or the widget rebuilds.
Stream<T> guardSupabaseRealtimeStream<T>(Stream<T> source) {
  return source.handleError(
    (Object error, StackTrace stackTrace) {
      if (kDebugMode) {
        debugPrint('[Supabase Realtime] $error');
      }
    },
    test: (dynamic error) => error is RealtimeSubscribeException,
  );
}
