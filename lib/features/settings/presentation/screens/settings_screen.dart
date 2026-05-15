import 'dart:convert';
import 'dart:io';

import 'package:cortex/core/constants/colors.dart';
import 'package:cortex/features/notes/domain/entities/note.dart';
import 'package:cortex/features/notes/presentation/providers/providers.dart';
import 'package:cortex/features/security/services/security_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final SecurityService _securityService = SecurityService();
  bool _isPrivateModeEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final isEnabled = await _securityService.isPrivateModeEnabled;
    setState(() {
      _isPrivateModeEnabled = isEnabled;
      _isLoading = false;
    });
  }

  Future<void> _togglePrivateMode(bool value) async {
    if (value) {
      // Must authenticate to enable
      final authSuccess = await _securityService.authenticate();
      if (!authSuccess) return;
    }
    
    await _securityService.setPrivateMode(value);
    setState(() {
      _isPrivateModeEnabled = value;
    });
  }

  Future<void> _exportData() async {
    try {
      final notesState = ref.read(noteNotifierProvider);
      final List<Map<String, dynamic>> dump = [];

      for (final note in notesState.notes) {
        final blocksData = note.blocks.map((b) => {
          'id': b.id,
          'data': () {
            if (b is TextBlock) return b.data;
            if (b is ImageBlock) return b.data;
            if (b is CheckboxBlock) return {'text': b.data, 'isChecked': b.isChecked};
            return '';
          }(),
          'orderIndex': b.orderIndex,
        }).toList();

        dump.add({
          'id': note.id,
          'title': note.title,
          'content': note.content,
          'blocks': blocksData,
          'createdAt': note.createdAt.toIso8601String(),
          'updatedAt': note.updatedAt?.toIso8601String(),
        });
      }

      final jsonString = jsonEncode(dump);
      
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/cortex_backup.json');
      await file.writeAsString(jsonString);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Data exported to ${file.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Settings",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 30),

            if (!_isLoading) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  "Private Mode",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text(
                  "Encrypt notes and require FaceID to unlock",
                  style: TextStyle(color: Colors.grey),
                ),
                value: _isPrivateModeEnabled,
                onChanged: _togglePrivateMode,
                activeColor: AppColors.primary,
              ),
              const Divider(height: 40),
            ],

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.download, color: AppColors.primary),
              ),
              title: const Text(
                "Export Data",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                "Export all notes to a JSON file",
                style: TextStyle(color: Colors.grey),
              ),
              onTap: _exportData,
            ),
          ],
        ),
      ),
    );
  }
}
