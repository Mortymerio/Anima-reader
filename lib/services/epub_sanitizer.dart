import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';

/// Sanitizes EPUB files by decoding URL-encoded paths in .opf and .ncx files.
///
/// Some EPUB generators produce percent-encoded hrefs (e.g. "Chapter%201.xhtml")
/// in the manifest/spine that certain parsers can't resolve. This class fixes
/// that by decoding those paths before the EPUB is parsed.
class EpubSanitizer {
  const EpubSanitizer();

  /// Returns sanitized bytes if modifications were needed, otherwise the original bytes.
  List<int> sanitize(List<int> bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final newArchive = Archive();
      bool modified = false;

      for (final file in archive) {
        if (file.isFile && _isManifestFile(file.name)) {
          final contentBytes = file.content as List<int>;
          final contentString = utf8.decode(contentBytes);
          final decodedContent = _decodeHrefs(contentString);

          if (decodedContent != contentString) {
            final newContentBytes = utf8.encode(decodedContent);
            newArchive.addFile(ArchiveFile(
              file.name,
              newContentBytes.length,
              newContentBytes,
            ));
            modified = true;
          } else {
            newArchive.addFile(file);
          }
        } else {
          newArchive.addFile(file);
        }
      }

      if (modified) {
        final encodedBytes = ZipEncoder().encode(newArchive);
        if (encodedBytes != null) return encodedBytes;
      }
    } catch (e) {
      debugPrint('EpubSanitizer: Error sanitizing EPUB bytes: $e');
    }
    return bytes;
  }

  bool _isManifestFile(String name) {
    return name.endsWith('.opf') || name.endsWith('.ncx');
  }

  String _decodeHrefs(String content) {
    return content.replaceAllMapped(
      RegExp(r'(href|src)="([^"]+)"'),
      (match) {
        final attr = match.group(1);
        final val = match.group(2)!;
        try {
          final decodedVal = Uri.decodeFull(val);
          return '$attr="$decodedVal"';
        } catch (_) {
          return match.group(0)!;
        }
      },
    );
  }
}
