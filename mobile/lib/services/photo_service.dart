import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Captures proof photos and keeps them in the app's documents directory so
/// the OS can't clear them (unlike the cache) before they are uploaded.
class PhotoService {
  final _picker = ImagePicker();

  Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'proof_photos'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Opens the camera. Returns the saved file path, or null if cancelled.
  /// Images are downscaled and compressed on capture (~150-300 KB).
  Future<String?> capture({
    required int tripId,
    required int supplierId,
  }) async {
    final shot = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 70,
    );
    if (shot == null) return null;

    final dir = await _dir();
    final name =
        'trip${tripId}_supplier${supplierId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final saved = await File(shot.path).copy(p.join(dir.path, name));
    return saved.path;
  }

  /// Saves a signature PNG next to the proof photos.
  Future<String> saveSignature(
    Uint8List png, {
    required int tripId,
    required int supplierId,
  }) async {
    final dir = await _dir();
    final name =
        'signature_trip${tripId}_supplier${supplierId}_${DateTime.now().millisecondsSinceEpoch}.png';
    final file = File(p.join(dir.path, name));
    await file.writeAsBytes(png, flush: true);
    return file.path;
  }

  Future<void> delete(String? path) async {
    if (path == null) return;
    final f = File(path);
    if (await f.exists()) await f.delete();
  }

  /// Housekeeping: removes photo files older than [days]. Uploaded photos
  /// live on the server, so old local copies are only clutter.
  Future<void> pruneOlderThan({int days = 14}) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    await for (final entity in (await _dir()).list()) {
      if (entity is File && (await entity.lastModified()).isBefore(cutoff)) {
        await entity.delete();
      }
    }
  }
}
