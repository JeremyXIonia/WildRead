import 'package:flutter/material.dart';

class ReaderMenu extends StatelessWidget {
  final double fontSize;
  final double brightness;
  final bool isDarkMode;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<double> onBrightnessChanged;
  final VoidCallback onToggleDarkMode;
  final VoidCallback onOpenToc;

  const ReaderMenu({
    super.key,
    required this.fontSize,
    required this.brightness,
    required this.isDarkMode,
    required this.onFontSizeChanged,
    required this.onBrightnessChanged,
    required this.onToggleDarkMode,
    required this.onOpenToc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.text_decrease,
                  color: Colors.white, size: 20),
              Expanded(
                child: Slider(
                  value: fontSize,
                  min: 12,
                  max: 28,
                  divisions: 8,
                  activeColor: Colors.white,
                  onChanged: onFontSizeChanged,
                ),
              ),
              const Icon(Icons.text_increase,
                  color: Colors.white, size: 24),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              const Icon(Icons.brightness_low,
                  color: Colors.white, size: 20),
              Expanded(
                child: Slider(
                  value: brightness,
                  min: 0.1,
                  max: 1.0,
                  activeColor: Colors.white,
                  onChanged: onBrightnessChanged,
                ),
              ),
              const Icon(Icons.brightness_high,
                  color: Colors.white, size: 24),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(
                onPressed: onToggleDarkMode,
                icon: Icon(
                    isDarkMode ? Icons.light_mode : Icons.dark_mode,
                    color: Colors.white),
                label: Text(isDarkMode ? '日间模式' : '夜间模式',
                    style: const TextStyle(color: Colors.white)),
              ),
              TextButton.icon(
                onPressed: onOpenToc,
                icon: const Icon(Icons.list, color: Colors.white),
                label: const Text('目录',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
