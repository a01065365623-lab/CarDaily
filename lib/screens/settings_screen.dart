import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../services/settings_service.dart';
import '../theme/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _introMusicEnabled = true;
  final _vehicleNicknameController = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _vehicleNicknameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final enabled = await SettingsService.isIntroMusicEnabled();
    final nickname = await SettingsService.getVehicleNickname();
    if (!mounted) return;
    setState(() {
      _introMusicEnabled = enabled;
      _vehicleNicknameController.text = nickname ?? '';
      _loading = false;
    });
  }

  Future<void> _toggleIntroMusic(bool value) async {
    setState(() => _introMusicEnabled = value);
    await SettingsService.setIntroMusicEnabled(value);
  }

  Future<void> _saveVehicleNickname() async {
    await SettingsService.setVehicleNickname(_vehicleNicknameController.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.settingsVehicleNicknameSaved)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.settingsAppBarTitle),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.settingsVehicleNicknameTitle,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.settingsVehicleNicknameSubtitle,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _vehicleNicknameController,
                              maxLength: 20,
                              decoration: InputDecoration(
                                hintText: l10n.settingsVehicleNicknameHint,
                                isDense: true,
                                counterText: '',
                                filled: true,
                                fillColor: AppColors.background,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: AppColors.divider),
                                ),
                              ),
                              onSubmitted: (_) => _saveVehicleNickname(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _saveVehicleNickname,
                            icon: const Icon(Icons.check_circle_rounded),
                            color: AppColors.amber,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: SwitchListTile(
                    value: _introMusicEnabled,
                    onChanged: _toggleIntroMusic,
                    activeColor: AppColors.amber,
                    title: Text(
                      l10n.settingsIntroMusicTitle,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      l10n.settingsIntroMusicSubtitle,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
