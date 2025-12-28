import 'dart:html' as html;

void saveBytesAsFile(List<int> bytes, String filename, String mime) {
  final blob = html.Blob([bytes], mime);
  final url = html.Url.createObjectUrlFromBlob(blob);

  final a = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..style.display = 'none';

  html.document.body!.children.add(a);
  a.click();
  a.remove();

  html.Url.revokeObjectUrl(url);
}

