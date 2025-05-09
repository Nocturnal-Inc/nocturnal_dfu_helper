import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_archive/flutter_archive.dart';
import 'package:mcumgr_flutter/mcumgr_flutter.dart' as mcumgr;
import 'package:nocturnal_dfu/src/models/manifest.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:uuid/uuid.dart';

class UpgradeStatus {
  late mcumgr.FirmwareUpgradeState state;
  late String message;

  UpgradeStatus(this.state, this.message);
}

/// Checks if you are awesome. Spoiler: you are.
class NocturnalDFU {
  late String deviceId;
  late Uint8List fileContents;
  mcumgr.FirmwareUpdateManager? updateManager;

  NocturnalDFU({required this.deviceId, required this.fileContents});

  /// deviceId = UUID of the nrf5* ble device
  void update(void Function(UpgradeStatus) cb) async {
    try {
      final managerFactory = mcumgr.FirmwareUpdateManagerFactory();

      updateManager = await managerFactory.getUpdateManager(deviceId);

      updateManager!.setup();

      var firmwareImages = await getFiles(fileContents);

      updateManager!.update(firmwareImages);

      var upgradeState = mcumgr.FirmwareUpgradeState.none;

      updateManager!.updateStateStream?.listen((event) {
        upgradeState = event;
      });

      updateManager!.progressStream.listen((event) {
        cb(
          UpgradeStatus(
            upgradeState,
            "${event.bytesSent} / ${event.imageSize}} bytes sent",
          ),
        );
      });

      updateManager!.logger.logMessageStream
          .where((log) => log.level.rawValue > 1) // filter out debug messages
          .listen((log) {
            cb(UpgradeStatus(upgradeState, log.message));
          });
    } catch (e) {
      print(e);
      cb(
        UpgradeStatus(
          mcumgr.FirmwareUpgradeState.none,
          "failed to update. Error: $e",
        ),
      );
    }
  }

  Future<List<mcumgr.Image>> getFiles(Uint8List fileContent) async {
    final prefix = 'firmware_${Uuid().v4()}';
    final systemTempDir = await path_provider.getTemporaryDirectory();

    final tempDir = Directory('${systemTempDir.path}/$prefix');
    await tempDir.create();

    final firmwareFileData = fileContent;
    final firmwareFile = File('${tempDir.path}/firmware.zip');
    await firmwareFile.writeAsBytes(firmwareFileData);

    final destinationDir = Directory('${tempDir.path}/firmware');
    await destinationDir.create();
    try {
      await ZipFile.extractToDirectory(
        zipFile: firmwareFile,
        destinationDir: destinationDir,
      );
    } catch (e) {
      throw Exception('Failed to unzip firmware');
    }

    // read manifest.json
    final manifestFile = File('${destinationDir.path}/manifest.json');
    final manifestString = await manifestFile.readAsString();
    Map<String, dynamic> manifestJson = json.decode(manifestString);
    Manifest manifest;

    try {
      manifest = Manifest.fromJson(manifestJson);
    } catch (e) {
      throw Exception('Failed to parse manifest.json');
    }

    List<mcumgr.Image> firmwareImages = [];
    for (final file in manifest.files) {
      final firmwareFile = File('${destinationDir.path}/${file.file}');
      final firmwareFileData = await firmwareFile.readAsBytes();
      final image = mcumgr.Image(image: file.image, data: firmwareFileData);

      firmwareImages.add(image);
    }

    // delete tempDir
    await tempDir.delete(recursive: true);

    return firmwareImages;
  }

  void dispose() {
    if (updateManager != null) {
      updateManager!.kill();
    }
  }
}
