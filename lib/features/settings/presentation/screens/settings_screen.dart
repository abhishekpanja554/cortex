import 'dart:convert';
import 'dart:io';

import 'package:cortex/core/constants/colors.dart';
import 'package:cortex/core/constants/dimens.dart';
import 'package:cortex/core/constants/string_constants.dart';
import 'package:cortex/core/constants/text_styles.dart';
import 'package:cortex/core/providers/core_providers.dart';
import 'package:cortex/core/widgets/page_header.dart';
import 'package:cortex/core/widgets/settings_group.dart';
import 'package:cortex/features/auth/presentation/auth_notifier.dart';
import 'package:cortex/features/auth/presentation/current_user_provider.dart';
import 'package:cortex/features/notes/presentation/providers/providers.dart';
import 'package:cortex/features/security/presentation/widgets/pin_setup_dialog.dart';
import 'package:cortex/features/security/services/security_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

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
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final isEnabled = await _securityService.isPrivateModeEnabled;
    final hasPin = await _securityService.hasAppPin;
    if (!mounted) return;
    setState(() {
      _isPrivateModeEnabled = isEnabled;
      _hasAppPin = hasPin;
      _isLoading = false;
    });
  }

  Future<String?> _showPinSetup() {
    return Navigator.of(context).push<String>(
      CupertinoPageRoute(
        fullscreenDialog: true,
        builder: (_) => const PinSetupDialog(),
      ),
    );
  }

  Future<void> _togglePrivateMode(bool value) async {
    if (value) {
      if (await _securityService.isDeviceSecurityAvailable) {
        final authSuccess = await _securityService.authenticate();
        if (!authSuccess) return;
      }
      if (!_hasAppPin) {
        if (!mounted) return;
        final pin = await _showPinSetup();
        if (pin == null) return;
        await _securityService.setAppPin(pin);
        _hasAppPin = true;
      }
    }

    await _securityService.setPrivateMode(value);
    if (!mounted) return;
    setState(() => _isPrivateModeEnabled = value);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value ? 'Private Mode on' : 'Private Mode off')),
    );
  }

  Future<void> _changePin() async {
    final pin = await _showPinSetup();
    if (pin == null) return;
    await _securityService.setAppPin(pin);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('App PIN updated')),
      );
    }
  }

  Future<void> _exportData() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final notes = ref.read(noteNotifierProvider).notes;
      final dump = [
        for (final preview in notes)
          {
            'id': preview.note.id,
            'title': preview.note.title,
            'body': preview.note.body,
            'createdAt': preview.note.createdAt.toIso8601String(),
            'updatedAt': preview.note.updatedAt.toIso8601String(),
          },
      ];

      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/cortex_backup.json');
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(dump));

      if (mounted) {
        final n = dump.length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Exported $n ${n == 1 ? 'note' : 'notes'} to cortex_backup.json'
              '${Platform.isIOS ? ' (Files › On My iPhone › Cortex)' : ''}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _logout() async {
    final count = await ref.read(noteRepositoryProvider).unsyncedCount();
    if (!mounted) return;

    final hasUnsynced = count > 0;
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(hasUnsynced ? 'Unsynced Changes' : 'Log Out of Cortex?'),
        content: Text(
          hasUnsynced
              ? '$count ${count == 1 ? 'note hasn’t' : 'notes haven’t'} synced yet and will be removed from this device.'
              : 'Your notes sync back when you log in again. Images are stored only on this device and will be removed.',
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: Text(hasUnsynced ? 'Log Out Anyway' : 'Log Out'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    ref.read(authProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(currentUserEmailProvider).value;
    final noteCount = ref.watch(noteNotifierProvider).notes.length;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return CustomScrollView(
      slivers: [
        const AppLargeTitleBar(title: AppStrings.settings),
        SliverList.list(
          children: [
            SettingsGroup(
              children: [
                _AccountTile(email: email, noteCount: noteCount),
              ],
            ),
            SettingsGroup(
              title: 'Security',
              footer: 'When on, Cortex locks whenever it goes to the background.',
              children: [
                SettingsTile(
                  icon: CupertinoIcons.lock_fill,
                  iconColor: AppColors.primary,
                  title: 'Private Mode',
                  subtitle: 'Face ID or app PIN to open',
                  trailing: _isLoading
                      ? const CupertinoActivityIndicator()
                      : CupertinoSwitch(
                          value: _isPrivateModeEnabled,
                          onChanged: _togglePrivateMode,
                        ),
                  onTap: _isLoading
                      ? null
                      : () => _togglePrivateMode(!_isPrivateModeEnabled),
                ),
                if (_isPrivateModeEnabled)
                  SettingsTile(
                    icon: CupertinoIcons.number,
                    iconColor: AppColors.indigo,
                    title: 'Change App PIN',
                    onTap: _changePin,
                  ),
              ],
            ),
            SettingsGroup(
              title: 'Data',
              children: [
                SettingsTile(
                  icon: CupertinoIcons.arrow_down_doc_fill,
                  iconColor: AppColors.green,
                  title: 'Export Notes',
                  subtitle: 'Save all notes as a JSON file',
                  trailing: _isExporting ? const CupertinoActivityIndicator() : null,
                  onTap: _exportData,
                ),
              ],
            ),
            SettingsGroup(
              children: [
                SettingsTile(
                  icon: CupertinoIcons.square_arrow_right,
                  title: 'Log Out',
                  destructive: true,
                  onTap: _logout,
                ),
              ],
            ),
            SizedBox(height: bottomInset + AppSpacing.xxl),
          ],
        ),
      ],
    );
  }
}

class _AccountTile extends StatelessWidget {
  final String? email;
  final int noteCount;

  const _AccountTile({required this.email, required this.noteCount});

  @override
  Widget build(BuildContext context) {
    final initial = (email?.isNotEmpty ?? false) ? email![0].toUpperCase() : null;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFA3A3AD), Color(0xFF85858E)],
              ),
            ),
            child: initial != null
                ? Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  )
                : const Icon(CupertinoIcons.person_fill, color: Colors.white, size: 30),
          ),
          const SizedBox(width: AppSpacing.md + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  email ?? 'Signed In',
                  style: TextStyles.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$noteCount ${noteCount == 1 ? 'note' : 'notes'} on this device',
                  style: TextStyles.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
