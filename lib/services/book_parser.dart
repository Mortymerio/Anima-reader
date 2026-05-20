import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:epubx/epubx.dart' as epub;
import 'package:image/image.dart' as img;
import 'epub_sanitizer.dart';

/// Result of parsing a book page/chapter.
class ParsedPage {
  final List<Widget> widgets;
  final int totalPages;

  const ParsedPage({required this.widgets, required this.totalPages});
}

/// Handles PDF and EPUB file parsing and content extraction.
///
/// Manages the lifecycle of PDF/EPUB documents including opening, page
/// extraction, and proper disposal to avoid memory leaks.
class BookParser {
  final EpubSanitizer _sanitizer;

  // PDF state
  PdfDocument? _syncfusionDoc;
  pdfx.PdfDocument? _pdfxDoc;

  // EPUB state
  epub.EpubBook? _epubBook;
  List<epub.EpubChapter> _flatChapters = [];

  BookParser({EpubSanitizer? sanitizer})
      : _sanitizer = sanitizer ?? const EpubSanitizer();

  // ─── Public getters ───

  bool get isPdfLoaded => _syncfusionDoc != null;
  bool get isEpubLoaded => _epubBook != null;

  int get totalPages {
    if (_syncfusionDoc != null) return _syncfusionDoc!.pages.count;
    if (_epubBook != null) return _flatChapters.length;
    return 0;
  }

  // ─── Loading ───

  /// Load a book from raw bytes. Detects format by file extension.
  Future<void> loadBook(List<int> bytes, String fileName) async {
    final name = fileName.toLowerCase();

    if (name.endsWith('.pdf')) {
      _syncfusionDoc = PdfDocument(inputBytes: bytes);
      _pdfxDoc = await pdfx.PdfDocument.openData(Uint8List.fromList(bytes));
    } else if (name.endsWith('.epub')) {
      final sanitizedBytes = _sanitizer.sanitize(bytes);
      _epubBook = await epub.EpubReader.readBook(sanitizedBytes);
      _flatChapters = _flattenChapters(_epubBook!.Chapters ?? []);
    }
  }

  // ─── PDF Extraction ───

  /// Extract text from a PDF page. Returns null if page has no extractable text.
  String? extractPdfText(int pageNumber) {
    if (_syncfusionDoc == null) return null;
    final pageIndex = (pageNumber - 1).clamp(0, _syncfusionDoc!.pages.count - 1);
    final text = PdfTextExtractor(_syncfusionDoc!).extractText(
      startPageIndex: pageIndex,
      endPageIndex: pageIndex,
    );
    return text.trim().isEmpty ? null : text;
  }

  /// Render a PDF page as an image. Returns raw JPEG bytes.
  Future<Uint8List?> renderPdfPageImage(int pageNumber) async {
    if (_pdfxDoc == null) return null;
    final pageIndex = (pageNumber - 1).clamp(0, _syncfusionDoc!.pages.count - 1);
    final page = await _pdfxDoc!.getPage(pageIndex + 1);
    try {
      final pageImage = await page.render(
        width: page.width * 2.0,
        height: page.height * 2.0,
        format: pdfx.PdfPageImageFormat.jpeg,
      );
      if (pageImage?.bytes == null) return null;
      return _cropImageMargins(pageImage!.bytes);
    } finally {
      await page.close();
    }
  }

  /// Helper to crop white margins from the page image
  Uint8List _cropImageMargins(Uint8List bytes) {
    final image = img.decodeImage(bytes);
    if (image == null) return bytes;

    int minX = image.width;
    int minY = image.height;
    int maxX = 0;
    int maxY = 0;

    // Scan the image to find the bounding box of non-white content
    // We scan with a step of 4 for performance.
    for (int y = 0; y < image.height; y += 4) {
      for (int x = 0; x < image.width; x += 4) {
        final pixel = image.getPixel(x, y);
        final r = img.getRed(pixel);
        final g = img.getGreen(pixel);
        final b = img.getBlue(pixel);

        // A pixel is considered non-white if any channel is below 240
        if (r < 240 || g < 240 || b < 240) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }

    // If no content was found (e.g. completely white page), return original
    if (maxX < minX || maxY < minY) {
      return bytes;
    }

    // Add some safety padding (e.g. 8 pixels) so we don't crop too close to text
    const padding = 8;
    minX = (minX - padding).clamp(0, image.width - 1);
    minY = (minY - padding).clamp(0, image.height - 1);
    maxX = (maxX + padding).clamp(0, image.width - 1);
    maxY = (maxY + padding).clamp(0, image.height - 1);

    final width = maxX - minX + 1;
    final height = maxY - minY + 1;

    if (width > 0 && height > 0 && (width < image.width || height < image.height)) {
      final cropped = img.copyCrop(image, minX, minY, width, height);
      final croppedBytes = img.encodeJpg(cropped, quality: 90);
      return Uint8List.fromList(croppedBytes);
    }

    return bytes;
  }

  // ─── EPUB Extraction ───

  /// Extract content widgets from an EPUB chapter.
  /// [pageNumber] is 1-indexed and maps to a chapter index.
  List<Widget> extractEpubContent(int pageNumber, double fontSize) {
    if (_epubBook == null || _flatChapters.isEmpty) return [];

    final chapterIndex = (pageNumber - 1).clamp(0, _flatChapters.length - 1);
    final chapter = _flatChapters[chapterIndex];
    final html = chapter.HtmlContent ?? '';
    final widgets = <Widget>[];
    final textStyle = TextStyle(
      color: null, // Will inherit from theme
      fontSize: fontSize,
      fontFamily: 'Serif',
      height: 1.5,
    );

    // Cover image on first page
    if (pageNumber == 1) {
      final coverImage = _findCoverImage();
      if (coverImage != null) {
        widgets.add(Image.memory(Uint8List.fromList(coverImage), fit: BoxFit.contain));
        widgets.add(const SizedBox(height: 24));
      }
    }

    // Parse inline images from HTML
    final imgRegex = RegExp(r'<img[^>]+src="([^"]+)"[^>]*>', caseSensitive: false);
    final matches = imgRegex.allMatches(html);

    int lastIndex = 0;
    for (final match in matches) {
      final textBefore = _stripHtml(html.substring(lastIndex, match.start));
      if (textBefore.isNotEmpty) {
        widgets.add(Text(textBefore, style: textStyle));
        widgets.add(const SizedBox(height: 16));
      }

      final imageWidget = _resolveEpubImage(match.group(1)!);
      if (imageWidget != null) {
        widgets.add(imageWidget);
        widgets.add(const SizedBox(height: 16));
      }
      lastIndex = match.end;
    }

    final textAfter = _stripHtml(html.substring(lastIndex));
    if (textAfter.isNotEmpty) {
      widgets.add(Text(textAfter, style: textStyle));
    }

    if (widgets.isEmpty) {
      widgets.add(Text('Chapter has no text or uses a complex format.', style: textStyle));
    }

    return widgets;
  }

  // ─── Cleanup ───

  /// Dispose all loaded documents. Call this in widget's dispose().
  void dispose() {
    _syncfusionDoc?.dispose();
    _syncfusionDoc = null;

    // Fix A4: pdfx document must also be closed to prevent memory leaks
    _pdfxDoc?.close();
    _pdfxDoc = null;

    _epubBook = null;
    _flatChapters = [];
  }

  // ─── Private helpers ───

  List<epub.EpubChapter> _flattenChapters(List<epub.EpubChapter> chapters) {
    final list = <epub.EpubChapter>[];
    for (final chapter in chapters) {
      list.add(chapter);
      if (chapter.SubChapters != null && chapter.SubChapters!.isNotEmpty) {
        list.addAll(_flattenChapters(chapter.SubChapters!));
      }
    }
    return list;
  }

  Uint8List? _findCoverImage() {
    if (_epubBook?.Content?.Images == null) return null;
    epub.EpubByteContentFile? coverFile;
    _epubBook!.Content!.Images!.forEach((key, value) {
      if (key.toLowerCase().contains('cover')) {
        coverFile = value;
      }
    });
    if (coverFile?.Content != null) {
      return Uint8List.fromList(coverFile!.Content!);
    }
    return null;
  }

  Widget? _resolveEpubImage(String src) {
    final imageName = src.split('/').last;
    epub.EpubByteContentFile? imageFile;
    _epubBook?.Content?.Images?.forEach((key, value) {
      if (key.endsWith(imageName) || imageName.endsWith(key)) {
        imageFile = value;
      }
    });
    if (imageFile?.Content != null) {
      return Image.memory(
        Uint8List.fromList(imageFile!.Content!),
        fit: BoxFit.contain,
      );
    }
    return null;
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .trim();
  }
}
