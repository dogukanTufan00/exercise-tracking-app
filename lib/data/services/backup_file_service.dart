import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../backup/backup_json_codec.dart';

/// Yedek dosyalarını cihazla alışveriş eden servis.
///
/// ViewModel bu arayüzü kullanır; testlerde sahtesi verilir.
abstract interface class BackupFileService {
  /// Metni geçici bir dosyaya yazar ve paylaşım menüsünü açar.
  Future<void> shareTextFile({
    required String fileName,
    required String content,
    required String mimeType,
  });

  /// Sistemin "Farklı kaydet" ekranını açar; kullanıcı konumu seçince metni (UTF-8) oraya yazar.
  /// Kaydedildiyse `true`, kullanıcı vazgeçtiyse `false`.
  Future<bool> saveTextFile({
    required String fileName,
    required String content,
    required String mimeType,
  });

  /// Dosya seçiciyi açar; seçilen dosyanın metnini (UTF-8) döndürür. Kullanıcı vazgeçerse `null`.
  Future<String?> pickTextFile();
}

/// [BackupFileService]'in gerçek cihaz uygulaması (path_provider, share_plus, file_picker).
class DeviceBackupFileService implements BackupFileService {
  @override
  Future<void> shareTextFile({
    required String fileName,
    required String content,
    required String mimeType,
  }) async {
    final directory = await getTemporaryDirectory();
    final file = File(p.join(directory.path, fileName));
    await file.writeAsString(content, encoding: utf8);

    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path, mimeType: mimeType)]),
    );
  }

  @override
  Future<bool> saveTextFile({
    required String fileName,
    required String content,
    required String mimeType,
  }) async {
    final uri = await FilePicker.saveFile(
      fileName: fileName,
      bytes: Uint8List.fromList(utf8.encode(content)),
      mimeType: mimeType,
    );
    return uri != null;
  }

  @override
  Future<String?> pickTextFile() async {
    final file = await FilePicker.pickFile();
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    try {
      return utf8.decode(bytes);
    } on FormatException {
      throw const BackupFormatException(
        'Dosya okunamadı: geçerli bir yedek dosyası değil.',
      );
    }
  }
}
