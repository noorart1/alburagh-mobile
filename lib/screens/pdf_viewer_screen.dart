import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import '../core/constants.dart';
import '../core/theme/app_colors.dart';

/// Downloads [url] to a local temp file and displays it with [PDFView],
/// since flutter_pdfview only renders from a local file path, not a network
/// URL directly.
class PdfViewerScreen extends StatefulWidget {
  final String title;
  final String url;

  const PdfViewerScreen({super.key, required this.title, required this.url});

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final Dio _dio = Dio();
  String? _localPath;
  String? _error;

  @override
  void initState() {
    super.initState();
    _download();
  }

  Future<void> _download() async {
    try {
      final dir = await getTemporaryDirectory();
      final fileName = widget.url.split('/').last;
      final file = File('${dir.path}/$fileName');

      if (!await file.exists()) {
        await _dio.download(widget.url, file.path);
      }

      if (!mounted) return;
      setState(() => _localPath = file.path);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'تعذر تحميل الملف');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: primaryColor,
      ),
      body: _error != null
          ? Center(
              child: Text(_error!, style: const TextStyle(color: AppColors.error)),
            )
          : _localPath == null
          ? const Center(child: CircularProgressIndicator())
          : PDFView(filePath: _localPath!),
    );
  }
}
