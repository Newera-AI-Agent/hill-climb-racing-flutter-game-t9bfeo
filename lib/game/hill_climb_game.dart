import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart' hide Overlay, Draggable, Image;

import 'game_config.dart';
import 'game_state.dart';
import 'physics/physics_world.dart';

/// Hill Climb Racing — main game class.
/// Manages physics, input, state, and rendering.
class HillClimbGame extends Forge2DGame with KeyboardEvents {
  late final PhysicsWorld physicsWorld;
  late final GameState gameState;
  final Set<LogicalKeyboardKey> _keysHeld = {};

  HillClimbGame() : super(gravity: GameConfig.gravity, zoom: 10.0);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    gameState = GameState(config: GameConfig());
    physicsWorld = PhysicsWorld();

    // Center camera slightly above vehicle start position.
    camera.viewport.anchor = Anchor.center;
    camera.followVector2(Vector2.zero(), relativeOffset: const Offset(0, 0));

    // Create terrain chunks ahead of start.
    _generateTerrainAround(0);

    // Spawn vehicle.
    _spawnVehicle();

    // Start game loop.
    gameState.phase = GamePhase.playing;
  }

  void _spawnVehicle() {
    physicsWorld.createVehicle(Vector2(3, GameConfig.minTerrainY - 3));
    final vehicleBody = physicsWorld.vehicle;
    if (vehicleBody != null) {
      world.add(vehicleBody);
    }
  }

  void _generateTerrainAround(double centerX) {
    final chunkWidth = GameConfig.chunkWidth;
    final chunkIndex = (centerX / chunkWidth).floor();

    for (int i = chunkIndex - GameConfig.chunksBehind;
        i <= chunkIndex + GameConfig.chunksAhead;
        i++) {
      if (!_hasTerrainForChunk(i)) {
        _createTerrainChunk(i);
      }
    }
  }

  final Set<int> _generatedChunks = {};

  bool _hasTerrainForChunk(int index) => _generatedChunks.contains(index);

  void _createTerrainChunk(int chunkIndex) {
    final chunkWidth = GameConfig.chunkWidth;
    final startX = chunkIndex * chunkWidth;
    final rng = math.Random(GameConfig.terrainSeed + chunkIndex * 31);

    // Generate terrain points for this chunk using Perlin-like noise.
    final points = <Vector2>[];
    final segmentLength = GameConfig.terrainSegmentLength;
    final numSegments = (chunkWidth / segmentLength).ceil();

    for (int i = 0; i <= numSegments; i++) {
      final x = startX + i * segmentLength;

      // Multi-octave noise for terrain height.
      double y = GameConfig.minTerrainY +
          (GameConfig.maxTerrainY - GameConfig.minTerrainY) / 2;

      // Smooth hills using sine combination.
      y += math.sin(x * 0.05 + rng.nextDouble() * 0.5) * 3.0;
      y += math.sin(x * 0.12 + rng.nextDouble() * 2.0) * 2.0;
      y += math.sin(x * 0.3 + rng.nextDouble() * 4.0) * 1.5;

      // Add some random variation.
      y += (rng.nextDouble() - 0.5) * 2.0;

      // Clamp to valid range.
      y = y.clamp(GameConfig.minTerrainY, GameConfig.maxTerrainY);

      points.add(Vector2(x, y));
    }

    physicsWorld.addTerrain(points, startX);
    _generatedChunks.add(chunkIndex);
  }

  void _cullTerrainBehind(double minX) {
    physicsWorld.cullTerrain(minX);
    _generatedChunks.removeWhere((index) {
      final chunkEnd = (index + 1) * GameConfig.chunkWidth;
      return chunkEnd < minX - 50;
    });
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (gameState.phase != GamePhase.playing) return;

    final vehicle = physicsWorld.vehicle;
    if (vehicle == null || vehicle.body == null) return;

    final vehicleBody = vehicle.body!;

    // Update speed.
    final vel = vehicleBody.linearVelocity;
    gameState.speed = vel.x;

    // Update distance.
    final dist = vehicleBody.position.x;
    if (dist > gameState.distance) {
      gameState.distance = dist;
    }

    // Fuel consumption.
    final isAccelerating =
        _keysHeld.contains(LogicalKeyboardKey.arrowRight) ||
        _keysHeld.contains(LogicalKeyboardKey.keyD);
    if (isAccelerating) {
      gameState.fuel -= GameConfig.fuelBurnRate * dt;
      if (gameState.fuel <= 0) {
        gameState.fuel = 0;
        gameState.phase = GamePhase.gameOver;
        return;
      }
    }

    // Flip check.
    final angle = vehicleBody.angle % (2 * math.pi);
    if (angle > math.pi * 0.7 && angle < math.pi * 1.3) {
      gameState.isFlipped = true;
      gameState.phase = GamePhase.gameOver;
      return;
    }

    // Apply vehicle controls.
    _applyControls(dt);

    // Stream terrain ahead.
    _generateTerrainAround(vehicleBody.position.x);
    _cullTerrainBehind(vehicleBody.position.x - 40);

    // Smooth camera follow.
    final target = Vector2(
      vehicleBody.position.x + GameConfig.cameraLookAhead,
      vehicleBody.position.y - GameConfig.cameraVerticalOffset,
    );
    camera.viewfinder.position = camera.viewfinder.position +
        (target - camera.viewfinder.position) *
            (GameConfig.cameraSmoothSpeed * dt);
  }

  void _applyControls(double dt) {
    final vehicle = physicsWorld.vehicle;
    if (vehicle == null) return;

    final isRight = _keysHeld.contains(LogicalKeyboardKey.arrowRight) ||
        _keysHeld.contains(LogicalKeyboardKey.keyD);
    final isLeft = _keysHeld.contains(LogicalKeyboardKey.arrowLeft) ||
        _keysHeld.contains(LogicalKeyboardKey.keyA);

    if (isRight) {
      vehicle.applyMotorSpeed(-GameConfig.acceleration);
    } else if (isLeft) {
      vehicle.applyMotorSpeed(GameConfig.brakeForce);
    } else {
      vehicle.applyMotorSpeed(0);
    }

    final isUp = _keysHeld.contains(LogicalKeyboardKey.arrowUp) ||
        _keysHeld.contains(LogicalKeyboardKey.keyW);
    final isDown = _keysHeld.contains(LogicalKeyboardKey.arrowDown) ||
        _keysHeld.contains(LogicalKeyboardKey.keyS);

    if (isUp) {
      vehicle.applyTilt(-GameConfig.airTiltTorque);
    } else if (isDown) {
      vehicle.applyTilt(GameConfig.airTiltTorque);
    }
  }

  @override
  void onKeyEvent(RawKeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    super.onKeyEvent(event, keysPressed);
    _keysHeld.clear();
    _keysHeld.addAll(keysPressed);

    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape ||
          event.logicalKey == LogicalKeyboardKey.keyP) {
        if (gameState.phase == GamePhase.playing) {
          gameState.phase = GamePhase.paused;
        } else if (gameState.phase == GamePhase.paused) {
          gameState.phase = GamePhase.playing;
        }
      }

      if (event.logicalKey == LogicalKeyboardKey.keyR &&
          gameState.phase == GamePhase.gameOver) {
        _restart();
      }
    }
  }

  void _restart() {
    // Destroy old vehicle.
    if (physicsWorld.vehicle != null) {
      physicsWorld.vehicle!.removeFromParent();
    }

    // Clear terrain.
    physicsWorld.dispose();
    _generatedChunks.clear();

    // Reset state.
    gameState.reset();

    // Re-create everything.
    _generateTerrainAround(0);
    _spawnVehicle();
  }

  // Touch controls for mobile/web.
  void onTapRight() {
    if (gameState.phase != GamePhase.playing) return;
    physicsWorld.vehicle?.applyMotorSpeed(-GameConfig.acceleration);
  }

  void onTapLeft() {
    if (gameState.phase != GamePhase.playing) return;
    physicsWorld.vehicle?.applyMotorSpeed(GameConfig.brakeForce);
  }

  void onTapRelease() {
    physicsWorld.vehicle?.applyMotorSpeed(0);
  }
}