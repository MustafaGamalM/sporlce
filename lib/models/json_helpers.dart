int jsonInt(Object? value, {int fallback = 0}) {
  return value is num ? value.toInt() : fallback;
}

int? jsonOptionalInt(Object? value) {
  return value is num ? value.toInt() : null;
}
