import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

class AudioSettingsScreen extends StatefulWidget {
  final User user;

  const AudioSettingsScreen({super.key, required this.user});

  @override
  State<AudioSettingsScreen> createState() => _AudioSettingsScreenState();
}

class _AudioSettingsScreenState extends State<AudioSettingsScreen> {
  final AuthService _authService = AuthService();
  late int _countdownVolume;
  late int _startVolume;
  late int _halfwayVolume;
  late int _finishVolume;
  bool _isSaving = false;

  final List<int> _volumeLevels = [0, 25, 50, 75, 100];

  @override
  void initState() {
    super.initState();
    _countdownVolume = widget.user.countdownVolume;
    _startVolume = widget.user.startVolume;
    _halfwayVolume = widget.user.halfwayVolume;
    _finishVolume = widget.user.finishVolume;
  }

  String _volumeLabel(int volume) {
    switch (volume) {
      case 0:
        return 'Off';
      case 25:
        return 'Quiet';
      case 50:
        return 'Medium';
      case 75:
        return 'Loud';
      case 100:
        return 'Max';
      default:
        return '$volume%';
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      await _authService.updateProfile(
        countdownVolume: _countdownVolume,
        startVolume: _startVolume,
        halfwayVolume: _halfwayVolume,
        finishVolume: _finishVolume,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Audio settings saved')),
        );
        Navigator.pop(context, true); // Return true to indicate settings changed
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save settings: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildVolumeControl(
    String title,
    String description,
    int currentVolume,
    ValueChanged<int> onChanged,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: _volumeLevels.map((level) {
                final isSelected = currentVolume == level;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: InkWell(
                      onTap: () => onChanged(level),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF9B1C1C)
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _volumeLabel(level),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Settings'),
        backgroundColor: const Color(0xFF9B1C1C),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Practice Audio Cues',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Customize the volume for each audio cue during practice sessions.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            _buildVolumeControl(
              'Countdown Beeps',
              'Three beeps before exercise starts',
              _countdownVolume,
              (value) => setState(() => _countdownVolume = value),
            ),
            _buildVolumeControl(
              'Start Sound',
              'Sound when exercise begins',
              _startVolume,
              (value) => setState(() => _startVolume = value),
            ),
            _buildVolumeControl(
              'Halfway Bell',
              'Bell at 50% completion',
              _halfwayVolume,
              (value) => setState(() => _halfwayVolume = value),
            ),
            _buildVolumeControl(
              'Finish Gong',
              'Gong when exercise completes',
              _finishVolume,
              (value) => setState(() => _finishVolume = value),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9B1C1C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Save Settings',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
