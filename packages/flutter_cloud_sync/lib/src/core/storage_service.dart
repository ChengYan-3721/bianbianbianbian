import 'dart:typed_data';

import 'package:meta/meta.dart';

/// Represents a file in cloud storage
@immutable
class CloudFile {
  /// File name
  final String name;

  /// Full file path
  final String path;

  /// File size in bytes (optional)
  final int? size;

  /// Last modified timestamp (optional)
  final DateTime? lastModified;

  /// Custom metadata (optional)
  ///
  /// Used to store fingerprint, version, etc.
  final Map<String, dynamic>? metadata;

  const CloudFile({
    required this.name,
    required this.path,
    this.size,
    this.lastModified,
    this.metadata,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CloudFile &&
          runtimeType == other.runtimeType &&
          path == other.path;

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() => 'CloudFile(name: $name, path: $path, size: $size)';
}

/// Abstract interface for cloud storage services
abstract class CloudStorageService {
  /// Upload data to cloud storage
  ///
  /// [path] - File path (e.g., 'users/123/data.json')
  /// [data] - File content as string
  /// [metadata] - Optional metadata map
  ///
  /// Throws [CloudStorageException] if upload fails.
  /// If file exists, it will be overwritten (upsert semantics).
  Future<void> upload({
    required String path,
    required String data,
    Map<String, String>? metadata,
  });

  /// Download data from cloud storage
  ///
  /// [path] - File path
  ///
  /// Returns file content as string, or null if file doesn't exist.
  /// Throws [CloudStorageException] if download fails (except 404).
  Future<String?> download({required String path});

  /// Delete file from cloud storage
  ///
  /// [path] - File path
  ///
  /// Throws [CloudStorageException] if deletion fails.
  /// Should be idempotent (no error if file doesn't exist).
  Future<void> delete({required String path});

  /// List files in a directory
  ///
  /// [path] - Directory path (e.g., 'users/123/')
  ///
  /// Returns list of files in the directory.
  /// Throws [CloudStorageException] if listing fails.
  Future<List<CloudFile>> list({required String path});

  /// Check if file exists
  ///
  /// [path] - File path
  ///
  /// Returns true if file exists, false otherwise.
  /// Throws [CloudStorageException] if check fails.
  Future<bool> exists({required String path});

  /// Get file metadata
  ///
  /// [path] - File path
  ///
  /// Returns file metadata, or null if file doesn't exist.
  /// Throws [CloudStorageException] if operation fails.
  Future<CloudFile?> getMetadata({required String path});

  // ---------------------------------------------------------------------------
  // Binary object API (Phase 11 — Attachment Cloud Sync)
  // ---------------------------------------------------------------------------
  // The methods above (`upload` / `download`) operate on UTF-8 strings — perfect
  // for JSON snapshots but lossy for image bytes. The methods below are the
  // binary-safe variants used by the attachment sync pipeline.
  //
  // Path convention (set by sync_service.dart): users/<uid>/attachments/<txId>/<sha256><ext>
  // Implementations MUST preserve byte-for-byte fidelity — no base64 wrapping,
  // no UTF-8 decoding.

  /// Upload raw bytes to cloud storage.
  ///
  /// [path] - Object path (e.g., 'users/abc/attachments/tx-1/aaa.jpg')
  /// [bytes] - File content as raw bytes
  /// [contentType] - Optional HTTP Content-Type (e.g., 'image/jpeg').
  ///                 Used by server for download Content-Type negotiation.
  /// [metadata] - Optional metadata map (same semantics as [upload]).
  ///
  /// Throws [CloudStorageException] if upload fails.
  /// If object exists, it will be overwritten (upsert semantics).
  Future<void> uploadBinary({
    required String path,
    required Uint8List bytes,
    String? contentType,
    Map<String, String>? metadata,
  });

  /// Download raw bytes from cloud storage.
  ///
  /// [path] - Object path
  ///
  /// Returns the object content as raw bytes, or null if it doesn't exist.
  /// Throws [CloudStorageException] if download fails (except 404).
  Future<Uint8List?> downloadBinary({required String path});

  /// Recursively list all objects under a prefix.
  ///
  /// Differs from [list] (which lists only one directory level): [listBinary]
  /// walks all subdirectories under [prefix] and returns every object
  /// reachable. Used by the orphan-object sweep (Phase 11.4) which compares
  /// remote object set against local DB metadata.
  ///
  /// [prefix] - Directory prefix (e.g., 'users/abc/attachments/').
  ///
  /// Returns a flat list of [CloudFile]s (no directory entries).
  /// Throws [CloudStorageException] if listing fails.
  Future<List<CloudFile>> listBinary({required String prefix});
}

/// No-op implementation for local-only mode
class NoopStorageService implements CloudStorageService {
  @override
  Future<void> upload({
    required String path,
    required String data,
    Map<String, String>? metadata,
  }) async {
    throw UnsupportedError('Storage is not configured');
  }

  @override
  Future<String?> download({required String path}) async {
    throw UnsupportedError('Storage is not configured');
  }

  @override
  Future<void> delete({required String path}) async {
    throw UnsupportedError('Storage is not configured');
  }

  @override
  Future<List<CloudFile>> list({required String path}) async {
    throw UnsupportedError('Storage is not configured');
  }

  @override
  Future<bool> exists({required String path}) async {
    throw UnsupportedError('Storage is not configured');
  }

  @override
  Future<CloudFile?> getMetadata({required String path}) async {
    throw UnsupportedError('Storage is not configured');
  }

  @override
  Future<void> uploadBinary({
    required String path,
    required Uint8List bytes,
    String? contentType,
    Map<String, String>? metadata,
  }) async {
    throw UnsupportedError('Storage is not configured');
  }

  @override
  Future<Uint8List?> downloadBinary({required String path}) async {
    throw UnsupportedError('Storage is not configured');
  }

  @override
  Future<List<CloudFile>> listBinary({required String prefix}) async {
    throw UnsupportedError('Storage is not configured');
  }
}
