import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../utils/app_navigator.dart';

class IntroVideoScreen extends StatefulWidget {
  const IntroVideoScreen({super.key});

  @override
  State<IntroVideoScreen> createState() => _IntroVideoScreenState();
}

class _IntroVideoScreenState extends State<IntroVideoScreen> {
  late final VideoPlayerController _controller;
  bool _isReady = false;
  bool _showSkip = false;
  bool _navigated = false;
  Timer? _skipDelayTimer;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/videos/intro.mp4')
      ..setLooping(false)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _isReady = true);
        _controller.play();
        _controller.addListener(_handlePlaybackState);
      }).catchError((_) {
        _navigateToWelcome();
      });

    _skipDelayTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _showSkip = true);
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_handlePlaybackState);
    _controller.dispose();
    _skipDelayTimer?.cancel();
    super.dispose();
  }

  void _handlePlaybackState() {
    if (!_controller.value.isPlaying &&
        _controller.value.position >= _controller.value.duration) {
      _navigateToWelcome();
    }
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: _isReady ? _buildVideoSurface() : _buildFallback(key: const ValueKey('intro-fallback')),
          ),
          DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black54],
              ),
            ),
          ),
          Positioned(
            bottom: media.padding.bottom + 32,
            left: 24,
            right: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Feel Like A Pro',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Кращі матчі, челенджі та відео в одному застосунку',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: media.padding.top + 16,
            right: 16,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: _showSkip ? 1 : 0,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black45,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                onPressed: _showSkip ? _navigateToWelcome : null,
                child: const Text('Пропустити'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoSurface() {
    final size = _controller.value.size;
    final aspectRatio = (size.width <= 0 || size.height <= 0)
        ? 16 / 9
        : size.width / size.height;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 420),
      opacity: _isReady ? 1 : 0,
      child: Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: VideoPlayer(_controller),
          ),
        ),
      ),
    );
  }

  Widget _buildFallback({Key? key}) {
    return Container(
      key: key,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1e7d32), Color(0xFF0f0f23)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                'assets/logo/flap_logo.jpg',
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

