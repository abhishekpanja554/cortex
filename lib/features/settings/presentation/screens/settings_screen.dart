import 'dart:convert';
import 'dart:io';

import 'package:cortex/core/constants/colors.dart';
import 'package:cortex/features/notes/presentation/providers/providers.dart';
import 'package:cortex/features/security/presentation/widgets/pin_setup_dialog.dart';
import 'package:cortex/features/security/services/security_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cortex/core/providers/core_providers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cortex/features/auth/presentation/auth_notifier.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  SecurityService get _securityService => ref.read(securityServiceProvider);
  bool _isPrivateModeEnabled = false;
  bool _isLoading = true;
  bool _hasAppPin = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final isEnabled = await _securityService.isPrivateModeEnabled;
    final hasPin = await _securityService.hasAppPin;
    setState(() {
      _isPrivateModeEnabled = isEnabled;
      _hasAppPin = hasPin;
      _isLoading = false;
    });
  }

  Future<void> _togglePrivateMode(bool value) async {
    if (value) {
      final isDeviceSecurityAvailable =
          await _securityService.isDeviceSecurityAvailable;

      if (isDeviceSecurityAvailable) {
        final authSuccess = await _securityService.authenticate();
        if (!authSuccess) return;
      }

      if (mounted && !(_hasAppPin)) {
        final pin = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (context) => const PinSetupDialog(),
        );

        if (pin == null) return;
        await _securityService.setAppPin(pin);
        setState(() => _hasAppPin = true);
      }
    }

    await _securityService.setPrivateMode(value);
    setState(() {
      _isPrivateModeEnabled = value;
    });
  }

  Future<void> _changePin() async {
    final pin = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PinSetupDialog(),
    );

    if (pin != null) {
      await _securityService.setAppPin(pin);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("App PIN updated")));
      }
    }
  }

  Future<void> _exportData() async {
    try {
      final notesState = ref.read(noteNotifierProvider);
      final List<Map<String, dynamic>> dump = [];

      for (final preview in notesState.notes) {
        final note = preview.note;
        dump.add({
          'id': note.id,
          'title': note.title,
          'body': note.body,
          'createdAt': note.createdAt.toIso8601String(),
          'updatedAt': note.updatedAt.toIso8601String(),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  Future<void> _logout() async {
    final noteRepo = ref.read(noteRepositoryProvider);
    final count = await noteRepo.unsyncedCount();

    if (count > 0 && mounted) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unsynced Changes'),
          content: Text('$count notes haven\'t synced and will be deleted.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Log out and delete'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }
    ref.read(authProvider.notifier).logout();
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  "Encrypt notes and require authentication to unlock",
                  style: TextStyle(color: Colors.grey),
                ),
                value: _isPrivateModeEnabled,
                onChanged: _togglePrivateMode,
                activeTrackColor: AppColors.primary,
              ),
              if (_isPrivateModeEnabled)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    "Change App PIN",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: _changePin,
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
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                "Export all notes to a JSON file",
                style: TextStyle(color: Colors.grey),
              ),
              onTap: _exportData,
            ),
            const Divider(height: 40),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.logout, color: Colors.red),
              ),
              title: const Text(
                "Log out",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.red),
              ),
              onTap: _logout,
            ),
          ],
        ),
      ),
    );
  }
}
