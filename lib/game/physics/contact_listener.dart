import 'package:flame_forge2d/flame_forge2d.dart';

/// Listens for contact events in the physics world.
/// Tracks ground contacts for the vehicle wheels (used for traction/flip detection)
/// and detects coin/fuel pickup collisions.
class ContactListener extends forge2d.ContactListener {
  /// Callback when the vehicle is touching ground (any wheel).
  void Function()? onGroundContact;
  /// Callback when the vehicle leaves the ground.
  void Function()? onGroundLeave;
  /// Callback when a coin body is touched by the vehicle.
  void Function(Body coinBody)? onCoinContact;
  /// Callback when a fuel can is touched.
  void Function(Body fuelBody)? onFuelContact;

  // Track ground contact by counting wheel-ground contacts
  int _groundContactCount = 0;
  bool get isOnGround => _groundContactCount > 0;

  @override
  void beginContact(Contact contact) {
    final a = contact.fixtureA.body;
    final b = contact.fixtureB.body;
    final dataA = contact.fixtureA.userData;
    final dataB = contact.fixtureB.userData;

    // Ground contact: a wheel touching terrain
    if ((dataA == 'wheel' && dataB == 'terrain') ||
        (dataB == 'wheel' && dataA == 'terrain')) {
      _groundContactCount++;
      if (_groundContactCount == 1) {
        onGroundContact?.call();
      }
      return;
    }

    // Coin pickup: vehicle chassis touches a coin
    if (dataA == 'vehicle' && dataB == 'coin') {
      onCoinContact?.call(b);
      return;
    }
    if (dataB == 'vehicle' && dataA == 'coin') {
      onCoinContact?.call(a);
      return;
    }

    // Fuel pickup
    if (dataA == 'vehicle' && dataB == 'fuel') {
      onFuelContact?.call(b);
      return;
    }
    if (dataB == 'vehicle' && dataA == 'fuel') {
      onFuelContact?.call(a);
      return;
    }
  }

  @override
  void endContact(Contact contact) {
    final dataA = contact.fixtureA.userData;
    final dataB = contact.fixtureB.userData;

    if ((dataA == 'wheel' && dataB == 'terrain') ||
        (dataB == 'wheel' && dataA == 'terrain')) {
      _groundContactCount--;
      if (_groundContactCount <= 0) {
        _groundContactCount = 0;
        onGroundLeave?.call();
      }
    }
  }

  @override
  void preSolve(Contact contact, Manifold oldManifold) {
    // No pre-solve modifications needed
  }

  @override
  void postSolve(Contact contact, ContactImpulse impulse) {
    // No post-solve modifications needed
  }
}
