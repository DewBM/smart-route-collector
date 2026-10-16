import 'dart:io';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_tokens.dart';

/// Thumbnail of a collection's proof photo, from the local file if present
/// (today's trip) or the server URL (history). Tap to view full screen.
class ProofPhoto extends StatelessWidget {
  const ProofPhoto({super.key, this.localPath, this.url, this.height = 120});

  final String? localPath;
  final String? url;
  final double height;

  bool get _hasLocal => localPath != null && File(localPath!).existsSync();
  bool get hasPhoto => _hasLocal || url != null;

  ImageProvider? get _provider {
    if (_hasLocal) return FileImage(File(localPath!));
    if (url != null) return NetworkImage(ApiService.absoluteUrl(url!));
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final provider = _provider;
    if (provider == null) return const SizedBox.shrink();

    return Semantics(
      button: true,
      label: 'Proof photo. Tap to enlarge.',
      child: GestureDetector(
        onTap: () => showDialog(
          context: context,
          builder: (_) => _Viewer(provider: provider),
        ),
        child: ClipRRect(
          borderRadius: Corners.mdAll,
          child: Image(
            image: provider,
            height: height,
            width: double.infinity,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : Container(
                    height: height,
                    color: context.colors.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  ),
            errorBuilder: (context, _, _) => Container(
              height: height,
              color: context.colors.surfaceContainerHighest,
              alignment: Alignment.center,
              child: Icon(
                Icons.broken_image_outlined,
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Viewer extends StatelessWidget {
  const _Viewer({required this.provider});

  final ImageProvider provider;

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              maxScale: 5,
              child: Center(child: Image(image: provider)),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(Gap.md),
              child: IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
