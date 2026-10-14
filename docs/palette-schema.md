# 色卡与板规格数据格式

本 App **不内置任何真实色号**，也不推测色号。色卡与板规格都是普通的 JSON 配置文件，
放在 `assets/` 下，由你自行填写与维护。本文档说明结构与校验规则。

解析代码：`lib/data/models/palette.dart`、`lib/data/models/bead_color.dart`。
校验规则有单测覆盖，写错时会给出**具体字段路径**（例如 `colors[3].hex`）。

---

## 1. 色卡文件 `assets/palettes/<id>.json`

```json
{
  "schemaVersion": 1,
  "id": "mard",
  "name": "MARD",
  "pitchMm": null,
  "source": "数据来源：包装盒背面色表，2026-10 抄录",
  "colors": [
    { "code": "A01", "name": "白色", "hex": "#F2F2F0", "series": "A" },
    { "code": "A02", "name": "米白", "hex": "#E8E0CE", "series": "A" }
  ]
}
```

### 顶层字段

| 字段 | 必填 | 说明 |
|---|---|---|
| `schemaVersion` | ✅ | 固定为 `1`。将来结构变更时递增，旧文件会被明确拒绝而不是静默误读 |
| `id` | ✅ | 色卡标识，需与清单 `index.json` 里的 `id` 一致，例如 `mard` |
| `name` | ✅ | 显示名，例如 `MARD` |
| `pitchMm` | ⭕ | 该品牌豆子的标称中心间距（毫米）。**留 `null` 表示未确认**，此时屏幕↔物理对齐完全由「标尺校准」决定。确认型号后再填数值 |
| `source` | ⭕ | 数据来源说明，建议写清出处与抄录日期，方便日后核对 |
| `colors` | ✅ | 色号数组。**允许为空数组**，表示"尚未填写" |

### `colors` 里每一项

| 字段 | 必填 | 说明 |
|---|---|---|
| `code` | ✅ | 色号，**同一文件内必须唯一**，例如 `A01` |
| `hex` | ✅ | **必须是 `#RRGGBB` 六位写法**（不接受 3 位缩写、不接受 8 位带透明度） |
| `name` | ⭕ | 色名 |
| `series` | ⭕ | 系列/分组，用于排序与分组显示 |

### 校验规则（违反会抛出带路径的错误）

1. `schemaVersion` 缺失、非整数、或不是 `1` → 拒绝加载。
2. `id` / `name` 缺失或为空字符串 → 拒绝。
3. `colors` 缺失或不是数组 → 拒绝。
4. 每个元素的 `hex` 必须是 `#` + 6 位十六进制（大小写都收，内部统一转大写）。
5. `code` 缺失/为空/重复 → 拒绝，并指出与哪一项重复，例如：
   `数据格式错误 [colors[7].code]: 色号 "A01" 与 colors[0] 重复`
6. `pitchMm` 必须为正数或 `null`；填 `0` 或负数会被拒绝。

### ⚠️ 关于"空色卡"

`colors: []` 是**合法**的，加载后 `Palette.isEmpty == true`。
此时**颜色量化功能必须被禁用**——这是刻意的设计：宁可提示"请先填写色卡"，
也不能让 App 用猜测的颜色生成图纸。

---

## 2. 色卡清单 `assets/palettes/index.json`

Flutter **无法在运行时枚举资源目录**，所以必须有一份清单告诉 App 有哪些色卡：

```json
{
  "schemaVersion": 1,
  "palettes": [
    { "id": "mard", "name": "MARD", "asset": "assets/palettes/mard.json" }
  ]
}
```

新增品牌的步骤：
1. 复制一份空的 `<id>.json` 到 `assets/palettes/`；
2. 填好 `id` / `name` / `colors`；
3. 在 `index.json` 的 `palettes` 数组里加一条记录（`id` 要与文件内的 `id` 一致）。

> 单个色卡文件写错**不会**让整个 App 打不开：`PaletteRepository.loadAll()` 会跳过出错的
> 那一个并通过 `onError` 回调上报，其余色卡正常可用。

---

## 3. 测试夹具色卡 `assets/palettes/test_fixture.json`

开发与单测需要一个**非空**色卡，所以有一个合成夹具（`T01`–`T08`）。
它的 `name` 与 `_warning` 字段都明确标注了「**非真实色号**」。

**严禁**把它当作任何品牌的真实色号使用，也严禁在正式 UI 上把它显示成真实色卡。

---

## 4. 板规格 `assets/boards/boards.json`

```json
{
  "schemaVersion": 1,
  "boards": [
    { "id": "square_29", "name": "29 × 29 标准方板", "rows": 29, "cols": 29, "pitchMm": null }
  ]
}
```

| 字段 | 必填 | 说明 |
|---|---|---|
| `id` | ✅ | 规格标识 |
| `name` | ✅ | 显示名 |
| `rows` / `cols` | ✅ | 行数/列数，必须为正整数 |
| `pitchMm` | ⭕ | 标称间距（毫米），留 `null` 表示未确认 |

> 目前只放了 `29 × 29` 与 `52 × 52` 两个预设（你没确认过的尺寸我没有编）。
> 需要别的尺寸，直接在这里加一条即可。
