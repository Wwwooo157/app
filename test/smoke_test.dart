import 'package:bead_light_board/app.dart';
import 'package:bead_light_board/core/constants/app_strings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('骨架能启动、渲染首页且无布局异常', (WidgetTester tester) async {
    await tester.pumpWidget(const BeadLightBoardApp());

    // 标题存在（说明主题与首页装配正确）
    expect(find.text(AppStrings.appTitle), findsOneWidget);
    // 副标题存在（说明首页内容真的渲染出来了，不是白屏）
    expect(find.text(AppStrings.appTagline), findsOneWidget);
    // 没有未捕获异常（RenderFlex overflow 等在这里会被抓到）
    expect(tester.takeException(), isNull);
  });
}
