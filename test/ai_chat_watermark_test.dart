import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/core/widgets/ai_robot_avatar.dart';
import 'package:tokigo/features/ai/presentation/widgets/ai_chat_watermark.dart';

/// The AI chat watermark (owner decision, 2026-11).
///
/// The EXISTING TokiGo brand mark, drawn faint behind the conversation:
/// * it never intercepts a tap meant for the content above it;
/// * it is excluded from the semantics tree (pure decoration);
/// * it uses the same transparent light/dark masters as the assistant mark.
void main() {
  testWidgets('the watermark is inert and excluded from semantics', (
    tester,
  ) async {
    int taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Stack(
            children: <Widget>[
              const Positioned.fill(child: AiChatWatermark()),
              Center(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => taps++,
                  child: const SizedBox(width: 120, height: 120),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AiChatWatermark), findsOneWidget);

    // A tap on the watermark's own area reaches the content above it.
    await tester.tapAt(tester.getCenter(find.byType(AiChatWatermark)));
    await tester.pump();
    expect(taps, 1);

    // It is decoration: no semantics node of its own.
    expect(
      find.descendant(
        of: find.byType(AiChatWatermark),
        matching: find.byType(Semantics),
      ),
      findsNothing,
    );
  });

  testWidgets('the watermark draws the existing transparent brand mark', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: AiChatWatermark()),
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
  });
}
