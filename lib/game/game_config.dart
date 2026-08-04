import 'dart:ui' show Color;

/// Hill Climb Racing — central configuration constants.
/// All tuning values live here so they can be adjusted in one place.
class GameConfig {
  GameConfig._();

  static const String version = '0.1.0';

  // ── World ──
  static const double gravity = 15.0;
  static const double pixelsPerMeter = 50.0;
  static const double worldWidth = 400.0;
  static const double worldHeight = 50.0;

  // ── Vehicle ──
  static const double chassisWidth = 3.5;
  static const double chassisHeight = 1.2;
  static const double wheelRadius = 0.55;
  static const double maxSpeed = 18.0;
  static const double acceleration = 12.0;
  static const double brakeForce = 8.0;
  static const double airTiltTorque = 3.5;
  static const double groundTiltTorque = 6.0;
  static const double suspensionStiffness = 80.0;
  static const double suspensionDamping = 5.0;
  static const double maxAngleDeg = 70.0;

  // ── Terrain ──
  static const double terrainSegmentLength = 2.0;
  static const double minTerrainY = 20.0;
  static const double maxTerrainY = 30.0;
  static const double hillAmplitude = 6.0;
  static const double hillFrequency = 0.08;
  static const int terrainSeed = 42;
  static const double chunkWidth = 80.0;
  static const int chunksAhead = 3;
  static const int chunksBehind = 1;

  // ── Pickups ──
  static const double coinValue = 10;
  static const double coinSpawnInterval = 6.0;
  static const double fuelSpawnInterval = 35.0;
  static const double fuelCanValue = 30.0;
  static const double maxFuel = 100.0;
  static const double startingFuel = 100.0;
  static const double fuelBurnRate = 2.8;
  static const double fuelConsumptionRate = 2.8;
  static const double fuelPickupAmount = 30.0;
  static const double pickupRadius = 1.2;
  static const double coinRadius = 0.4;

  // ── Camera ──
  static const double cameraSmoothSpeed = 8.0;
  static const double cameraLookAhead = 6.0;
  static const double cameraVerticalOffset = 4.0;
  static const double startX = 0.0;

  // ── Visuals ──
  static const Color skyColor = Color(0xFF87CEEB);
  static const Color groundColor = Color(0xFF8B4513);
  static const Color grassColor = Color(0xFF228B22);
}
