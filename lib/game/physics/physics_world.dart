import 'dart:math' as math;

import 'package:flame_forge2d/flame_forge2d.dart';
import '../game_config.dart';

/// Manages the Forge2D physics world — gravity, vehicle, terrain, and pickups.
class PhysicsWorld {
  final Forge2DWorld world;
  
  /// All terrain bodies currently in the world.
  final List<Body> terrainBodies = [];
  
  /// All coin pickup bodies currently in the world.
  final List<Body> coinBodies = [];
  
  /// All fuel pickup bodies currently in the world.
  final List<Body> fuelBodies = [];

  PhysicsWorld(this.world);

  /// Create a terrain chain body from a list of world-space points.
  Body createTerrain(List<Vector2> points) {
    final bodyDef = BodyDef(type: BodyType.static, position: Vector2.zero());
    final body = world.createBody(bodyDef);
    
    for (int i = 0; i < points.length - 1; i++) {
      final shape = EdgeShape()
        ..set(points[i], points[i + 1]);
      final fixtureDef = FixtureDef(shape)
        ..friction = 0.6
        ..restitution = 0.05;
      body.createFixture(fixtureDef);
    }
    
    terrainBodies.add(body);
    return body;
  }

  /// Remove terrain bodies whose rightmost X is behind the camera.
  void cullTerrain(double minX) {
    terrainBodies.removeWhere((body) {
      // Check if all fixtures are behind minX.
      bool allBehind = true;
      for (final fixture in body.fixtures) {
        if (fixture.shape is EdgeShape) {
          final edge = fixture.shape as EdgeShape;
          if (edge.vertex2.x >= minX) {
            allBehind = false;
            break;
          }
        }
      }
      if (allBehind) {
        world.destroyBody(body);
        return true;
      }
      return false;
    });
  }

  /// Create a coin pickup sensor at the given position.
  Body createCoin(Vector2 position) {
    final bodyDef = BodyDef(type: BodyType.static, position: position);
    final body = world.createBody(bodyDef);
    final shape = CircleShape()..radius = GameConfig.pickupRadius;
    final fixtureDef = FixtureDef(shape)
      ..isSensor = true
      ..userData = 'coin';
    body.createFixture(fixtureDef);
    coinBodies.add(body);
    return body;
  }

  /// Create a fuel pickup sensor at the given position.
  Body createFuel(Vector2 position) {
    final bodyDef = BodyDef(type: BodyType.static, position: position);
    final body = world.createBody(bodyDef);
    final shape = CircleShape()..radius = GameConfig.pickupRadius;
    final fixtureDef = FixtureDef(shape)
      ..isSensor = true
      ..userData = 'fuel';
    body.createFixture(fixtureDef);
    fuelBodies.add(body);
    return body;
  }

  /// Remove a specific coin body from the world.
  void removeCoin(Body body) {
    coinBodies.remove(body);
    world.destroyBody(body);
  }

  /// Remove a specific fuel body from the world.
  void removeFuel(Body body) {
    fuelBodies.remove(body);
    world.destroyBody(body);
  }

  /// Remove all pickup bodies.
  void clearAllPickups() {
    for (final body in [...coinBodies]) {
      world.destroyBody(body);
    }
    coinBodies.clear();
    for (final body in [...fuelBodies]) {
      world.destroyBody(body);
    }
    fuelBodies.clear();
  }

  /// Advance the physics simulation by one step.
  void step(double dt) {
    world.stepDt(dt);
  }

  /// Destroy all managed bodies.
  void dispose() {
    clearAllPickups();
    for (final body in [...terrainBodies]) {
      world.destroyBody(body);
    }
    terrainBodies.clear();
  }
}
