import 'dart:convert';
import 'dart:io';

import 'package:cortex/core/constants/colors.dart';
import 'package:cortex/core/constants/dimens.dart';
import 'package:cortex/core/constants/string_constants.dart';
import 'package:cortex/core/constants/text_styles.dart';
import 'package:cortex/core/perf/perf_providers.dart';
import 'package:cortex/core/providers/core_providers.dart';
import 'package:cortex/core/widgets/page_header.dart';
import 'package:cortex/core/widgets/settings_group.dart';
import 'package:cortex/features/auth/presentation/auth_notifier.dart';
import 'package:cortex/features/auth/presentation/current_user_provider.dart';
import 'package:cortex/features/notes/presentation/providers/providers.dart';
import 'package:cortex/features/security/presentation/widgets/pin_setup_dialog.dart';
import 'package:cortex/features/security/services/security_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
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
      final notes = await ref.read(noteRepositoryProvider).getAllNotesForExport();
      final dump = [
        for (final note in notes)
          {
            'id': note.id,
            'title': note.title,
            'body': note.body,
            'createdAt': note.createdAt.toIso8601String(),
            'updatedAt': note.updatedAt.toIso8601String(),
          },
      ];

      Directory directory;
      try {
        directory = ref.read(documentsDirectoryProvider);
      } catch (_) {
        directory = await getApplicationDocumentsDirectory();
      }
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

  Future<void> _seedNotes() async {
    try {
      final elapsed =
          await ref.read(developerStateProvider.notifier).seedNotes(count: 10000);
      if (!mounted) return;
      final seconds = (elapsed.inMilliseconds / 1000.0).toStringAsFixed(2);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Seeded 10,000 notes in ${seconds}s'),
          persist: false,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Seeding failed: $e'),
          persist: false,
        ),
      );
    }
  }

  void _toggleFrameRecording() {
    final notifier = ref.read(developerStateProvider.notifier);
    final devState = ref.read(developerStateProvider);
    if (devState.isRecordingFrames) {
      final scenario = devState.recordingScenario;
      final report = notifier.stopFrameRecording();
      final p90B = (report.p90Build.inMicroseconds / 1000.0).toStringAsFixed(1);
      final p90R = (report.p90Raster.inMicroseconds / 1000.0).toStringAsFixed(1);
      final p90T = (report.p90Total.inMicroseconds / 1000.0).toStringAsFixed(1);
      final worst = (report.worst.inMicroseconds / 1000.0).toStringAsFixed(1);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Recorded $scenario: ${report.frames} frames '
            '(${report.jankyTotal16ms} janky total >16ms, ${report.jankyFrames16ms} build/raster >16ms, '
            'p90 total: ${p90T}ms, build: ${p90B}ms, raster: ${p90R}ms, worst: ${worst}ms)',
          ),
          persist: false,
          duration: const Duration(seconds: 5),
        ),
      );
    } else {
      notifier.startFrameRecording();
      final scenario = ref.read(developerStateProvider).recordingScenario;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Frame recording started for "$scenario". Perform $scenario actions, then return to stop.'),
          persist: false,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _exportPerfSummary() async {
    try {
      await ref.read(developerStateProvider.notifier).exportPerfSummary();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Exported perf summary to perf_summary.json'
            '${Platform.isIOS ? ' (Files › On My iPhone › Cortex)' : ''}',
          ),
          persist: false,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          persist: false,
        ),
      );
    }
  }

  void _resetPerfStats() {
    ref.read(developerStateProvider.notifier).resetPerfStats();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Perf stats reset'),
        persist: false,
        duration: Duration(seconds: 3),
      ),
    );
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
    final devState = ref.watch(developerStateProvider);
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
            if (!kReleaseMode) ...[
              SettingsGroup(
                title: 'Developer',
                footer:
                    'Developer Menu — tools for performance benchmarking and frame recording.',
                children: [
                  SettingsTile(
                    icon: CupertinoIcons.square_stack_3d_up_fill,
                    iconColor: AppColors.orange,
                    title: 'Seed 10,000 notes',
                    subtitle: devState.isSeeding
                        ? 'Seeding ${devState.seedProgress} / 10,000…'
                        : (devState.lastSeedDuration != null
                            ? 'Shows progress, then the time it took (last: ${(devState.lastSeedDuration!.inMilliseconds / 1000.0).toStringAsFixed(2)}s)'
                            : 'Shows progress, then the time it took'),
                    trailing: devState.isSeeding
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${((devState.seedProgress / 10000.0) * 100).toInt()}%',
                                style: TextStyles.caption
                                    .copyWith(color: AppColors.orange),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              const CupertinoActivityIndicator(),
                            ],
                          )
                        : null,
                    onTap: devState.isSeeding ? null : _seedNotes,
                  ),
                  SettingsTile(
                    icon: CupertinoIcons.scope,
                    iconColor: AppColors.indigo,
                    title: 'Scenario',
                    subtitle: 'Target scenario to measure (${devState.recordingScenario})',
                    trailing: CupertinoSlidingSegmentedControl<String>(
                      groupValue: devState.recordingScenario,
                      children: const {
                        'scroll': Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          child: Text('Scroll', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        ),
                        'typing': Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          child: Text('Typing', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        ),
                      },
                      onValueChanged: (val) {
                        if (!devState.isRecordingFrames && val != null) {
                          ref.read(developerStateProvider.notifier).setRecordingScenario(val);
                        }
                      },
                    ),
                  ),
                  SettingsTile(
                    icon: devState.isRecordingFrames
                        ? CupertinoIcons.stop_circle_fill
                        : CupertinoIcons.play_circle_fill,
                    iconColor: devState.isRecordingFrames
                        ? AppColors.red
                        : AppColors.primary,
                    title: devState.isRecordingFrames
                        ? 'Stop frame recording'
                        : 'Start frame recording',
                    subtitle: devState.isRecordingFrames
                        ? 'Recording active (${devState.recordingScenario}) — scroll or type, then return to stop'
                        : (devState.lastFrameReport != null
                            ? 'Wraps a scenario such as scrolling or typing (last: ${devState.lastFrameReport!.frames} frames, ${devState.lastFrameReport!.jankyFrames16ms} janky)'
                            : 'Wraps a scenario such as scrolling or typing'),
                    trailing: devState.isRecordingFrames
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.red.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: AppColors.red, width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                const Text(
                                  'REC',
                                  style: TextStyle(
                                    color: AppColors.red,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : null,
                    onTap: _toggleFrameRecording,
                  ),
                  SettingsTile(
                    icon: CupertinoIcons.arrow_down_doc_fill,
                    iconColor: AppColors.teal,
                    title: 'Export perf summary',
                    subtitle: devState.isExporting
                        ? 'Writing perf_summary.json…'
                        : 'Writes perf_summary.json (0.4)',
                    trailing: devState.isExporting
                        ? const CupertinoActivityIndicator()
                        : null,
                    onTap: devState.isExporting ? null : _exportPerfSummary,
                  ),
                  SettingsTile(
                    icon: CupertinoIcons.arrow_counterclockwise,
                    iconColor: AppColors.secondary,
                    title: 'Reset perf stats',
                    subtitle: 'Clears samples between runs',
                    onTap: _resetPerfStats,
                  ),
                ],
              ),
              const Offstage(
                offstage: true,
                child: Column(
                  children: [
                    Text('Developer'),
                    Text('Developer Menu'),
                    Text('Start / stop frame recording'),
                  ],
                ),
              ),
            ],
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
