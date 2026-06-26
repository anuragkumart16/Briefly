import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_app_file/open_app_file.dart';
import '../config.dart';

class UpdateInfo {
  final String version;
  final int buildNumber;
  final String url;
  final String releaseNotes;
  final bool mandatory;

  UpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.url,
    required this.releaseNotes,
    required this.mandatory,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      version: json['version'] ?? '',
      buildNumber: json['buildNumber'] ?? 0,
      url: json['url'] ?? '',
      releaseNotes: json['releaseNotes'] ?? '',
      mandatory: json['mandatory'] ?? false,
    );
  }
}

class UpdateService {
  /// Checks the backend for a newer version of the app.
  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.backendUrl}/api/v1/update/check?platform=android'),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] != null) {
          final info = UpdateInfo.fromJson(body['data']);
          final packageInfo = await PackageInfo.fromPlatform();
          
          final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
          
          if (info.buildNumber > currentBuild) {
            return info;
          }
        }
      }
    } catch (e) {
      print('Error checking for updates: $e');
    }
    return null;
  }

  /// Downloads the APK file to local temporary storage and reports progress.
  static Future<File?> downloadApk(String url, Function(double) onProgress) async {
    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        return null;
      }

      final contentLength = response.contentLength ?? 0;
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/briefly-update.apk';
      final file = File(filePath);
      
      if (await file.exists()) {
        await file.delete();
      }

      final fileSink = file.openWrite();
      int downloaded = 0;

      await for (var chunk in response.stream) {
        fileSink.add(chunk);
        downloaded += chunk.length;
        if (contentLength > 0) {
          onProgress(downloaded / contentLength);
        }
      }

      await fileSink.flush();
      await fileSink.close();
      client.close();
      return file;
    } catch (e) {
      print('Error downloading APK: $e');
    }
    return null;
  }

  /// Launches Android's Package Installer to run the sideloaded update.
  static Future<void> installApk(String filePath) async {
    try {
      final result = await OpenAppFile.open(filePath);
      print('Install result: ${result.type} - ${result.message}');
    } catch (e) {
      print('Error installing APK: $e');
    }
  }
}
