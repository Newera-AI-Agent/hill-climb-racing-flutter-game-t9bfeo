import 'game_config.dart';

enum GamePhase { menu, playing, paused, gameOver }

class GameState {
  GamePhase phase = GamePhase.menu;
  double distance = 0.0;
  int coins = 0;
  double fuel = 100.0;
  double speed = 0.0;
  double tilt = 0.0;
  int bestScore = 0;
  bool isGrounded = true;
  bool isFlipped = false;

  final GameConfig config;

  GameState({required this.config});

  void reset() {
    phase = GamePhase.playing;
    distance = 0.0;
    coins = 0;
    fuel = config.startingFuel;
    speed = 0.0;
    tilt = 0.0;
    isGrounded = true;
    isFlipped = false;
  }

  void updateBestScore() {
    final score = coins * 100 + distance.toInt();
    if (score > bestScore) {
      bestScore = score;
    }
  }

  int get currentScore => coins * 100 + distance.toInt();

  bool get isPlaying => phase == GamePhase.playing;
  bool get isAlive => phase == GamePhase.playing && !isFlipped && fuel > 0;
}
