// Create file: lib/screens/qr_code_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:ui' as ui;
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class QRCodeScreen extends StatefulWidget {
  final String bagCode;
  final String bagName;
  
  const QRCodeScreen({
    super.key, 
    required this.bagCode, 
    this.bagName = '',
  });

  @override
  State<QRCodeScreen> createState() => _QRCodeScreenState();
}

class _QRCodeScreenState extends State<QRCodeScreen> {
  final GlobalKey _qrKey = GlobalKey();
  bool _isSaving = false;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('QR Code: ${widget.bagCode}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _saveAndShareQRCode,
            tooltip: 'Share QR Code',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RepaintBoundary(
              key: _qrKey,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    QrImageView(
                      data: widget.bagCode,
                      version: QrVersions.auto,
                      size: 200,
                      backgroundColor: Colors.white,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.bagCode,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    if (widget.bagName.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        widget.bagName,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            if (_isSaving)
              const CircularProgressIndicator()
            else
              const Text('Scan this code to look up the bag'),
          ],
        ),
      ),
    );
  }
  
  Future<void> _saveAndShareQRCode() async {
    try {
      setState(() => _isSaving = true);
      
      // Capture QR code as image
      RenderRepaintBoundary boundary = _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData != null) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/bag_${widget.bagCode}.png');
        await file.writeAsBytes(byteData.buffer.asUint8List());
        
        await Share.shareXFiles([XFile(file.path)], text: 'Bag Code: ${widget.bagCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing QR code: $e')),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }
}