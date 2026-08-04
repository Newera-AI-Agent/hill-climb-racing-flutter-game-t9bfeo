import 'dart:math';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';
import '../game_config.dart';

/// The main vehicle chassis as a Forge2D polygon body.
/// Has a trapezoidal shape (narrower top, wider bottom) and draws
/// body color, window, and outline.
class VehicleBody extends BodyComponent {
  final Paint _paint;
  final Paint _windowPaint;
  late final PolygonShape _chassisShape;

  /// Wheel bodies attached to this chassis via wheel joints.
  Body? rearWheel;
  Body? frontWheel;
  Joint? rearJoint;
  Joint? frontJoint;

  VehicleBody({Color? color})
      : _paint = Paint()
          ..color = color ?? Colors.red.shade600
          ..style = PaintingStyle.fill,
        _windowPaint = Paint()
          ..color = Colors.lightBlue.shade200
          ..style = PaintingStyle.fill;

  @override
  Body createBody() {
    final shape = PolygonShape();
    final w = GameConfig.chassisWidth;
    final h = GameConfig.chassisHeight;

    // Trapezoidal chassis: wider bottom, narrower top.
    final vertices = <Vector2>[
      Vector2(-w * 0.4, h * 0.5),   // top-left
      Vector2(w * 0.4, h * 0.5),    // top-right
      Vector2(w * 0.5, -h * 0.3),   // mid-right
      Vector2(w * 0.5, -h * 0.5),   // bottom-right
      Vector2(-w * 0.5, -h * 0.5),  // bottom-left
      Vector2(-w * 0.5, -h * 0.3),  // mid-left
    ];

    shape.set(vertices);
    _chassisShape = shape;

    final fixtureDef = FixtureDef(shape)
      ..density = 2.5
      ..friction = 0.4
      ..restitution = 0.05;

    final bodyDef = BodyDef(
      type: BodyType.dynamic,
      position: Vector2(5, 10),
      linearDamping: 0.05,
      angularDamping: 1.5,
    );

    return world.createBody(bodyDef)..createFixture(fixtureDef);
  }

  /// Create two wheels and attach them to the chassis with wheel joints.
  void attachWheels(World world) {
    if (body == null) return;

    final w = GameConfig.chassisWidth;
    final r = GameConfig.wheelRadius;

    // Rear wheel
    rearWheel = _createWheelBody(
      world,
      body!.position + Vector2(-w * 0.4, -GameConfig.chassisHeight * 0.6),
    );
    rearJoint = _createWheelJoint(
      world,
      body!,
      rearWheel!,
      Vector2(-w * 0.4, -GameConfig.chassisHeight * 0.5),
    );

    // Front wheel
    frontWheel = _createWheelBody(
      world,
      body!.position + Vector2(w * 0.4, -GameConfig.chassisHeight * 0.6),
    );
    frontJoint = _createWheelJoint(
      world,
      body!,
      frontWheel!,
      Vector2(w * 0.4, -GameConfig.chassisHeight * 0.5),
    );
  }

  Body _createWheelBody(World world, Vector2 position) {
    final shape = CircleShape()..radius = GameConfig.wheelRadius;

    final fixtureDef = FixtureDef(shape)
      ..density = 1.0
      ..friction = 1.2
      ..restitution = 0.1;

    final bodyDef = BodyDef(
      type: BodyType.dynamic,
      position: position,
      linearDamping: 0.05,
    );

    final wheel = world.createBody(bodyDef);
    wheel.createFixture(fixtureDef);
    return wheel;
  }

  WheelJoint _createWheelJoint(
    World world,
    Body chassis,
    Body wheel,
    Vector2 localAnchor,
  ) {
    final jointDef = WheelJointDef()
      ..initialize(chassis, wheel, wheel.position, Vector2(0, 1))
      ..localAnchorA.setFrom(localAnchor)
      ..localAxisA.setFrom(Vector2(0, 1))
      ..frequencyHz = GameConfig.suspensionStiffness * 0.05
      ..dampingRatio = GameConfig.suspensionDamping * 0.05
      ..enableMotor = true;

    return world.createJoint(jointDef) as WheelJoint;
  }

  /// Set motor speed for both wheel joints (positive = forward).
  void setWheelMotorSpeed(double speed) {
    (rearJoint as WheelJoint?)?.setMotorSpeed(speed);
    (frontJoint as WheelJoint?)?.setMotorSpeed(speed);
  }

  /// Apply torque to the rear wheel for additional rotation.
  void applyTorque(double torque) {
    rearWheel?.applyAngularImpulse(torque);
  }

  /// Clean up joints and wheels.
  void dispose(World world) {
    for (final joint in [rearJoint, frontJoint]) {
      if (joint != null) world.destroyJoint(joint);
    }
    for (final wheel in [rearWheel, frontWheel]) {
      if (wheel != null) world.destroyBody(wheel);
    }
    rearWheel = null;
    frontWheel = null;
    rearJoint = null;
    frontJoint = null;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final b = this.body;
    if (b == null) return;

    canvas.save();
    final pos = b.position;
    final angle = b.angle;
    canvas.translate(pos.x, pos.y);
    canvas.rotate(angle);

    // Draw chassis
    final path = _buildChassisPath();
    canvas.drawPath(path, _paint);

    // Chassis outline
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.black87
        ..strokeWidth = 0.06,
    );

    // Window
    final windowPath = Path();
    final ww = GameConfig.chassisWidth / 2.5;
    final wh = GameConfig.chassisHeight / 3.5;
    windowPath.addRRect(RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(0, GameConfig.chassisHeight * 0.1),
        width: ww,
        height: wh,
      ),
      Radius.circular(0.15),
    ));
    canvas.drawPath(windowPath, _windowPaint);
    canvas.drawPath(
      windowPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.blueGrey.shade700
        ..strokeWidth = 0.04,
    );

    canvas.restore();
  }

  Path _buildChassisPath() {
    final path = Path();
    final w = GameConfig.chassisWidth;
    final h = GameConfig.chassisHeight;

    // Rounded trapezoidal chassis
    path.moveTo(-w * 0.4, h * 0.5);
    path.lineTo(w * 0.4, h * 0.5);
    path.quadraticBezierTo(w * 0.5, h * 0.3, w * 0.5, 0);
    path.lineTo(w * 0.5, -h * 0.5);
    path.lineTo(-w * 0.5, -h * 0.5);
    path.lineTo(-w * 0.5, 0);
    path.quadraticBezierTo(-w * 0.5, h * 0.3, -w * 0.4, h * 0.5);
    path.close();

    return path;
  }

  /// Render the wheels (called separately by the game).
  void renderWheels(Canvas canvas) {
    for (final wheel in [rearWheel, frontWheel]) {
      if (wheel == null) continue;
      canvas.save();
      final pos = wheel.position;
      final angle = wheel.angle;
      canvas.translate(pos.x, pos.y);
      canvas.rotate(angle);

      final r = GameConfig.wheelRadius;

      // Tire
      canvas.drawCircle(Offset.zero, r, Paint()..color = Colors.grey.shade800);
      canvas.drawCircle(
        Offset.zero,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = Colors.black
          ..strokeWidth = 0.05,
      );

      // Hub
      canvas.drawCircle(Offset.zero, r * 0.3, Paint()..color = Colors.grey.shade400);

      // Spokes
      final spokePaint = Paint()
        ..color = Colors.grey.shade600
        ..strokeWidth = 0.03;
      for (int i = 0; i < 5; i++) {
        final spokeAngle = i * (pi * 2 / 5) + angle;
        final dx = r * 0.6 * cos(spokeAngle);
        final dy = r * 0.6 * sin(spokeAngle);
        canvas.drawLine(Offset.zero, Offset(dx, dy), spokePaint);
      }

      canvas.restore();
    }
  }
}
