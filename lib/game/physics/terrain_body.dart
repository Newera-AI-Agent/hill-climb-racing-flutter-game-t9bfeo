import 'dart:math';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';
import '../game_config.dart';

/// A terrain segment rendered as a Forge2D chain shape.
/// Points are in world coordinates; the body is static.
class TerrainBody extends BodyComponent {
  final List<Vector2> points;
  final double startX;
  final double endX;
  final Paint _groundPaint;
  final Paint _grassPaint;
  final Paint _deepGroundPaint;

  TerrainBody(this.points, this.startX, this.endX)
      : _groundPaint = Paint()
          ..color = const Color(0xFF8B5E3C)
          ..style = PaintingStyle.fill,
        _grassPaint = Paint()
          ..color = const Color(0xFF4CAF50)
          ..style = PaintingStyle.fill,
        _deepGroundPaint = Paint()
          ..color = const Color(0xFF6D4C41)
          ..style = PaintingStyle.fill;

  @override
  Body createBody() {
    final bodyDef = BodyDef(
      type: BodyType.static,
      position: Vector2.zero(),
    );
    final body = world.createBody(bodyDef);

    // Create chain shape from points
    if (points.length < 2) return body;

    for (int i = 0; i < points.length - 1; i++) {
      final edge = EdgeShape()
        ..set(points[i], points[i + 1]);
      body.createFixture(FixtureDef(edge)
        ..friction = 0.7
        ..restitution = 0.0);
    }

    return body;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (points.length < 2) return;

    canvas.save();

    final path = Path();
    path.moveTo(points[0].x, points[0].y);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].x, points[i].y);
    }

    // Extend down to fill the ground area
    final lastX = points.last.x;
    final firstX = points.first.x;
    path.lineTo(lastX, GameConfig.worldHeight);
    path.lineTo(firstX, GameConfig.worldHeight);
    path.close();

    // Draw deep ground
    canvas.drawPath(path, _deepGroundPaint);

    // Draw brown strip just below surface
    final surfacePath = Path();
    surfacePath.moveTo(points[0].x, points[0].y);
    for (int i = 1; i < points.length; i++) {
      surfacePath.lineTo(points[i].x, points[i].y);
    }
    final surfaceBottom = 0.5;
    surfacePath.lineTo(lastX, points.last.y + surfaceBottom);
    surfacePath.lineTo(firstX, points.first.y + surfaceBottom);
    surfacePath.close();
    canvas.drawPath(surfacePath, _groundPaint);

    // Draw green grass line at the very top
    final grassPath = Path();
    grassPath.moveTo(points[0].x, points[0].y);
    for (int i = 1; i < points.length; i++) {
      grassPath.lineTo(points[i].x, points[i].y);
    }
    final grassOffset = 0.15;
    grassPath.lineTo(lastX, points.last.y + grassOffset);
    grassPath.lineTo(firstX, points.first.y + grassOffset);
    grassPath.close();
    canvas.drawPath(grassPath, _grassPaint);

    // Draw surface outline
    final outlinePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.06;
    final outlinePath = Path();
    outlinePath.moveTo(points[0].x, points[0].y);
    for (int i = 1; i < points.length; i++) {
      outlinePath.lineTo(points[i].x, points[i].y);
    }
    canvas.drawPath(outlinePath, outlinePaint);

    canvas.restore();
  }
}

/// Generates terrain height for a given x coordinate.
/// Uses layered Perlin-like noise for natural-looking hills.
class TerrainGenerator {
  final Random _random;
  final double _seed;

  TerrainGenerator({int? seed})
      : _seed = (seed ?? GameConfig.terrainSeed).toDouble(),
        _random = Random(seed ?? GameConfig.terrainSeed);

  /// Get terrain surface Y at world coordinate x.
  /// Returns the Y value (positive is down in Forge2D).
  double getHeight(double x) {
    final noise1 = sin(x * 0.03 + _seed) * 4.0;
    final noise2 = sin(x * 0.07 + _seed * 1.7) * 2.5;
    final noise3 = sin(x * 0.15 + _seed * 0.4) * 1.5;
    final noise4 = cos(x * 0.22 + _seed * 2.1) * 1.0;

    // Steeper hills occasionally
    final steepHill = sin(x * 0.01 + _seed * 3.0);
    final steepFactor = steepHill > 0.7 ? (steepHill - 0.7) * 15.0 : 0.0;

    // Base terrain at ~25m, with noise adding variation
    var height = GameConfig.minTerrainY +
        (GameConfig.maxTerrainY - GameConfig.minTerrainY) / 2 +
        noise1 + noise2 + noise3 + noise4 + steepFactor;

    // Clamp to reasonable bounds
    if (height < GameConfig.minTerrainY) height = GameConfig.minTerrainY;
    if (height > GameConfig.maxTerrainY) height = GameConfig.maxTerrainY;

    return height;
  }

  /// Generate a terrain chunk from startX to endX with the given point spacing.
  List<Vector2> generateChunk(double startX, double endX, {double spacing = 0.5}) {
    final points = <Vector2>[];
    var x = startX;
    while (x <= endX + spacing) {
      final y = getHeight(x);
      points.add(Vector2(x, y));
      x += spacing;
    }
    return points;
  }
}
