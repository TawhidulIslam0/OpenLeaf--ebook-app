enum HttpFailure {
  notFound('404 not found'),
  timeout(
    'The catalog did not respond within 30 seconds. '
    'Check your internet connection and retry.',
  ),
  connection(
    'Could not connect to the book catalog. '
    'Check your internet connection and retry.',
  ),
  server('The catalog returned an error. Please try again.'),
  unknown('Could not load catalog data. Please try again.');

  final String description;
  const HttpFailure(this.description);
}
