import 'package:html/parser.dart' as html_parser;

class StringUtils {
  /// Remove HTML tags from a string and decode HTML entities
  static String stripHtmlTags(String htmlString) {
    if (htmlString.isEmpty) return '';

    try {
      final document = html_parser.parse(htmlString);
      final parsedString = document.body?.text ?? '';

      // Decode common HTML entities
      return _decodeHtmlEntities(parsedString).trim();
    } catch (e) {
      // If parsing fails, do a simple regex replacement
      return htmlString.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    }
  }

  /// Decode common HTML entities
  static String _decodeHtmlEntities(String text) {
    return text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&apos;', "'");
  }
}
