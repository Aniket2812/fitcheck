/// Turns transport and implementation errors into calm, user-facing copy.
///
/// Feature-specific screens should pass a fallback that explains what the
/// person can do next. Useful validation messages are kept as-is.
String userFacingError(
  Object error, {
  String fallback = 'That didn’t work this time. Give it another go.',
}) {
  final message = error
      .toString()
      .replaceFirst(RegExp(r'^(Exception|FormatException):\s*'), '')
      .trim();
  if (message.isEmpty) return fallback;

  final technical = message.toLowerCase();
  const hiddenTerms = <String>[
    'backend',
    'server',
    'provider',
    'wireless debugging',
    'socketexception',
    'clientexception',
    'clientconnection',
    'timeoutexception',
    'future not completed',
    'connection refused',
    'connection closed',
    'failed host lookup',
    'uri=http',
    '/api/',
    'status code',
    'http 4',
    'http 5',
  ];
  if (hiddenTerms.any(technical.contains)) return fallback;
  return message;
}
