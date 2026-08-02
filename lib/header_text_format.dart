/// The "Name: Value" per line text format the HTTP headers field uses -
/// shared between a data source's editor and an action element's, so both
/// read and write it identically.
String headersToText(Map<String, String> headers) =>
    [for (final entry in headers.entries) '${entry.key}: ${entry.value}']
        .join('\n');

Map<String, String> headersFromText(String text) {
  final headers = <String, String>{};
  for (final line in text.split('\n')) {
    final separator = line.indexOf(':');
    if (separator <= 0) continue;
    headers[line.substring(0, separator).trim()] = line
        .substring(separator + 1)
        .trim();
  }
  return headers;
}
