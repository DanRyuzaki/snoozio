import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:snoozio/features/main/logic/music/music_player_controller.dart';

class MusicPlayerDialog extends StatefulWidget {
  const MusicPlayerDialog({super.key});

  @override
  State<MusicPlayerDialog> createState() => _MusicPlayerDialogState();
}

class _MusicPlayerDialogState extends State<MusicPlayerDialog> {
  int _fadeOutDuration = 10;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 700),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF2E1A47).withValues(alpha: 0.98),
              const Color(0xFF1A0D2E).withValues(alpha: 0.98),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFF9D4EDD).withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(
              child: Consumer<MusicPlayerController>(
                builder: (context, controller, child) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildNowPlaying(controller),
                        const SizedBox(height: 24),
                        _buildVolumeControl(controller),
                        const SizedBox(height: 24),
                        _buildFadeOutControl(controller),
                        const SizedBox(height: 32),
                        _buildTrackList(controller),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF9D4EDD).withValues(alpha: 0.3),
            const Color(0xFF6C5CE7).withValues(alpha: 0.2),
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(22),
          topRight: Radius.circular(22),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF9D4EDD).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const HugeIcon(
              icon: HugeIcons.strokeRoundedMusicNote03,
              color: Color(0xFFE0AAFF),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sleep Music',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Relaxing sounds for better sleep',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedCancel01,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNowPlaying(MusicPlayerController controller) {
    final currentTrack = controller.getCurrentTrack();

    if (currentTrack == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            const HugeIcon(
              icon: HugeIcons.strokeRoundedMusicNote01,
              size: 48,
              color: Colors.white38,
            ),
            const SizedBox(height: 12),
            Text(
              'No music playing',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Select a track below to start',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF7209B7).withValues(alpha: 0.3),
            const Color(0xFF5A189A).withValues(alpha: 0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE0AAFF).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF9D4EDD).withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              currentTrack.icon,
              size: 48,
              color: const Color(0xFFE0AAFF),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            currentTrack.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),

          Text(
            currentTrack.description,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () {
                  if (controller.isPlaying) {
                    controller.pause();
                  } else {
                    controller.resume();
                  }
                },
                icon: HugeIcon(
                  icon: controller.isPlaying
                      ? HugeIcons.strokeRoundedPause
                      : HugeIcons.strokeRoundedPlay,
                  size: 32,
                  color: Colors.white,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF6C5CE7),
                  padding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                onPressed: () => controller.stop(),
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedStop,
                  size: 28,
                  color: Colors.white,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFE74C3C),
                  padding: const EdgeInsets.all(14),
                ),
              ),
            ],
          ),

          if (controller.isFadingOut) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF9800).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFFF9800).withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const HugeIcon(
                    icon: HugeIcons.strokeRoundedMoon02,
                    size: 16,
                    color: Color(0xFFFFB74D),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Fading out...',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVolumeControl(MusicPlayerController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const HugeIcon(
              icon: HugeIcons.strokeRoundedVolumeHigh,
              size: 20,
              color: Color(0xFFE0AAFF),
            ),
            const SizedBox(width: 8),
            const Text(
              'Volume',
              style: TextStyle(
                color: Color(0xFFE0AAFF),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              '${(controller.volume * 100).round()}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: const Color(0xFF9D4EDD),
            inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
            thumbColor: const Color(0xFFE0AAFF),
            overlayColor: const Color(0xFF9D4EDD).withValues(alpha: 0.3),
            trackHeight: 6,
          ),
          child: Slider(
            value: controller.volume,
            onChanged: (value) => controller.setVolume(value),
            min: 0.0,
            max: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildFadeOutControl(MusicPlayerController controller) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const HugeIcon(
                icon: HugeIcons.strokeRoundedMoonSlowWind,
                size: 20,
                color: Color(0xFFE0AAFF),
              ),
              const SizedBox(width: 8),
              const Text(
                'Sleep Timer',
                style: TextStyle(
                  color: Color(0xFFE0AAFF),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Fade out after $_fadeOutDuration minutes',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [5, 10, 15, 30, 45, 60].map((minutes) {
              final isSelected = _fadeOutDuration == minutes;
              return ChoiceChip(
                label: Text(
                  '$minutes min',
                  style: TextStyle(
                    color: isSelected
                        ? const Color.fromARGB(173, 255, 255, 255)
                        : const Color(0xFF6C5CE7),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() => _fadeOutDuration = minutes);
                },
                selectedColor: const Color(0xFF6C5CE7),
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                side: BorderSide(
                  color: isSelected
                      ? const Color(0xFF9D4EDD)
                      : Colors.white.withValues(alpha: 0.2),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: controller.isPlaying && !controller.isFadingOut
                  ? () => controller.fadeOut(
                      durationSeconds: _fadeOutDuration * 60,
                    )
                  : null,
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedMoon02,
                size: 20,
                color: Colors.white,
              ),
              label: Text(
                controller.isFadingOut ? 'Fading Out...' : 'Start Sleep Timer',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5CE7),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                disabledBackgroundColor: Colors.grey.withValues(alpha: 0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackList(MusicPlayerController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedPlayList,
              size: 20,
              color: Color(0xFFE0AAFF),
            ),
            SizedBox(width: 8),
            Text(
              'Available Tracks',
              style: TextStyle(
                color: Color(0xFFE0AAFF),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...controller.tracks.map((track) => _buildTrackItem(track, controller)),
      ],
    );
  }

  Widget _buildTrackItem(MusicTrack track, MusicPlayerController controller) {
    final isPlaying =
        controller.currentTrackId == track.id && controller.isPlaying;
    final isSelected = controller.currentTrackId == track.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: isSelected
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF6C5CE7).withValues(alpha: 0.3),
                  const Color(0xFF5A4CC5).withValues(alpha: 0.2),
                ],
              )
            : null,
        color: isSelected ? null : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF9D4EDD).withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.1),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF9D4EDD).withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            track.icon,
            color: isSelected ? const Color(0xFFE0AAFF) : Colors.white70,
            size: 24,
          ),
        ),
        title: Text(
          track.name,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.9),
            fontSize: 15,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        subtitle: Text(
          track.description,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 12,
          ),
        ),
        trailing: isPlaying
            ? const HugeIcon(
                icon: HugeIcons.strokeRoundedMusicNote04,
                size: 24,
                color: Color(0xFF9D4EDD),
              )
            : null,
        onTap: () => controller.playTrack(track.id),
      ),
    );
  }
}
