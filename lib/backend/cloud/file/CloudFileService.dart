import 'dart:convert';
import 'dart:typed_data';

import 'package:googleapis/drive/v3.dart' as drive;

import 'package:mira_finance_tracker/backend/cloud/connection/DriveHttpHandler.dart';

/// Class to handle the operations on files and folder
/// for every other instance
class CloudFileService {
  final String _email;
  late final DriveHttpHandler _client;
  late final drive.DriveApi _driveApi;

  /// Cloud file service requiring the [_email] of the user
  /// and the [_client] to handle the http requests
  CloudFileService({
    required this._email,
    required this._client,
  }){
    _driveApi = drive.DriveApi(_client);
  }

  String get email => _email;

  // ===========================================================================
  // READING METHODS
  // ===========================================================================

  /// Downloads the whole file content as bytes in memory
  /// starting from the [fileId] given
  Future<Uint8List> readBytes(String fileId) async {
    final media = await _driveApi.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final chunks = <int>[];
    await for (final chunk in media.stream) {
      chunks.addAll(chunk);
    }
    return Uint8List.fromList(chunks);
  }

  /// Read a file and returns its content as a string
  /// starting from the [fileId] given
  Future<String> readText(String fileId) async {
    final bytes = await readBytes(fileId);
    return utf8.decode(bytes);
  }

  /// Read a file a decodes its content as a json object
  /// starting from the [fileId] given
  Future<Map<String, dynamic>> readJson(String fileId) async {
    final text = await readText(fileId);
    return jsonDecode(text) as Map<String, dynamic>;
  }

  /// Recover the metadata expressed in the [fields]
  /// starting from the [fileId] given
  Future<drive.File> getMetadata(
    String fileId, {
    String fields = 'id,name,mimeType,size,modifiedTime,parents',
  }) async {
    return (await _driveApi.files.get(fileId, $fields: fields)) as drive.File;
  }

  /// Read a file by [name] and returns the first match found, 
  /// or null if it's not found. 
  /// [folderId] and [trashed] are optional and represent respectively 
  /// the folder where the file has been saved in and the trashed state of the file
  Future<drive.File?> findByName(
    String name, {
    String? folderId,
    bool trashed = false,
  }) async {
    final results = await listFiles(
      query: "name = '${_escape(name)}' and trashed = $trashed",
      folderId: folderId,
      pageSize: 1,
    );
    return results.isEmpty ? null : results.first;
  }

  /// List file and folders in the drive,
  /// optionally filtered by a [query] and/or a [folderId]
  Future<List<drive.File>> listFiles({
    String? query,
    String? folderId,
    int pageSize = 100,
    String? pageToken,
    String fields = 'nextPageToken,files(id,name,mimeType,size,modifiedTime,parents)',
  }) async {
    String? q;
    if (folderId != null && query != null) {
      q = "'$folderId' in parents and $query";
    } else if (folderId != null) {
      q = "'$folderId' in parents";
    } else {
      q = query;
    }

    final result = await _driveApi.files.list(
      q: q,
      pageSize: pageSize,
      pageToken: pageToken,
      $fields: fields,
    );
    return result.files ?? [];
  }

  /// Function to find a folder by its [folderName]
  Future<drive.File?> findFolderByName(String folderName) async {
    final folder = await listFiles(
      query: "name = 'Backup' and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
    );

    if (folder.isNotEmpty) {
      return folder.first;
    }
    return null;
  }

  // ===========================================================================
  //  WRITING
  // ===========================================================================

  /// Creating file starting from the [fileName] and the [bytes] given
  Future<drive.File> createBytes({
    required String fileName,
    required List<int> bytes,
    String? mimeType,
    String? parentFolderId,
  }) async {
    final media = drive.Media(Stream.value(bytes), bytes.length);

    final metadata = drive.File()
      ..name = fileName
      ..mimeType = mimeType ?? 'application/octet-stream';

    if (parentFolderId != null) {
      metadata.parents = [parentFolderId];
    }

    return _driveApi.files.create(metadata, uploadMedia: media);
  }

  /// Create a text file startin from the [fileName] and text [content] given,
  /// optionally specifying the [parentFolderId] where to save it
  Future<drive.File> createText({
    required String fileName,
    required String content,
    String? parentFolderId,
  }) {
    return createBytes(
      fileName: fileName,
      bytes: utf8.encode(content),
      mimeType: 'text/plain',
      parentFolderId: parentFolderId,
    );
  }

  /// Create a JSON File with [fileName], the corresponding map [content],
  /// optionally specifing the [parentFolderId]
  Future<drive.File> createJson({
    required String fileName,
    required Map<String, dynamic> content,
    String? parentFolderId,
  }) {
    return createBytes(
      fileName: fileName,
      bytes: utf8.encode(jsonEncode(content)),
      mimeType: 'application/json',
      parentFolderId: parentFolderId,
    );
  }

  /// Create folder specifting the [folderName]
  /// and optionally the [parentFolderId]
  Future<drive.File> createFolder({
    required String folderName,
    String? parentFolderId,
  }) {
    final folder = drive.File()
      ..name = folderName
      ..mimeType = 'application/vnd.google-apps.folder';

    if (parentFolderId != null) {
      folder.parents = [parentFolderId];
    }

    return _driveApi.files.create(folder);
  }

  // ===========================================================================
  // UPDATE
  // ===========================================================================

  /// Override the content of an existing file using [bytes] provided.
  /// Optionally give a [mimeType] to express the type of file to replace
  /// in order to check it.
  Future<drive.File> updateBytes({
    required String fileId,
    required List<int> bytes,
    String? mimeType,
  }) async {
    final media = drive.Media(Stream.value(bytes), bytes.length);

    final metadata = drive.File();
    if (mimeType != null) metadata.mimeType = mimeType;

    return _driveApi.files.update(
      metadata,
      fileId,
      uploadMedia: media,
    );
  }

  /// Overrides file with a new text [content]
  Future<drive.File> updateText({
    required String fileId,
    required String content,
  }) {
    return updateBytes(
      fileId: fileId,
      bytes: utf8.encode(content),
      mimeType: 'text/plain',
    );
  }

  /// Update metadata file (such as the [newName])
  /// without affecting the content
  Future<drive.File> rename({
    required String fileId,
    required String newName,
  }) {
    final metadata = drive.File()..name = newName;
    return _driveApi.files.update(metadata, fileId);
  }

  /// Move files to another folder
  /// Keeps previous parents only if [keepPreviousParents] is true.
  Future<drive.File> moveToFolder({
    required String fileId,
    required String newFolderId,
    bool keepPreviousParents = false,
  }) async {
    final current = await getMetadata(fileId, fields: 'parents');
    final previousParents = current.parents?.join(',') ?? '';

    return _driveApi.files.update(
      drive.File(),
      fileId,
      addParents: newFolderId,
      removeParents: keepPreviousParents ? null : previousParents,
      $fields: 'id,name,parents',
    );
  }

  /// Copy an existing file, optionally 
  /// renaming and moving it
  Future<drive.File> copyFile({
    required String fileId,
    String? newName,
    String? parentFolderId,
  }) {
    final metadata = drive.File();
    if (newName != null) metadata.name = newName;
    if (parentFolderId != null) metadata.parents = [parentFolderId];

    return _driveApi.files.copy(metadata, fileId);
  }

  // ===========================================================================
  // DELETION
  // ===========================================================================

  /// Definitely eliminating the file (without trashing it)
  Future<void> delete(String fileId) async {
    await _driveApi.files.delete(fileId);
  }

  /// Move a file to to trash (restorable)
  Future<drive.File> trash(String fileId) {
    return _driveApi.files.update(drive.File()..trashed = true, fileId);
  }

  /// Restore files from trash bin
  Future<drive.File> restore(String fileId) {
    return _driveApi.files.update(drive.File()..trashed = false, fileId);
  }

  /// Empty trash
  Future<void> emptyTrash() async {
    await _driveApi.files.emptyTrash();
  }

  // ===========================================================================
  // UTILITY
  // ===========================================================================
  String _escape(String value) => value.replaceAll("'", r"\'");
}