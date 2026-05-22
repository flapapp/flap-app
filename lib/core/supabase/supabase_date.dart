DateTime asDateTime(dynamic v) {
  if (v == null) {
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
  if (v is DateTime) {
    return v;
  }
  if (v is String) {
    return DateTime.tryParse(v) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}

DateTime? asDateTimeOrNull(dynamic v) {
  if (v == null) {
    return null;
  }
  if (v is DateTime) {
    return v;
  }
  if (v is String) {
    return DateTime.tryParse(v);
  }
  return null;
}

/// Device-local kickoff instant from a `scheduled_at` column value.
DateTime? localKickoffFromScheduledAt(dynamic raw) {
  final dt = asDateTimeOrNull(raw);
  return dt?.toLocal();
}

/// `HH:mm` in local time — used by Mode Hub and match list cards.
String formatLocalKickoffTime(dynamic raw) {
  final local = localKickoffFromScheduledAt(raw);
  if (local == null) {
    return '—';
  }
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
