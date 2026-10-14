import 'package:bead_light_board/data/models/json_support.dart';

/// 拼豆板规格。
///
/// `pitchMm` 是豆子中心间距（毫米）。**故意允许为 null**：本 App 不猜品牌规格，
/// 屏幕与物理钉位的 1:1 对齐最终由"标尺校准"（S5）确定；
/// 只有在确认了具体品牌型号时才填这里的标称值作为默认估计。
final class BoardSpec {
  const BoardSpec({
    required this.id,
    required this.name,
    required this.rows,
    required this.cols,
    this.pitchMm,
  });

  /// 规格标识，例如 `square_29`。
  final String id;

  /// 显示名。
  final String name;

  /// 行数。
  final int rows;

  /// 列数。
  final int cols;

  /// 标称间距（毫米），null 表示未确认。
  final double? pitchMm;

  /// 总钉位（格子）数。
  int get pegCount => rows * cols;

  /// 是否方板。
  bool get isSquare => rows == cols;

  /// 若已知间距，返回物理边长（毫米）；否则 null。
  double? get physicalWidthMm => pitchMm == null ? null : pitchMm! * cols;

  /// 若已知间距，返回物理高度（毫米）；否则 null。
  double? get physicalHeightMm => pitchMm == null ? null : pitchMm! * rows;

  /// 从 JSON 解析。
  static BoardSpec fromJson(Map<String, Object?> json, {required String path}) {
    return BoardSpec(
      id: requireString(json, 'id', path),
      name: requireString(json, 'name', path),
      rows: requirePositiveInt(json, 'rows', path),
      cols: requirePositiveInt(json, 'cols', path),
      pitchMm: optionalPositiveDouble(json, 'pitchMm', path),
    );
  }

  @override
  String toString() =>
      'BoardSpec($id, ${rows}x$cols${pitchMm == null ? ', pitch=?' : ', ${pitchMm}mm'})';
}
