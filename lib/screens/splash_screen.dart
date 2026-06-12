import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SplashScreen extends StatefulWidget {
  final Future<bool> autoLoginFuture;
  final Function(bool isAuthed) onFinished;

  const SplashScreen({
    super.key,
    required this.autoLoginFuture,
    required this.onFinished,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _titleFade;
  late Animation<Offset> _titleSlide;
  late Animation<double> _subTitleFade;
  late Animation<Offset> _subTitleSlide;

  bool _autoLoginResult = false;
  bool _autoLoginCompleted = false;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    // Staggered Animations
    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOutBack),
      ),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
    );

    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.75, curve: Curves.easeIn),
      ),
    );

    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.75, curve: Curves.easeOutCubic),
      ),
    );

    _subTitleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.55, 0.95, curve: Curves.easeIn),
      ),
    );

    _subTitleSlide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.55, 0.95, curve: Curves.easeOutCubic),
      ),
    );

    // Start auto-login fetch
    widget.autoLoginFuture.then((result) {
      if (mounted) {
        setState(() {
          _autoLoginResult = result;
          _autoLoginCompleted = true;
          _checkFinished();
        });
      }
    });

    // Start animation
    _controller.forward().then((_) {
      if (mounted) {
        _checkFinished();
      }
    });
  }

  void _checkFinished() {
    // Navigate only if BOTH animation finished AND auto-login finished
    if (_controller.isCompleted && _autoLoginCompleted) {
      widget.onFinished(_autoLoginResult);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF22873B), // Match native splash color
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated Logo
              FadeTransition(
                opacity: _logoFade,
                child: ScaleTransition(
                  scale: _logoScale,
                  child: SvgPicture.asset(
                    'assets/logo/Ellipse 2.svg',
                    width: 140,
                    height: 140,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              // Animated Title
              FadeTransition(
                opacity: _titleFade,
                child: SlideTransition(
                  position: _titleSlide,
                  child: const Text(
                    'EduSpace',
                    style: TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'serif',
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              
              // Animated Subtitle
              FadeTransition(
                opacity: _subTitleFade,
                child: SlideTransition(
                  position: _subTitleSlide,
                  child: Text(
                    'Маркази омузишӣ',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white.withOpacity(0.9),
                      fontFamily: 'serif',
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
