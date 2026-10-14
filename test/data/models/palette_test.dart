import 'package:bead_light_board/data/models/json_support.dart';
import 'package:bead_light_board/data/models/palette.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Palette.fromJson 正常路径', () {
    test('解析合法色卡并保留全部字段', () {
      final Palette palette = Palette.fromJsonText('''
{
  "schemaVersion": 1,
  "id": "demo",
  "name": "Demo 色卡",
  "pitchMm": 5,
  "source": "单元测试",
  "colors": [
    { "code": "A01", "name": "白色", "hex": "#F2F2F0", "series": "A" },
    { "code": "A02", "hex": "#123456" }
  ]
}
''');

      expect(palette.id, 'demo');
      expect(palette.name, 'Demo 色卡');
      expect(palette.pitchMm, 5);
      expect(palette.source, '单元测试');
      expect(palette.length, 2);
      expect(palette.isEmpty, isFalse);

      expect(palette.colors[0].code, 'A01');
      expect(palette.colors[0].argb, 0xFFF2F2F0);
      expect(palette.colors[0].hex, '#F2F2F0');
      expect(palette.colors[0].name, '白色');
      expect(palette.colors[0].series, 'A');

      expect(palette.colors[1].name, isNull);
      expect(palette.colors[1].series, isNull);
      expect(palette.colors[1].hex, '#123456');
    });

    test('colors 为空数组时允许加载（表示尚未填写真实色号）', () {
      final Palette palette = Palette.fromJsonText(
        '{"schemaVersion": 1, "id": "empty", "name": "空色卡", "colors": []}',
      );
      expect(palette.isEmpty, isTrue);
      expect(palette.length, 0);
    });

    test('hex 大小写都接受，并统一归一化为大写', () {
      final Palette palette = Palette.fromJsonText(
        '{"schemaVersion":1,"id":"x","name":"X",'
        '"colors":[{"code":"c1","hex":"#abcdef"}]}',
      );
      expect(palette.colors[0].hex, '#ABCDEF');
      expect(palette.colors[0].argb, 0xFFABCDEF);
    });

    test('indexOfCode 能定位色号', () {
      final Palette palette = Palette.fromJsonText(
        '{"schemaVersion":1,"id":"x","name":"X",'
        '"colors":[{"code":"c1","hex":"#111111"},{"code":"c2","hex":"#222222"}]}',
      );
      expect(palette.indexOfCode('c1'), 0);
      expect(palette.indexOfCode('c2'), 1);
      expect(palette.indexOfCode('不存在'), isNull);
    });

    test('toJson 往返后内容一致', () {
      final Palette original = Palette.fromJsonText('''
{"schemaVersion":1,"id":"demo","name":"Demo","pitchMm":2.6,
 "colors":[{"code":"A01","name":"白","hex":"#F2F2F0","series":"A"}]}
''');
      final Palette roundTrip = Palette.fromJson(original.toJson());
      expect(roundTrip.id, original.id);
      expect(roundTrip.name, original.name);
      expect(roundTrip.pitchMm, original.pitchMm);
      expect(roundTrip.colors, original.colors);
    });
  });

  group('Palette.fromJson 错误路径', () {
    void expectPath(String json, String expectedPath) {
      expect(
        () => Palette.fromJsonText(json),
        throwsA(
          isA<ModelFormatException>().having(
            (ModelFormatException e) => e.path,
            'path',
            expectedPath,
          ),
        ),
      );
    }

    test('schemaVersion 缺失 / 类型错 / 版本不符', () {
      expectPath('{"id":"x","name":"X","colors":[]}', 'schemaVersion');
      expectPath(
        '{"schemaVersion":"1","id":"x","name":"X","colors":[]}',
        'schemaVersion',
      );
      expectPath(
        '{"schemaVersion":99,"id":"x","name":"X","colors":[]}',
        'schemaVersion',
      );
    });

    test('id / name 缺失或为空', () {
      expectPath('{"schemaVersion":1,"name":"X","colors":[]}', '.id');
      expectPath('{"schemaVersion":1,"id":"  ","name":"X","colors":[]}', '.id');
      expectPath('{"schemaVersion":1,"id":"x","colors":[]}', '.name');
    });

    test('colors 缺失或不是数组', () {
      expectPath('{"schemaVersion":1,"id":"x","name":"X"}', '.colors');
      expectPath(
        '{"schemaVersion":1,"id":"x","name":"X","colors":{}}',
        '.colors',
      );
    });

    test('hex 各种非法写法都要被拒绝，且错误路径指向具体色号', () {
      const List<String> badHex = <String>[
        'F2F2F0', // 缺 #
        '#FFF', // 3 位缩写
        '#GGGGGG', // 非十六进制
        '#FFFFFFFF', // 8 位（带透明度）不接受
        '#F2F2F', // 5 位
        '',
      ];
      for (final String hex in badHex) {
        expectPath(
          '{"schemaVersion":1,"id":"x","name":"X",'
              '"colors":[{"code":"c1","hex":"$hex"}]}',
          'colors[0].hex',
        );
      }
    });

    test('hex 缺失或不是字符串', () {
      expectPath(
        '{"schemaVersion":1,"id":"x","name":"X","colors":[{"code":"c1"}]}',
        'colors[0].hex',
      );
      expectPath(
        '{"schemaVersion":1,"id":"x","name":"X",'
            '"colors":[{"code":"c1","hex":123}]}',
        'colors[0].hex',
      );
    });

    test('色号缺失 / 为空 / 重复，错误信息要指出重复位置', () {
      expectPath(
        '{"schemaVersion":1,"id":"x","name":"X","colors":[{"hex":"#111111"}]}',
        'colors[0].code',
      );
      expectPath(
        '{"schemaVersion":1,"id":"x","name":"X",'
            '"colors":[{"code":" "},{"code":"b","hex":"#111111"}]}',
        'colors[0].code',
      );

      expect(
        () => Palette.fromJsonText(
          '{"schemaVersion":1,"id":"x","name":"X","colors":['
          '{"code":"dup","hex":"#111111"},'
          '{"code":"dup","hex":"#222222"}]}',
        ),
        throwsA(
          isA<ModelFormatException>()
              .having(
                (ModelFormatException e) => e.path,
                'path',
                'colors[1].code',
              )
              .having(
                (ModelFormatException e) => e.message,
                'message',
                contains('colors[0]'),
              ),
        ),
      );
    });

    test('colors 元素不是对象', () {
      expectPath(
        '{"schemaVersion":1,"id":"x","name":"X","colors":["nope"]}',
        'colors[0]',
      );
    });

    test('pitchMm 为 0 或负数要拒绝', () {
      expectPath(
        '{"schemaVersion":1,"id":"x","name":"X","pitchMm":0,"colors":[]}',
        '.pitchMm',
      );
      expectPath(
        '{"schemaVersion":1,"id":"x","name":"X","pitchMm":-5,"colors":[]}',
        '.pitchMm',
      );
    });

    test('JSON 本身坏掉时给出明确提示', () {
      expect(
        () => Palette.fromJsonText('{not json'),
        throwsA(
          isA<ModelFormatException>().having(
            (ModelFormatException e) => e.message,
            'message',
            contains('JSON 解析失败'),
          ),
        ),
      );
    });

    test('顶层不是对象时给出明确提示', () {
      expect(
        () => Palette.fromJsonText('[1,2,3]'),
        throwsA(
          isA<ModelFormatException>().having(
            (ModelFormatException e) => e.message,
            'message',
            contains('顶层必须是 JSON 对象'),
          ),
        ),
      );
    });
  });
}
