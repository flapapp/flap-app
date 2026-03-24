import 'dart:math';

import 'package:flutter/material.dart';
import '../utils/i18n.dart';

class IntroVideoScreen extends StatefulWidget {
  const IntroVideoScreen({super.key});

  @override
  State<IntroVideoScreen> createState() => _IntroVideoScreenState();
}

class _IntroVideoScreenState extends State<IntroVideoScreen> {
  bool _navigated = false;
  bool _imageReady = false;
  late final FocusNode _focusNode;
  late final String _startupImage;
  static const List<String> _startupImages = [
    'assets/startup/start_1.png',
    'assets/startup/start_2.png',
    'assets/startup/start_3.png',
    'assets/startup/start_4.png',
    'assets/startup/start_5.png',
    'assets/startup/start_6.png',
    'assets/startup/start_7.png',
    'assets/startup/start_8.png',
  ];

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _startupImage = _startupImages[Random().nextInt(_startupImages.length)];
    precacheImage(AssetImage(_startupImage), context).whenComplete(() {
      if (mounted) {
        setState(() => _imageReady = true);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _navigateToWelcome() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacementNamed('/welcome');
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: KeyboardListener(
        focusNode: _focusNode,
        onKeyEvent: (_) => _navigateToWelcome(),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _navigateToWelcome,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_imageReady)
                Image.asset(
                  _startupImage,
                  fit: BoxFit.cover,
                )
              else
                const ColoredBox(
                  color: Colors.black,
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.white70),
                  ),
                ),
              DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black26, Colors.black87],
                  ),
                ),
              ),
              Positioned(
                bottom: media.padding.bottom + 34,
                left: 24,
                right: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Feel Like A Pro',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      I18n.inline(
                        'Натисніть будь-яку клавішу або торкніться екрана',
                        'Press any key or tap anywhere to continue',
                      ),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: media.padding.top + 16,
                right: 16,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black45,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  onPressed: _navigateToWelcome,
                  child: Text(I18n.inline('Далі', 'Continue')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

