String normalizeGutendexSearchQuery(String query) {
  final trimmed = query.trim();
  final commaIndex = trimmed.indexOf(',');
  if (commaIndex < 0) return trimmed;

  final surname = trimmed.substring(0, commaIndex).trim();
  final givenNames = trimmed.substring(commaIndex + 1).trim();
  if (surname.isEmpty || givenNames.isEmpty) return trimmed;

  return '$givenNames $surname';
}
