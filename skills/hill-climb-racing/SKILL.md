---
name: flutter-web-hill-climb-architecture
description: Architecture and phased implementation rules for a complete single-player 2D hill-climb racing game built with Flutter Web, Flame, and Forge2D.
---

## When to use

Use this skill when building or extending a browser-playable, single-player 2D side-scrolling vehicle game in Flutter. It covers physics, procedural terrain, camera movement, coins, fuel, controls, HUD, persistence, testing, and deployment without a backend.

## Rules

1. **Use Flame as the game runtime and Forge2D for simulation.**
   - Use `flame` for the game loop, components, input, camera, rendering, overlays, and asset loading.
   - Use `flame_forge2d` and Forge2D bodies, fixtures, joints, and contacts for vehicle and terrain physics.
   - Do not implement vehicle collision or gravity manually in Flutter widgets.

2. **Keep Flutter UI separate from the simulation.**
   - Flutter widgets may render menus, pause screens, settings, and HUD overlays.
   - Flame components own gameplay rendering and updates.
   - Communicate through immutable game state, commands, and callbacks rather than making game components depend directly on widget state.

3. **Use a fixed simulation timestep with interpolation-safe rendering.**
   - Run physics at a stable fixed timestep, preferably 60 Hz.
   - Accumulate elapsed time and cap catch-up steps to prevent browser-tab stalls from causing explosive simulation updates.
   - Keep rendering responsive even when the browser frame rate fluctuates.

4. **Represent terrain as deterministic chunks.**
   - Generate terrain from a seed and chunk index so the same run can be reproduced.
   - Keep a small active window around the vehicle, such as the current chunk plus several chunks ahead and behind.
   - Remove distant physics bodies and components to control memory and collision cost.

5. **Separate world units from pixels.**
   - Define one world-unit scale and use it consistently for bodies, terrain, camera coordinates, and gameplay distances.
   - Convert screen pixels only at the rendering/input boundary.
   - Tune physics dimensions in meters-like world units instead of using arbitrary screen-pixel values.

6. **Model gameplay through explicit state and events.**
   - Track fuel, coins, distance, speed, airtime, flip state, vehicle upgrades, pause status, and game-over reason in a testable state model.
   - Emit events such as `coinCollected`, `fuelConsumed`, `fuelDepleted`, `vehicleCrashed`, `checkpointReached`, and `runEnded`.
   - Do not embed score, fuel, or progression rules inside rendering code.

7. **Use simple deterministic controls.**
   - Support keyboard controls first: gas, brake/reverse, and left/right tilt.
   - Map touch and pointer buttons to the same command interface.
   - Apply controls to wheel torque, braking, and chassis angular torque; avoid directly setting chassis position or rotation during normal gameplay.

8. **Optimize for Flutter Web.**
   - Prefer vector drawing, generated terrain, and small sprite sheets over large animated assets.
   - Avoid per-frame widget rebuilds and unbounded object creation.
   - Dispose listeners, timers, overlays, and physics bodies when a run or game instance ends.
   - Verify builds with both `flutter test` and `flutter build web --release`.

## Steps

1. **Create the Flutter Web project dependencies.**
   - Add compatible versions of `flame`, `flame_forge2d`, and optionally `shared_preferences` for local best scores.
   - Keep Flutter widgets and game code in the same application; no backend or network service is required.
   - Verify with `flutter pub get` and `flutter analyze`.

2. **Create the feature-oriented source structure.**

   ```text
   lib/
   ├── main.dart
   ├── app/
   │   ├── app.dart
   │   ├── app_theme.dart
   │   └── routes.dart
   ├── game/
   │   ├── hill_climb_game.dart
   │   ├── game_config.dart
   │   ├── game_state.dart
   │   ├── game_events.dart
   │   ├── game_commands.dart
   │   ├── camera/
   │   │   └── follow_camera.dart
   │   ├── physics/
   │   │   ├── physics_world.dart
   │   │   ├── vehicle_body.dart
   │   │   ├── wheel_body.dart
   │   │   ├── terrain_body.dart
   │   │   └── contact_listener.dart
   │   ├── terrain/
   │   │   ├── terrain_generator.dart
   │   │   ├── terrain_chunk.dart
   │   │   ├── terrain_streamer.dart
   │   │   └── terrain_profile.dart
   │   ├── entities/
   │   │   ├── vehicle_component.dart
   │   │   ├── coin_component.dart
   │   │   ├── fuel_can_component.dart
   │   │   └── checkpoint_component.dart
   │   ├── systems/
   │   │   ├── input_system.dart
   │   │   ├── fuel_system.dart
   │   │   ├── scoring_system.dart
   │   │   ├── crash_system.dart
   │   │   └── progression_system.dart
   │   └── rendering/
   │       ├── background_component.dart
   │       ├── terrain_renderer.dart
   │       └── vehicle_renderer.dart
   ├── ui/
   │   ├── game_page.dart
   │   ├── game_overlay.dart
   │   ├── hud_overlay.dart
   │   ├── main_menu.dart
   │   ├── pause_menu.dart
   │   └── game_over_overlay.dart
   ├── persistence/
   │   └── local_progress_repository.dart
   └── shared/
       ├── result.dart
       └── geometry.dart

  test/
  ├── terrain_generator_test.dart
  ├── fuel_system_test.dart
  ├── scoring_system_test.dart
  └── game_state_test.dart

  assets/
  ├── images/
  ├── audio/
  └── fonts/
  ```

3. **Define the game configuration before implementing entities.**
   - Put gravity, world scale, timestep, terrain chunk width, vehicle dimensions, wheel friction, suspension limits, fuel rates, camera look-ahead, and maximum catch-up steps in `game_config.dart`.
   - Make gameplay tuning values data-driven and centralized.
   - Verify that changing a tuning value does not require editing multiple systems.

4. **Implement the game shell and lifecycle.**
   - Create `HillClimbGame extends Forge2DGame`.
   - Configure gravity, camera, viewport, debug mode, and world scale.
   - Add explicit lifecycle methods for `prepareRun`, `startRun`, `pauseRun`, `resumeRun`, `endRun`, and `resetRun`.
   - Verify that a run can be started, paused, resumed, reset, and disposed without duplicate entities or listeners.

5. **Implement the vehicle using a chassis, two wheels, and suspension joints.**
   - Create a dynamic chassis body with a polygon fixture.
   - Create dynamic wheel bodies with circular fixtures.
   - Connect wheels to the chassis using `WheelJoint`s or equivalent suspension joints.
   - Configure wheel motor speed, motor torque, suspension frequency, damping, density, friction, and category masks.
   - Use a separate visual component or child renderers so the physics body is not responsible for all drawing.
   - Verify that the vehicle rests on terrain, accelerates, brakes, rotates in air, and responds to impacts.

6. **Implement collision categories and contact handling.**
   - Define filters for vehicle chassis, wheels, terrain, coins, fuel, checkpoints, and sensor fixtures.
   - Use contacts only to report gameplay events; do not mutate unrelated game state directly from low-level collision code.
   - Route contacts through `game_events.dart` and process them in gameplay systems.
   - Verify that coins and fuel are collected once, terrain supports the vehicle, and non-solid sensors do not block movement.

7. **Implement deterministic procedural terrain.**
   - Generate a height profile using seeded noise or layered sine/noise functions with bounded slopes.
   - Add smoothing and slope limits so terrain remains driveable.
   - Build each chunk as a chain or edge fixture, with optional static solid fill below the surface.
   - Ensure adjacent chunks share matching boundary height and slope.
   - Add deterministic spawn locations for coins, fuel, and checkpoints based on the same seed.
   - Verify that two generators with the same seed produce identical terrain and pickups.

8. **Implement terrain streaming around the player.**
   - Track the vehicle’s world x-coordinate.
   - Generate chunks ahead before they become visible and retain a safety margin behind the player.
   - Remove old chunks, their pickups, and their Forge2D bodies outside the active window.
   - Never regenerate an existing chunk with different geometry during a run.
   - Verify long-distance driving does not cause unbounded component or body growth.

9. **Implement camera and rendering layers.**
   - Follow the vehicle with bounded horizontal and vertical movement.
   - Add camera look-ahead based on velocity, with clamped limits to avoid excessive jitter.
   - Render parallax background layers independently from physics terrain.
   - Draw terrain using a filled surface plus a visible outline; keep decorative backgrounds non-collidable.
   - Verify the vehicle remains readable and the camera does not reveal ungenerated terrain.

10. **Implement the shared command and state model.**
    - Define commands such as `accelerate`, `brake`, `tiltLeft`, `tiltRight`, `pause`, and `restart`.
    - Define immutable state fields for phase, fuel, coins, distance, speed, best distance, vehicle health, and game-over reason.
    - Apply commands through `InputSystem`; expose state snapshots to Flutter overlays.
    - Verify that keyboard, pointer, and touch inputs produce identical gameplay behavior.

11. **Implement keyboard and browser-safe input.**
    - Register keyboard listeners only while the game page is mounted.
    - Prevent browser scrolling for gameplay keys when appropriate.
    - Track key-down and key-up state rather than relying only on key-repeat events.
    - Clear all pressed keys on focus loss, pause, route changes, and disposal.
    - Verify controls work with `W`/up for gas, `S`/down for brake, and `A`/`D` or left/right for tilt.

12. **Implement touch and pointer controls with Flutter overlays.**
    - Add large, accessible gas, brake, and tilt buttons through `GameWidget` overlays.
    - Use pointer-down and pointer-up callbacks to issue press/release commands.
    - Make buttons responsive without rebuilding the entire game tree every frame.
    - Verify controls work on a browser touch device and do not interfere with camera or page scrolling.

13. **Implement fuel, coins, scoring, and failure conditions as systems.**
    - Consume fuel while the engine is active, with consumption based on throttle and optionally vehicle load.
    - Add fuel pickups and a clear fuel meter.
    - Add coins, distance scoring, stunt or flip bonuses only after the base scoring loop works.
    - Define crash conditions such as chassis impact, excessive angular velocity, or vehicle health depletion.
    - End the run when fuel reaches zero, the vehicle crashes, or another explicit failure condition occurs.
    - Verify fuel cannot become negative, pickups cannot be double-counted, and game-over is idempotent.

14. **Implement progression without a backend.**
    - Store only local progress such as best distance, best coins, selected vehicle, and unlocked upgrades.
    - Use `shared_preferences` or a small local repository abstraction.
    - Keep persistence outside the game simulation and write results at run completion or checkpoint intervals.
    - Verify the game remains playable when storage is unavailable or cleared.

15. **Build the Flutter page and overlays.**
    - Use `GameWidget` as the primary game surface.
    - Add overlays for HUD, main menu, pause, settings, and game over.
    - Keep HUD updates limited to state changes or a modest refresh cadence rather than rebuilding every physics step.
    - Ensure the canvas fills the browser viewport and adapts to resize and device pixel ratio.
    - Verify the game is playable at desktop and narrow mobile-browser dimensions.

16. **Add visual and audio assets incrementally.**
    - Start with generated shapes and simple colors so physics and gameplay can be validated without asset dependencies.
    - Add sprites, sound effects, background music, and particles only after the playable loop is stable.
    - Load assets through Flame’s asset cache and handle missing optional audio gracefully.
    - Verify release builds contain all declared assets and do not rely on filesystem paths unavailable on the web.

17. **Test pure systems independently of the browser.**
    - Test seeded terrain generation, chunk boundaries, spawn placement, fuel consumption, score calculation, state transitions, and persistence fallback using Dart tests.
    - Keep procedural generation and gameplay calculations independent from Flame where practical.
    - Add a debug mode with physics outlines, chunk IDs, contact labels, and vehicle telemetry.
    - Verify deterministic tests do not depend on wall-clock time or browser rendering.

18. **Validate performance and browser behavior.**
    - Profile with Flutter DevTools in a release-like web build.
    - Confirm active Forge2D body count, component count, frame time, and memory remain bounded during extended driving.
    - Cap physics catch-up work after tab throttling or focus changes.
    - Avoid rebuilding large widget subtrees from per-frame game updates.
    - Verify keyboard focus, browser resize, tab switching, pause behavior, and pointer capture.

19. **Deploy with the Flutter Web toolchain.**
    - Run formatting, static analysis, unit tests, and a release build:

      ```bash
      dart format .
      flutter analyze
      flutter test
      flutter build web --release
      ```

    - Serve `build/web` from a static web host with fallback routing configured if client-side routes are used.
    - Verify production loading over HTTPS, asset paths, responsive sizing, audio restrictions, and browser compatibility.

## Definition of done

- The project runs as a Flutter Web application with no backend.
- A player can start, drive, brake, tilt, collect coins, collect fuel, pause, restart, and reach game over.
- Vehicle physics use Forge2D bodies and joints rather than manually positioned gameplay objects.
- Terrain is procedurally generated, seeded, continuous between chunks, and streamed with bounded memory.
- Camera movement, terrain rendering, pickups, collisions, fuel, scoring, and failure states work together.
- Keyboard, pointer, and touch controls share one command path.
- HUD, pause, main-menu, and game-over overlays work without frame-by-frame widget rebuilds.
- Gameplay rules and terrain generation have automated tests.
- `flutter analyze`, `flutter test`, and `flutter build web --release` pass.
- The release build runs correctly in a browser after static hosting from `build/web`.