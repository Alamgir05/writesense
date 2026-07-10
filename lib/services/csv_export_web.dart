// Web implementation: trigger a browser file download using package:web
import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<void> saveAndShare(String content, String filename, String subject) async {
  final bytes = web.Blob(
    [content.toJS].toJS,
    web.BlobPropertyBag(type: 'text/csv'),
  );
  final url = web.URL.createObjectURL(bytes);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = filename;
  web.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}
