import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// A photo full screen: pinch to zoom, drag to move, ✕ / back to close.
/// Always black (like the Photos app), in light AND dark mode.
class ChatImageViewerPage extends StatelessWidget {
  const ChatImageViewerPage({super.key, this.url, this.localPath});

  final String? url;
  final String? localPath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      body: InteractiveViewer(
        minScale: 1,
        maxScale: 5,
        child: Center(
          child: localPath != null
              ? Image.file(File(localPath!), fit: BoxFit.contain)
              : CachedNetworkImage(
                  imageUrl: url ?? '',
                  fit: BoxFit.contain,
                  placeholder: (_, _) =>
                      const CircularProgressIndicator(color: Colors.white),
                  errorWidget: (_, _, _) => const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white54,
                    size: 48,
                  ),
                ),
        ),
      ),
    );
  }
}
