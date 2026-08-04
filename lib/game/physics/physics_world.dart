import 'package:flame_forge2d/flame_forge2d.dart';
import '../game_config.dart';
import 'vehicle_body.dart';
import 'terrain_body.dart';
import 'contact_listener.dart';

/// Manages the Forge2D physics world — gravity, vehicle, terrain, and coin/fuel bodies.
class PhysicsWorld {
  final Forge2DGame game;
  late final World world;
  late final VehicleBody vehicle;
  final List<TerrainBody> terrainBodies = [];
  final List<Body> pickupBodies = [];
  final GameContactListener contactListener;

  /// Track which pickups have been collected this frame.
  final Set<Body> collectedPickups = {};

  PhysicsWorld(this.game)
      : contactListener = GameContactListener() {
    world = World.withGravity(Vector2(0, GameConfig.gravity));
    world.setContactListener(contactListener);
  }

  /// Create the vehicle at the given world position.
  void createVehicle(Vector2 position) {
    vehicle = VehicleBody(
      world: world,
      position: position,
    );
    world.add(vehicle);
  }

  /// Add a terrain segment as a chain shape body.
  void addTerrainSegment(List<Vector2> points, double startX) {
    final terrain = TerrainBody(
      world: world,
      points: points,
      startX: startX,
    );
    world.add(terrain);
    terrainBodies.add(terrain);
  }

  /// Remove terrain bodies that are far behind the camera.
  void cullTerrain(double minX) {
    terrainBodies.removeWhere((t) {
      if (t.startX + t.segmentWidth < minX - GameConfig.chunkWidth) {
        t.removeFromParent();
        world.destroyBody(t.body);
        return true;
      }
      return false;
    });
  }

  /// Add a coin pickup at the given world position.
  void addCoin(Vector2 position) {
    final bodyDef = BodyDef(
      type: BodyType.static,
      position: position,
    );
    final body = world.createBody(bodyDef);
    final shape = CircleShape()..radius = GameConfig.pickupRadius;
    final fixtureDef = FixtureDef(shape)
      ..isSensor = true
      ..userData = PickupType.coin;
    body.createFixture(fixtureDef);
    pickupBodies.add(body);
  }

  /// Add a fuel pickup at the given world position.
  void addFuel(Vector2 position) {
    final bodyDef = BodyDef(
      type: BodyType.static,
      position: position,
    );
    final body = world.createBody(bodyDef);
    final shape = CircleShape()..radius = GameConfig.pickupRadius;
    final fixtureDef = FixtureDef(shape)
      ..isSensor = true
      ..userData = PickupType.fuel;
    body.createFixture(fixtureDef);
    pickupBodies.add(body);
  }

  /// Remove a collected pickup body.
  void removePickup(Body body) {
    pickupBodies.remove(body);
    world.destroyBody(body);
  }

  /// Collect all pickups marked by the contact listener this frame.
  List<(Body, PickupType)> drainCollectedPickups() {
    final result = contactListener.drainCollected(this);
    for (final (body, _) in result) {
      pickupBodies.remove(body);
      world.destroyBody(body);
    }
    return result;
  }

  /// Apply motor torque to the rear wheel.
  void applyMotorTorque(double torque) {
    vehicle.rearWheel?.applyAngularImpulse(torque);
  }

  /// Apply motor torque to the front wheel.
  void applyFrontMotorTorque(double torque) {
    vehicle.frontWheel?.applyAngularImpulse(torque);
  }

  /// Advance the physics simulation by one step.
  void step(double dt) {
    world.stepDt(dt, velocityIterations: 8, positionIterations: 3);
  }

  /// Clean up all bodies.
  void dispose() {
    for (final t in List<TerrainBody>.from(terrainBodies)) {
      t.removeFromParent();
      world.destroyBody(t.body);
    }
    terrainBodies.clear();
    for (final b in List<Body>.from(pickupBodies)) {
      world.destroyBody(b);
    }
    pickupBodies.clear();
    vehicle.removeFromParent();
  }
}
