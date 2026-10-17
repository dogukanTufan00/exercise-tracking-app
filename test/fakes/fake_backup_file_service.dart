import 'dart:async';

import 'package:exercise_tracking_app/data/services/backup_file_service.dart';

/// Paylaşılan bir metin dosyasının kaydı.
class SharedTextFile {
  const SharedTextFile({
    required this.fileName,
    required this.content,
    required this.mimeType,
  });

  final String fileName;
  final String content;
  final String mimeType;
}

/// Testler için bellekte çalışan [BackupFileService].
///
/// Paylaşılan dosyalar [sharedFiles] listesinde tutulur. [pickResult] seçilecek dosyanın
/// metnidir; `null` ise kullanıcı vazgeçmiş gibi davranır.
class FakeBackupFileService implements BackupFileService {
  final List<SharedTextFile> sharedFiles = [];

  /// [pickTextFile]'ın döndüreceği metin; `null` = vazgeçildi.
  String? pickResult;

  /// Doluysa, işlemler bu tamamlanana kadar bekler (meşgul durumunu test etmek için).
  Completer<void>? gate;

  @override
  Future<void> shareTextFile({
    required String fileName,
    required String content,
    required String mimeType,
  }) async {
    await gate?.future;
    sharedFiles.add(
      SharedTextFile(fileName: fileName, content: content, mimeType: mimeType),
    );
  }

  @override
  Future<String?> pickTextFile() async {
    await gate?.future;
    return pickResult;
  }
}
