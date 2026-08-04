import 'package:flutter/material.dart';
import '../game/hill_climb_game.dart';

/// Root app widget for the Hill Climb Racing game.
class HillClimbApp extends StatelessWidget {
  const HillClimbApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hill Climb Racing',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1A1A2E),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00D2FF),
          brightness: Brightness.dark,
        ),
      ),
      home: const GameScreen(),
    );
  }
}

/// Full-screen widget that hosts the Flame GameWidget.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final HillClimbGame _game;

  @override
  void initState() {
    super.initState();
    _game = HillClimbGame();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget(game: _game),
    );
  }
}
