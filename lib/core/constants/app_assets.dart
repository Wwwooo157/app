/// 资源路径常量。
///
/// 单独放一处，避免"字符串字面量散落各处"——导入与网格两个界面必须用
/// **同一个**色卡，否则量化出来的索引与显示的颜色会对不上。
library;

/// 夹具色卡（T01–T08，**非真实色号**，只用于跑通流程）。
///
/// 真实色号请填在 mard/perler/hama/artkal 里，然后把这个常量换掉即可。
const String kFixturePaletteAsset = 'assets/palettes/test_fixture.json';
