import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Raw byte storage for hotel photos.
///
/// Photos are the one thing the app caches that is **large**: a single
/// full-size hotel JPEG is 200KB–2MB, and a dozen of them used to live inside
/// the shared Hive box. Hive parses the whole box on the main isolate at
/// launch, so those bytes turned into seconds of cold start on a low-RAM
/// device. Encoded images now live as plain files (like Meta's Fresco disk
/// cache) and Hive only keeps a few bytes of metadata per photo.
abstract interface class HotelImageBlobStore {
  /// Reads the blob called [name], or null when it is missing/unreadable.
  Future<Uint8List?> read(String name);

  /// Writes [bytes] under [name]. Returns false when the write failed.
  Future<bool> write(String name, Uint8List bytes);

  /// Deletes [name]. Missing names are a no-op.
  Future<void> delete(String name);

  /// Every blob currently stored (used to sweep orphans).
  Future<List<String>> list();
}

/// File-backed store in the app's cache directory.
///
/// The directory is resolved lazily and once: it is a platform-channel call
/// that must never sit on the launch path. The OS is free to reclaim this
/// directory under storage pressure — every blob is re-downloadable.
class FileHotelImageBlobStore implements HotelImageBlobStore {
  FileHotelImageBlobStore({Future<Directory> Function()? directory})
    : _directory = directory ?? _defaultDirectory;

  static const String _folder = 'hotel_images';

  final Future<Directory> Function() _directory;
  Future<Directory>? _resolved;

  static Future<Directory> _defaultDirectory() async {
    final cache = await getApplicationCacheDirectory();
    return Directory('${cache.path}/$_folder');
  }

  Future<Directory> _dir() => _resolved ??= _directory();

  @override
  Future<Uint8List?> read(String name) async {
    try {
      final dir = await _dir();
      final file = File('${dir.path}/$name');
      if (!await file.exists()) return null;
      return await file.readAsBytes();
    } catch (_) {
      return null; // Best-effort: a broken blob is a cache miss.
    }
  }

  @override
  Future<bool> write(String name, Uint8List bytes) async {
    try {
      final dir = await _dir();
      if (!await dir.exists()) await dir.create(recursive: true);
      await File('${dir.path}/$name').writeAsBytes(bytes, flush: false);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> delete(String name) async {
    try {
      final dir = await _dir();
      final file = File('${dir.path}/$name');
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Best-effort.
    }
  }

  @override
  Future<List<String>> list() async {
    try {
      final dir = await _dir();
      if (!await dir.exists()) return const <String>[];
      return await dir
          .list()
          .where((entity) => entity is File)
          .map((entity) => entity.uri.pathSegments.last)
          .toList();
    } catch (_) {
      return const <String>[];
    }
  }
}

/// In-memory store for tests and for hosts without a file system.
class MemoryHotelImageBlobStore implements HotelImageBlobStore {
  final Map<String, Uint8List> _blobs = <String, Uint8List>{};

  @override
  Future<void> delete(String name) async {
    _blobs.remove(name);
  }

  @override
  Future<List<String>> list() async => _blobs.keys.toList();

  @override
  Future<Uint8List?> read(String name) async => _blobs[name];

  @override
  Future<bool> write(String name, Uint8List bytes) async {
    _blobs[name] = bytes;
    return true;
  }
}
