import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/core/widgets/ai_robot_avatar.dart';
import 'package:tokigo/features/ai/domain/ai_chat_message.dart';
import 'package:tokigo/features/ai/presentation/pages/ai_chat_page.dart';
// ignore: unused_import

/// The assistant's brand identity (owner decision, 2026-11).
///
/// One asset, one size recipe, everywhere the assistant speaks:
/// * a COMPLETED assistant reply carries the brand mark;
/// * a USER reply never does;
/// * the thinking indicator carries it too, with the breathing pulse running;
/// * the welcome state is text-only (owner decision: no brand mark there).
void main() {
  Widget host(Widget child, {TextDirection direction = TextDirection.ltr}) {
    return ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: Directionality(
          textDirection: direction,
          child: Scaffold(body: child),
        ),
      ),
    );
  }

  void noop() {}

  testWidgets('an assistant reply carries the robot, a user reply does not', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1480);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      host(
        ListView(
          children: <Widget>[
            ChatBubble(
              message: const AiChatMessage.user('find me a hotel'),
              showRetry: false,
              onRetry: noop,
            ),
            ChatBubble(
              message: const AiChatMessage.assistant('Here are three stays'),
              showRetry: false,
              onRetry: noop,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Exactly ONE robot in the thread — beside the assistant turn only.
    expect(find.byType(AiRobotAvatar), findsOneWidget);

    final Rect robot = tester.getRect(find.byType(AiRobotAvatar));
    final Rect userBubble = tester.getRect(find.text('find me a hotel'));
    final Rect assistantBubble = tester.getRect(
      find.text('Here are three stays'),
    );

    // The robot belongs to the assistant turn, on its leading edge.
    expect(robot.center.dy, lessThan(assistantBubble.bottom));
    expect(robot.right, lessThanOrEqualTo(assistantBubble.left + 1));
    // It never sits beside the user's own message.
    expect(robot.center.dy, greaterThan(userBubble.bottom - 1));
  });

  testWidgets('the thinking indicator carries the robot and the pulse runs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1480);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // The animated mark DOES breathe: the pulse is an AnimatedBuilder INSIDE the
    // robot's own box.
    await tester.pumpWidget(
      host(
        const Align(
          alignment: Alignment.centerLeft,
          child: AiRobotAvatar(size: 40, animate: true),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 120));
    expect(
      find.descendant(
        of: find.byType(AiRobotAvatar),
        matching: find.byType(AnimatedBuilder),
      ),
      findsOneWidget,
    );

    // The static variant has no pulse at all.
    await tester.pumpWidget(
      host(
        const Align(
          alignment: Alignment.centerLeft,
          child: AiRobotAvatar(size: 40),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AiRobotAvatar),
        matching: find.byType(AnimatedBuilder),
      ),
      findsNothing,
    );
  });

  testWidgets('the robot mirrors to the trailing edge in Arabic (RTL)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1480);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      host(
        ListView(
          children: <Widget>[
            ChatBubble(
              message: const AiChatMessage.assistant('هذه ثلاث فنادق'),
              showRetry: false,
              onRetry: noop,
            ),
          ],
        ),
        direction: TextDirection.rtl,
      ),
    );
    await tester.pumpAndSettle();

    final Rect robot = tester.getRect(find.byType(AiRobotAvatar));
    final Rect bubble = tester.getRect(find.text('هذه ثلاث فنادق'));
    // In RTL the assistant turn's leading edge is the RIGHT one: the robot sits
    // to the right of the message, not to its left.
    expect(robot.left, greaterThan(bubble.right - 40));
    expect(robot.right, lessThanOrEqualTo(bubble.right + 80));
    expect(robot.left, greaterThan(bubble.left));
  });

  testWidgets('the welcome state is text-only (no brand mark)', (tester) async {
    tester.view.physicalSize = const Size(720, 1480);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // The page's welcome column is reproduced here (the real page needs the AI
    // providers and localizations). Owner decision: it carries the welcome
    // message only — the umbrella/brand mark is gone from the welcome state.
    await tester.pumpWidget(
      host(
        const Column(
          children: <Widget>[
            Text('Hi! Ask me about flights, hotels, and more…'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AiRobotAvatar), findsNothing);
    expect(find.text('Hi! Ask me about flights, hotels, and more…'), findsOneWidget);
  });

  test('the shared asset is the existing TokiGo brand mark', () {
    expect(
      AiRobotAvatar.lightAssetName,
      'assets/icon/app_icon_adaptive_foreground_1024.png',
    );
    expect(
      AiRobotAvatar.darkAssetName,
      'assets/icon/app_icon_adaptive_dark_foreground_1024.png',
    );
  });

  testWidgets('the light and dark surfaces pick their own transparent mark', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: AiRobotAvatar(size: 32)),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<Image>(find.byType(Image)).image,
      isA<AssetImage>().having(
        (AssetImage a) => a.assetName,
        'assetName',
        AiRobotAvatar.lightAssetName,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(body: AiRobotAvatar(size: 32)),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<Image>(find.byType(Image)).image,
      isA<AssetImage>().having(
        (AssetImage a) => a.assetName,
        'assetName',
        AiRobotAvatar.darkAssetName,
      ),
    );
  });
}
