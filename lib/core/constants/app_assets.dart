/// 资源路径常量。
///
/// 单独放一处，避免"字符串字面量散落各处"——导入与网格两个界面必须用
/// **同一个**色卡，否则量化出来的索引与显示的颜色会对不上。
library;

/// 夹具色卡（T01–T08，**非真实色号**，只用于跑通流程与单测）。
///
/// 测试**必须**显式注入它，不要依赖它是默认值 —— 默认色卡是真实数据，
/// 而真实数据随时可能被使用者更新，不该让测试跟着晃。
const String kFixturePaletteAsset = 'assets/palettes/test_fixture.json';

/// 默认色卡：MARD 221 色（国内主流参考体系）。
///
/// 数据出处与已知分歧见 `assets/palettes/mard.json` 的 `source` 字段，
/// 以及 `docs/palette-schema.md`。App 内置它是为了方便开箱即用；
/// 请以手上的**实物色卡**为准，发现偏差直接改 JSON 即可。
const String kDefaultPaletteAsset = 'assets/palettes/mard.json';
