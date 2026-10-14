# 第三方数据与致谢

本项目自身代码以 MIT 许可证发布（见 [LICENSE](LICENSE)）。但它**内置了第三方色卡数据**，
按 MIT 的要求在此保留其版权声明。

---

## 1. MARD 色卡数据（`assets/palettes/mard.json`、`assets/palettes/mard291.json`）

- 来源仓库：**HansBug/pindou-color-data** — https://github.com/HansBug/pindou-color-data
- 采用文件：`mard-221-alfonse-doudou/colors.json`（221 色）、`mard-291-github/colors.json`（291 色）
- 许可证：**MIT License, Copyright (c) 2026 HansBug**

该仓库自述：它交叉验证了 xiaoana、Zippland/perler-beads、PinDou colorSystemMapping、
get-colors-from-beans 等公开来源，并对上游的重复色号 / 缺失色号 / 不可辨认色号做了
显式标注（不猜测、不套用相近色号）。

### 已知分歧（请以实物色卡为准）

该仓库的 `mard-221-alfonse-doudou` 与 `mard-221-github` 两个来源，**221 个色号集合完全一致，
但有 77 个 HEX 不同**（144 个一致）。本项目采用其 README 推荐的 `alfonse-doudou` 版。

另外，来源数据**只提供色号与 HEX，不提供色名**，因此本项目的色卡文件里没有 `name` 字段
（不编造色名）。

### 上游许可证全文

```
MIT License

Copyright (c) 2026 HansBug

Permission is hereby granted, free of charge, to any person obtaining a copy
of this data and associated documentation files (the "Data"), to deal
in the Data without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Data, and to permit persons to whom the Data is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Data.

THE DATA IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE DATA OR THE USE OR OTHER DEALINGS IN THE DATA.
```

---

## 2. 第三方依赖

Flutter / Dart 依赖及其许可证见 `pubspec.yaml` 与各自包的仓库。主要的几个：

| 包 | 用途 | 许可证 |
|---|---|---|
| `flutter_riverpod` | 状态管理 | MIT |
| `image` | 图片解码 / 缩放 / 像素操作 | MIT |
| `image_picker` | 相册选图 | Apache-2.0 |
| `path_provider` | 应用目录 | BSD-3-Clause |

---

## 3. 商标说明

「MARD」「Perler」「Hama」「Artkal」等为各自品牌所有。本项目与这些品牌**无任何关联**，
不使用其商标作为项目名称；色卡数据仅用于帮助使用者把图片量化到自己手上的豆子色号。
