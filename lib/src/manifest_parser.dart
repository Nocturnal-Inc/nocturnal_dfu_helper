import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:nocturnal_dfu/src/models/ota_manifest.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

Future<(OTAManifest?, String, String?)> extractAndReadManifest(
  String zipFilePath,
) async {
  try {
    final Directory tempDir = await getTemporaryDirectory();
    final String outputDirPath = p.join(tempDir.path, 'unzipped_bundle');

    // Create/clear output directory
    final outDir = Directory(outputDirPath);
    if (await outDir.exists()) {
      await outDir.delete(recursive: true);
    }
    await outDir.create(recursive: true);

    final zipBytes = await File(zipFilePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(zipBytes);

    for (final file in archive) {
      final String outFilePath = p.join(outputDirPath, file.name);
      if (file.isFile) {
        final outFile = File(outFilePath)..createSync(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>);
      } else {
        await Directory(outFilePath).create(recursive: true);
      }
    }

    final manifestFile = File(p.join(outputDirPath, 'manifest.json'));
    if (await manifestFile.exists()) {
      final jsonStr = await manifestFile.readAsString().timeout(
        Duration(seconds: 3),
      );
      final manifest = OTAManifest.fromJson(jsonDecode(jsonStr));
      return (manifest, outputDirPath, null);
    }

    return (null, outputDirPath, null);
  } catch (e, s) {
    return (null, "", "Error: $e | Stacktrace: $s");
  }
}
