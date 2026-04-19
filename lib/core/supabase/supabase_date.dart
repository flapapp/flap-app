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
