import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// A short description's optional lead title and the paragraph(s) after
/// it, matching how the website renders WooCommerce's short_description:
/// a bold lead line (the product's own `<p><strong>...</strong></p>`),
/// followed by the descriptive paragraph(s). [title] is empty when the
/// source HTML doesn't follow that convention (a single wholly-bold
/// leading paragraph) -- callers should fall back to showing [body] alone.
class ParsedDescription {
  final String title;
  final String body;

  const ParsedDescription({required this.title, required this.body});
}

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

  /// Splits a short_description's HTML into a bold lead title and the body
  /// paragraph(s) below it, the way the website itself presents it.
  static ParsedDescription splitLeadTitle(String htmlString) {
    if (htmlString.isEmpty) {
      return const ParsedDescription(title: '', body: '');
    }

    try {
      final elements = html_parser
          .parse(htmlString)
          .body!
          .children
          .where((el) => el.text.trim().isNotEmpty)
          .toList();

      if (elements.isEmpty) {
        return ParsedDescription(title: '', body: stripHtmlTags(htmlString));
      }

      final dom.Element lead = elements.first;
      final leadText = _decodeHtmlEntities(lead.text).trim();
      // "Wholly bold" -- every bit of this element's text lives inside a
      // <strong>/<b> descendant -- is the signal this paragraph is a lead
      // title rather than the first line of body copy.
      final boldText = lead
          .querySelectorAll('strong, b')
          .map((e) => e.text)
          .join();
      final isWhollyBold =
          elements.length > 1 &&
          _decodeHtmlEntities(boldText).trim() == leadText;

      if (!isWhollyBold) {
        return ParsedDescription(title: '', body: stripHtmlTags(htmlString));
      }

      final body = elements
          .skip(1)
          .map((el) => _decodeHtmlEntities(el.text).trim())
          .where((text) => text.isNotEmpty)
          .join('\n\n');

      return ParsedDescription(title: leadText, body: body);
    } catch (e) {
      return ParsedDescription(title: '', body: stripHtmlTags(htmlString));
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
