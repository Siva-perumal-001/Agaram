import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

import '../models/wallet_doc.dart';
import 'wallet_service.dart';

class DriveArchiveProgress {
  final int done;
  final int total;
  final int failed;
  final String? currentFileName;

  const DriveArchiveProgress({
    required this.done,
    required this.total,
    required this.failed,
    this.currentFileName,
  });
}

class DriveArchiveResult {
  final String folderId;
  final int uploaded;
  final int failed;
  final List<String> failedNames;

  const DriveArchiveResult({
    required this.folderId,
    required this.uploaded,
    required this.failed,
    required this.failedNames,
  });

  String get folderUrl => 'https://drive.google.com/drive/folders/$folderId';
}

class DriveSignInCancelled implements Exception {
  final String message = 'Google sign-in cancelled.';
  @override
  String toString() => message;
}

class DriveService {
  static const _rootFolderName = 'Agaram';
  static const _folderMimeType = 'application/vnd.google-apps.folder';

  static final GoogleSignIn _signIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveFileScope],
  );

  /// Signs in (interactive if needed) and returns an authenticated Drive API
  /// client. Throws [DriveSignInCancelled] if the user aborts.
  static Future<_DriveClient> _authenticate() async {
    GoogleSignInAccount? account = await _signIn.signInSilently();
    account ??= await _signIn.signIn();
    if (account == null) throw DriveSignInCancelled();
    final headers = await account.authHeaders;
    final inner = http.Client();
    final authed = _AuthedClient(headers, inner);
    return _DriveClient(drive.DriveApi(authed), inner, account);
  }

  /// Archives every wallet doc of [eventId] into
  /// `Agaram / {eventDate.year} / {eventName}` on the signed-in user's Drive.
  /// Existing folders are reused; files are uploaded anew on every run.
  static Future<DriveArchiveResult> archiveWalletDocs({
    required String eventId,
    required String eventName,
    required DateTime eventDate,
    void Function(DriveArchiveProgress)? onProgress,
  }) async {
    final client = await _authenticate();
    try {
      final snap = await WalletService.collection(eventId).get();
      final docs = snap.docs.map(WalletDoc.fromFirestore).toList();
      final total = docs.length;

      final folderId = await _ensureFolderPath(
        client.api,
        [_rootFolderName, eventDate.year.toString(), eventName],
      );

      onProgress?.call(DriveArchiveProgress(
          done: 0, total: total, failed: 0, currentFileName: null));

      var uploaded = 0;
      var failed = 0;
      final failedNames = <String>[];

      for (final doc in docs) {
        final name = _driveFileName(doc);
        onProgress?.call(DriveArchiveProgress(
          done: uploaded,
          total: total,
          failed: failed,
          currentFileName: name,
        ));
        try {
          final bytes = await _downloadBytes(doc.url);
          await _uploadBytes(
            api: client.api,
            folderId: folderId,
            fileName: name,
            bytes: bytes,
            mimeType: _mimeFor(doc),
          );
          uploaded++;
        } catch (_) {
          failed++;
          failedNames.add(name);
        }
      }

      onProgress?.call(DriveArchiveProgress(
        done: uploaded,
        total: total,
        failed: failed,
      ));

      return DriveArchiveResult(
        folderId: folderId,
        uploaded: uploaded,
        failed: failed,
        failedNames: failedNames,
      );
    } finally {
      client.close();
    }
  }

  static Future<String> _ensureFolderPath(
    drive.DriveApi api,
    List<String> path,
  ) async {
    String? parentId;
    for (final name in path) {
      parentId = await _findOrCreateFolder(api, name: name, parentId: parentId);
    }
    return parentId!;
  }

  static Future<String> _findOrCreateFolder(
    drive.DriveApi api, {
    required String name,
    String? parentId,
  }) async {
    final escaped = name.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
    final parentClause =
        parentId != null ? "and '$parentId' in parents " : '';
    final q =
        "name = '$escaped' and mimeType = '$_folderMimeType' ${parentClause}and trashed = false";
    final list = await api.files.list(
      q: q,
      $fields: 'files(id,name)',
      spaces: 'drive',
    );
    final existing = list.files;
    if (existing != null && existing.isNotEmpty && existing.first.id != null) {
      return existing.first.id!;
    }
    final folder = drive.File()
      ..name = name
      ..mimeType = _folderMimeType
      ..parents = parentId != null ? [parentId] : null;
    final created = await api.files.create(folder);
    if (created.id == null) {
      throw StateError('Drive did not return an ID for folder "$name".');
    }
    return created.id!;
  }

  static Future<String> _uploadBytes({
    required drive.DriveApi api,
    required String folderId,
    required String fileName,
    required List<int> bytes,
    required String mimeType,
  }) async {
    final file = drive.File()
      ..name = fileName
      ..parents = [folderId];
    final media = drive.Media(
      Stream.value(bytes),
      bytes.length,
      contentType: mimeType,
    );
    final created = await api.files.create(file, uploadMedia: media);
    if (created.id == null) {
      throw StateError('Drive did not return an ID for file "$fileName".');
    }
    return created.id!;
  }

  static Future<List<int>> _downloadBytes(String url) async {
    final resp = await http.get(Uri.parse(url));
    if (resp.statusCode != 200) {
      throw StateError('Download failed: HTTP ${resp.statusCode}');
    }
    return resp.bodyBytes;
  }

  static String _driveFileName(WalletDoc doc) {
    final raw = doc.fileName;
    if (raw != null && raw.trim().isNotEmpty) return raw;
    final ext = doc.type == WalletDocType.pdf ? 'pdf' : 'jpg';
    final fromTitle = doc.title.trim();
    if (fromTitle.isEmpty) return 'document-${doc.id}.$ext';
    return fromTitle.endsWith('.$ext') ? fromTitle : '$fromTitle.$ext';
  }

  static String _mimeFor(WalletDoc doc) {
    if (doc.type == WalletDocType.pdf) return 'application/pdf';
    final lower = doc.url.toLowerCase().split('?').first;
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }
}

class _DriveClient {
  final drive.DriveApi api;
  final http.Client _inner;
  final GoogleSignInAccount account;
  _DriveClient(this.api, this._inner, this.account);
  void close() => _inner.close();
}

class _AuthedClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner;
  _AuthedClient(this._headers, this._inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }

  @override
  void close() {}
}
