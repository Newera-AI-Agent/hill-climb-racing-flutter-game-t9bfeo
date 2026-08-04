import 'dart:async';
import 'dart:math' as math;
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart' hide Overlay;
import 'game_config.dart';
import 'game_state.dart';
import 'game_commands.dart';
import 'physics/physics_world.dart';
import 'physics/vehicle_body.dart';
import 'terrain/terrain_streamer.dart';
import 'entities/coin_component.dart';
import 'entities/fuel_component.dart';
import 'camera/follow_camera.dart';
import 'overlays/hud_overlay.dart';
import 'overlays/pause_overlay.dart';
import 'overlays/game_over_overlay.dart';

/// Main game class that ties physics, terrain, entities, camera and UI together.
class HillClimbGame extends Forge2DGame
    with KeyboardEvents, PanDetector, TapDetector {
  late final PhysicsWorld physicsWorld;
  late final TerrainStreamer terrainStreamer;
  late final VehicleBody vehicle;
  late final FollowCamera followCamera;
  late final GameState gameState;

  // Command stream for decoupling input from updates.
  final _commandController = StreamController<GameCommand>.broadcast();
  Stream<GameCommand> get commands => _commandController.stream;

  // Track which keys are held down.
  final _keysHeld = <LogicalKeyboardKey>{};

  HillClimbGame() : super(gravity: GameConfig.worldGravity, zoom: 10.0);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Set up the camera.
    followCamera = FollowCamera(
      viewport: camera.viewport,
      offset: Vector2.zero(),
    );
    camera.viewport.add(followCamera);

    // Create game state.
    gameState = GameState();
    gameState.addListener(_onGameStateChanged);

    // Create physics world and terrain.
    physicsWorld = PhysicsWorld();
    terrainStreamer = TerrainStreamer(world: world);

    // Create vehicle.
    vehicle = VehicleBody(
      world: world,
      startPosition: Vector2(0, 0),
    );
    world.add(vehicle);

    // Set up contact listener for pickups.
    world.contactManager.contactListener = ContactListener(
      onCoinCollected: _onCoinCollected,
      onFuelCollected: _onFuelCollected,
    );

    // Load overlays into the Forge2D world overlay system.
    overlays.addEntry('hud', HudOverlay(game: this));
    overlays.addEntry('pause', PauseOverlay(game: this));
    overlays.addEntry('gameOver', GameOverOverlay(game: this));
    overlays.active = 'hud';

    // Start the game loop.
    gameState.startGame();

    // Spawn initial terrain and pickups.
    terrainStreamer.generateInitialChunks(vehicle.body.position);
  }

  @override
  void update(double dt) {
    if (gameState.status != GameStatus.playing) {
      super.update(dt);
      return;
    }

    super.update(dt);

    // Update game state time.
    gameState.elapsedTime += dt;

    // Calculate distance score.
    final dist = vehicle.body.position.x - GameConfig.startX;
    if (dist > gameState.distance) {
      gameState.distance = dist;
    }

    // Fuel consumption.
    gameState.fuel -= GameConfig.fuelConsumptionRate * dt;
    if (gameState.fuel <= 0) {
      gameState.fuel = 0;
      _triggerGameOver();
      return;
    }

    // Flip check — if vehicle is upside down.
    if (_isVehicleFlipped()) {
      _triggerGameOver();
      return;
    }

    // Stream terrain ahead.
    terrainStreamer.streamAround(vehicle.body.position);

    // Spawn pickups ahead.
    _maybeSpawnPickups();

    // Update camera to follow vehicle.
    followCamera.followTarget = vehicle.body.position;
  }

  @override
  void onKeyEvent(RawKeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    super.onKeyEvent(event, keysPressed);

    if (event is RawKeyDownEvent) {
      _keysHeld.add(event.logicalKey);

      if (event.logicalKey == LogicalKeyboardKey.escape ||
          event.logicalKey == LogicalKeyboardKey.keyP) {
        _togglePause();
        return;
      }

      if (event.logicalKey == LogicalKeyboardKey.keyR) {
        _restart();
        return;
      }
    } else if (event is RawKeyUpEvent) {
      _keysHeld.remove(event.logicalKey);
    }

    // Send continuous input based on held keys.
    if (_keysHeld.contains(LogicalKeyboardKey.arrowRight) ||
        _keysHeld.contains(LogicalKeyboardKey.keyD)) {
      _commandController.add(GameCommand.accelerate);
    } else if (_keysHeld.contains(LogicalKeyboardKey.arrowLeft) ||
        _keysHeld.contains(LogicalKeyboardKey.keyA)) {
      _commandController.add(GameCommand.brake);
    }

    if (_keysHeld.contains(LogicalKeyboardKey.arrowUp) ||
        _keysHeld.contains(LogicalKeyboardKey.keyW)) {
      _commandController.add(GameCommand.tiltBackward);
    } else if (_keysHeld.contains(LogicalKeyboardKey.arrowDown) ||
        _keysHeld.contains(LogicalKeyboardKey.keyS)) {
      _commandController.add(GameCommand.tiltForward);
    }
  }

  // Touch controls — tap right half = accelerate, left half = brake.
  @override
  void onPanUpdate(DragUpdateInfo info) {
    if (gameState.status != GameStatus.playing) return;

    final screenCenter = size.x / 2;
    if (info.eventPosition.game.x > screenCenter) {
      _commandController.add(GameCommand.accelerate);
    } else {
      _commandController.add(GameCommand.brake);
    }
  }

  @override
  void onPanEnd(DragEndInfo info) {
    // Automatically tilts based on vehicle momentum — no tilt on pan end.
  }

  @override
  void onTapDown(TapDownInfo info) {
    if (gameState.status == GameStatus.paused) {
      _togglePause();
    } else if (gameState.status == GameStatus.gameOver) {
      _restart();
    }
  }

  void _onGameStateChanged() {
    // Update overlays based on state.
    switch (gameState.status) {
      case GameStatus.playing:
        overlays.active = 'hud';
        break;
      case GameStatus.paused:
        overlays.active = 'pause';
        break;
      case GameStatus.gameOver:
        overlays.active = 'gameOver';
        break;
    }
  }

  void _togglePause() {
    if (gameState.status == GameStatus.playing) {
      gameState.pause();
    } else if (gameState.status == GameStatus.paused) {
      gameState.resume();
    }
  }

  void _restart() {
    gameState.restart();
    vehicle.reset(Vector2(0, 0));
    terrainStreamer.clearAll();
    terrainStreamer.generateInitialChunks(Vector2(0, 0));
    _clearAllPickups();
  }

  void _triggerGameOver() {
    if (gameState.status == GameStatus.playing) {
      gameState.gameOver();
    }
  }

  bool _isVehicleFlipped() {
    final angle = vehicle.body.angle;
    // Normalize angle to [-pi, pi].
    final normAngle = angle % (2 * math.pi);
    return normAngle > math.pi / 2 && normAngle < 3 * math.pi / 2;
  }

  void _onCoinCollected() {
    gameState.coins += 1;
  }

  void _onFuelCollected() {
    gameState.fuel = (gameState.fuel + GameConfig.fuelPickupAmount)
        .clamp(0, GameConfig.maxFuel);
  }

  final Set<int> _spawnedChunkIndices = {};

  void _maybeSpawnPickups() {
    final currentChunk = terrainStreamer.chunkIndexAt(vehicle.body.position.x);
    if (!_spawnedChunkIndices.contains(currentChunk)) {
      _spawnedChunkIndices.add(currentChunk);
      _spawnPickupsForChunk(currentChunk);
    }
  }

  void _spawnPickupsForChunk(int chunkIndex) {
    final rng = math.Random(chunkIndex * 31 + GameConfig.terrainSeed);
    final chunkStartX = chunkIndex * GameConfig.chunkWidth.toDouble();

    // Coins.
    final coinCount = rng.nextInt(4);
    for (int i = 0; i < coinCount; i++) {
      final x = chunkStartX + rng.nextDouble() * GameConfig.chunkWidth;
      final y = terrainStreamer.getHeightAt(x) - 2.0 - rng.nextDouble() * 3.0;
      final coin = CoinComponent(
        position: Vector2(x, y),
      );
      world.add(coin);
    }

    // Fuel can.
    if (rng.nextDouble() < 0.4) {
      final x = chunkStartX + rng.nextDouble() * GameConfig.chunkWidth;
      final y = terrainStreamer.getHeightAt(x) - 2.0;
      final fuel = FuelComponent(
        position: Vector2(x, y),
      );
      world.add(fuel);
    }
  }

  void _clearAllPickups() {
    _spawnedChunkIndices.clear();
    // Remove all coin and fuel bodies from world.
    for (final body in world.bodies.toList()) {
      if (body is CoinComponent || body is FuelComponent) {
        world.destroyBody(body.body);
      }
    }
  }

  @override
  Color backgroundColor() => GameConfig.skyColor;

  void sendCommand(GameCommand command) {
    _commandController.add(command);
  }
}
