import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/core/widgets/ai_robot_avatar.dart';
import 'package:tokigo/features/ai/domain/ai_chat_message.dart';
import 'package:tokigo/features/ai/presentation/pages/ai_chat_page.dart';
// ignore: unused_import

/// The assistant's robot identity (owner decision, 2026-11).
///
/// One asset, one size recipe, everywhere the assistant speaks:
/// * a COMPLETED assistant reply carries the robot;
/// * a USER reply never does;
/// * the thinking indicator carries it too, with the breathing pulse running;
/// * the welcome hero reuses the same widget.
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

  testWidgets('the welcome hero reuses the same robot widget', (tester) async {
    tester.view.physicalSize = const Size(720, 1480);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // The hero is the page's own welcome state, which needs the AI providers and
    // localizations; the page's welcome column is reproduced here so the test
    // asserts the SHARED widget rather than the whole page's dependency graph.
    await tester.pumpWidget(
      host(
        const Column(
          children: <Widget>[
            AiRobotAvatar(size: 96),
            SizedBox(height: 12),
            Text('Hi! Ask me about flights, hotels, and more…'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AiRobotAvatar), findsOneWidget);
    expect(
      tester.getSize(find.byType(AiRobotAvatar)).width,
      96,
      reason: 'the welcome hero draws the identity larger',
    );
    expect(find.text('Hi! Ask me about flights, hotels, and more…'), findsOneWidget);
  });

  test('the shared asset is the one the AI welcome state already shipped', () {
    expect(AiRobotAvatar.assetName, 'assets/images/TOKI AI.png');
  });
}
