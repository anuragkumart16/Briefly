import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class FloatModel {
  final String id;
  String text;
  bool isActive;
  final DateTime createdAt;
  DateTime updatedAt;
  String syncStatus; // 'synced', 'created_offline', 'updated_offline', 'deleted_offline'

  FloatModel({
    required this.id,
    required this.text,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = 'synced',
  });

  factory FloatModel.fromJson(Map<String, dynamic> json) {
    return FloatModel(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      text: json['text'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
      syncStatus: json['syncStatus'] as String? ?? 'synced',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'syncStatus': syncStatus,
    };
  }
}

class FloatsSyncService {
  static const String _storageKey = 'offline_floats';

  /// Load floats from SharedPreferences. Filters out deleted_offline items for standard UI usage.
  static Future<List<FloatModel>> loadLocalFloats() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_storageKey);
    if (jsonStr == null) return [];

    try {
      final List<dynamic> decoded = jsonDecode(jsonStr);
      return decoded.map((item) => FloatModel.fromJson(item)).toList();
    } catch (e) {
      debugPrint('Error decoding local floats: $e');
      return [];
    }
  }

  /// Save floats list back to SharedPreferences.
  static Future<void> saveLocalFloats(List<FloatModel> floats) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(floats.map((f) => f.toJson()).toList());
    await prefs.setString(_storageKey, jsonStr);
  }

  /// Add a float locally.
  static Future<FloatModel> addFloatLocally(String text) async {
    final now = DateTime.now();
    final float = FloatModel(
      id: 'temp_${now.millisecondsSinceEpoch}',
      text: text,
      isActive: true,
      createdAt: now,
      updatedAt: now,
      syncStatus: 'created_offline',
    );

    final localList = await loadLocalFloats();
    localList.insert(0, float);
    await saveLocalFloats(localList);

    // Trigger async sync in background
    syncWithServer().catchError((e) => debugPrint('Background sync failed: $e'));

    return float;
  }

  /// Update a float locally.
  static Future<void> updateFloatLocally(String id, {String? text, bool? isActive}) async {
    final localList = await loadLocalFloats();
    final index = localList.indexWhere((f) => f.id == id);
    if (index == -1) return;

    final float = localList[index];
    if (text != null) float.text = text;
    if (isActive != null) float.isActive = isActive;
    float.updatedAt = DateTime.now();

    // If it was already created offline, keep it as 'created_offline' so we post it first.
    if (float.syncStatus != 'created_offline') {
      float.syncStatus = 'updated_offline';
    }

    await saveLocalFloats(localList);

    // Trigger async sync in background
    syncWithServer().catchError((e) => debugPrint('Background sync failed: $e'));
  }

  /// Delete a float locally.
  static Future<void> deleteFloatLocally(String id) async {
    final localList = await loadLocalFloats();
    final index = localList.indexWhere((f) => f.id == id);
    if (index == -1) return;

    final float = localList[index];

    if (float.syncStatus == 'created_offline') {
      // If created offline, it never reached the server, so just delete locally.
      localList.removeAt(index);
    } else {
      // Mark as deleted offline so sync job deletes it from server later.
      float.syncStatus = 'deleted_offline';
    }

    await saveLocalFloats(localList);

    // Trigger async sync in background
    syncWithServer().catchError((e) => debugPrint('Background sync failed: $e'));
  }

  /// Sync offline changes with server and pull latest floats list from server.
  static Future<void> syncWithServer() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? '';
    if (userId.isEmpty) return;

    final localList = await loadLocalFloats();
    bool hasChanges = false;

    // 1. Process Offline Deletions
    final deletions = localList.where((f) => f.syncStatus == 'deleted_offline').toList();
    for (final float in deletions) {
      try {
        final response = await http.delete(
          Uri.parse('${AppConfig.backendUrl}/api/v1/users/$userId/floats/${float.id}'),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200 || response.statusCode == 404) {
          localList.removeWhere((f) => f.id == float.id);
          hasChanges = true;
        }
      } catch (e) {
        debugPrint('Sync failed deleting float ${float.id}: $e');
      }
    }

    // 2. Process Offline Creations
    final creations = localList.where((f) => f.syncStatus == 'created_offline').toList();
    for (final float in creations) {
      try {
        final response = await http.post(
          Uri.parse('${AppConfig.backendUrl}/api/v1/users/$userId/floats'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'text': float.text}),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 201) {
          final body = jsonDecode(response.body);
          if (body['success'] == true && body['data'] != null) {
            // Update temporary ID with actual server database ID
            final index = localList.indexWhere((f) => f.id == float.id);
            if (index != -1) {
              localList[index] = FloatModel.fromJson(body['data'])..syncStatus = 'synced';
              hasChanges = true;
            }
          }
        }
      } catch (e) {
        debugPrint('Sync failed creating float: $e');
      }
    }

    // 3. Process Offline Updates
    final updates = localList.where((f) => f.syncStatus == 'updated_offline').toList();
    for (final float in updates) {
      try {
        final response = await http.put(
          Uri.parse('${AppConfig.backendUrl}/api/v1/users/$userId/floats/${float.id}'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'text': float.text, 'isActive': float.isActive}),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final index = localList.indexWhere((f) => f.id == float.id);
          if (index != -1) {
            localList[index].syncStatus = 'synced';
            hasChanges = true;
          }
        }
      } catch (e) {
        debugPrint('Sync failed updating float ${float.id}: $e');
      }
    }

    // Save processed local changes before pulling from server
    if (hasChanges) {
      await saveLocalFloats(localList);
    }

    // 4. Fetch latest from server and merge
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.backendUrl}/api/v1/users/$userId/floats'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] != null) {
          final List<dynamic> serverData = body['data'];
          final serverList = serverData.map((json) => FloatModel.fromJson(json)).toList();

          // Merge: serverList takes priority unless local float is unsynced (created/updated/deleted offline)
          final Map<String, FloatModel> merged = {};

          // Populate with latest server data
          for (final f in serverList) {
            merged[f.id] = f;
          }

          // Override/insert local items that are not yet synced
          final latestLocal = await loadLocalFloats();
          for (final f in latestLocal) {
            if (f.syncStatus != 'synced') {
              if (f.syncStatus == 'deleted_offline') {
                merged.remove(f.id);
              } else {
                merged[f.id] = f;
              }
            }
          }

          // Sort final merged list by createdAt desc (default sort)
          final sortedList = merged.values.toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          await saveLocalFloats(sortedList);
        }
      }
    } catch (e) {
      debugPrint('Sync: failed to fetch floats from server: $e');
    }
  }
}
