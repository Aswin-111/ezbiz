import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_core/theme.dart';

class PdfPreviewScreen extends StatelessWidget {
  final File pdfFile;

  const PdfPreviewScreen({Key? key, required this.pdfFile}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!pdfFile.existsSync()) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: const Text('Order Bill', style: TextStyle(color: Colors.black)),
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        body: const Center(child: Text('PDF file does not exist.')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Text('Order Bill', style: TextStyle(color: Colors.black)),
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => Share.shareXFiles([
              XFile(
                pdfFile.path,
                mimeType: 'application/pdf',
                name: 'order_bill.pdf',
              ),
            ]),
          ),
        ],
      ),
      body: SfPdfViewerTheme(
        data: const SfPdfViewerThemeData(
          backgroundColor: Colors.white, // 👈 THIS controls that lavender zone
        ),
        child: SfPdfViewer.file(
          pdfFile,
          canShowScrollHead: false,
          canShowScrollStatus: false,
        ),
      ),
    );
  }
}
