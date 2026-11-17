/// Validates external caption sources without storing secrets in logs.
Uri? parseExternalSubtitleUrl(String input) {
  final uri = Uri.tryParse(input.trim());
  if (uri == null ||
      !uri.hasAuthority ||
      (uri.scheme != 'https' && uri.scheme != 'http') ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return uri;
}
