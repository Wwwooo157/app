# 开发环境与踩坑记录

本文件记录**这台机器上已验证过的环境事实**，避免下次重踩。全部来自实测，不是推断。

## 工具链位置（用户级环境变量，已持久化）

| 组件 | 路径 | 版本 |
|---|---|---|
| Flutter SDK | `E:\Flutter_SDK\flutter` | 3.47.7 stable / Dart 3.13.5 |
| JDK | `E:\JDK_AndroidSDK\jdk-17` | OpenJDK 17.0.20.1（`JAVA_HOME`） |
| Android SDK | `E:\JDK_AndroidSDK\Sdk` | platform-tools 37.0.1、platforms;android-36、build-tools 36.0.0 + 37.0.0 |
| Gradle 缓存 | `%USERPROFILE%\.gradle` | Gradle 9.3.1 |

`JAVA_HOME` / `ANDROID_HOME` / `ANDROID_SDK_ROOT` / `FLUTTER_STORAGE_BASE_URL` / `PUB_HOSTED_URL`
均为用户级变量；PATH 追加了 `flutter\bin`、`jdk-17\bin`、`platform-tools`、`cmdline-tools\latest\bin`。

## 网络相关的三个坑（都已解决，别改回去）

1. **`plugins.gradle.org` 不可达**（连接被重置），Flutter 工具链构建会报
   `Plugin [id: 'org.gradle.kotlin.kotlin-dsl', ...] was not found`。
   解决分两层：
   - 全局：`%USERPROFILE%\.gradle\init.d\china-mirrors.gradle` 把阿里云镜像加到
     `pluginManagement`（**删掉该文件即可完全还原**）；
   - 本仓库：`android/settings.gradle.kts` 的 `pluginManagement.repositories` 与
     `android/build.gradle.kts` 的 `allprojects.repositories` 也把阿里云镜像放在最前。
   注意：全局脚本**只**加 `pluginManagement`。Flutter 工具链构建用了
   `RepositoriesMode.FAIL_ON_PROJECT_REPOS`，若在 init 脚本里给项目级加仓库会**弄坏构建**。

2. **`services.gradle.org` 超时**：Gradle 发行包下载不通。
   解决：项目 `android/gradle/wrapper/gradle-wrapper.properties` 的 `distributionUrl`
   指向腾讯镜像 `https://mirrors.cloud.tencent.com/gradle/`（本仓库已改）。

3. **校园网按账号限速 ~1MB/s**（实测 3 路并发不叠加）。手机热点更慢（疑似达量降速）。
   换频段无用（2.4G 与 5.8G 同档）。**有效手段是换国内源**，不是换网络。

## Android 构建的两个坑（重要）

1. **NDK 会被无谓下载 2–3 GB**：Flutter 模板的 `android/app/build.gradle.kts` 里有
   `ndkVersion = flutter.ndkVersion`，AGP 见到它就会去装 NDK。纯 Dart 应用不需要 NDK，
   本仓库已删掉该行（并留了注释说明何时需要加回来）。
   另外 `android/gradle.properties` 里设了 `android.builder.sdkDownload=false`，
   让 AGP **不要**偷偷下载 GB 级组件，缺什么就显式报错、显式安装。

2. **绝不要给 Gradle/Kotlin 构建文件写入 UTF-8 BOM**（本项目已因此浪费两轮构建）：
   Flutter 用**行首锚定的正则文本解析** `build.gradle.kts` 来判断插件声明
   （见 `FlutterPluginUtils.getSubprojectPluginState`）。BOM 会让 `^plugins` 匹配失败，
   于是 Flutter 认为 app 模块没应用 AGP → **跳过自动应用 KGP** →
   `kotlin { compilerOptions { } }` 报 `Unresolved reference 'compilerOptions'`。
   - PowerShell 5.1 的 `Set-Content -Encoding UTF8` **会写 BOM**，禁用；
   - 需要脚本化改这些文件时，用
     `[System.IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($false)))`；
   - 构建脚本里一律用 ASCII 注释。

3. **AGP 9.1.0 钉死 `build-tools;36.0.0`**：只装最新的 37.0.0 会报
   `Failed to find Build Tools revision 36.0.0`。36.0.0 与 37.0.0 都装了。

## 屏幕与板子的物理尺寸（1:1 对齐的硬约束）

实测设备：**OPPO Pad (OPD2101)**，Android 14 / SDK 34，横屏 2560×1600，density 360，
**xdpi 276.462 / ydpi 275.525**（`adb shell dumpsys display` 读出，不是猜的）。

| 换算 | 结果 |
|---|---|
| 屏幕可用物理尺寸 | **235.2 mm × 147.5 mm**（对角线 10.92"） |
| 5mm 豆 1:1 最多显示 | **47 列 × 29 行**（贴满屏幕、零边距的理论上限） |
| 52×52 @5mm 板子 | **260 mm 见方 → 放不下** |
| 29×29 @5mm 板子 | 145 mm 见方 → 刚好放下（纵向仅余 2.5mm） |
| 52×52 @2.6mm(mini) | 135.2 mm 见方 → 宽裕 |

结论：**52×52 的 5mm 板无法整板 1:1 显示**，必须走「分区引导」（按区域逐块对齐、逐块拼），
或改用 mini 豆 / 小板 / 大显示器平放（要装下 260mm 见方，显示器短边需 ≥ 270mm，
普通平板和 15.6" 便携屏都不够，24" 显示器平放约 531×299mm 才够）。

> `pitchMm` 与屏幕尺寸都是确定性数据，改动必须同步
> `test/assets/assets_validation_test.dart` 里的断言。

## S4 真机验证记录（1:1 网格）

### ⭐ 物理 1:1 已用实体尺子验证：正好 50mm

使用者用实体尺子量屏幕上标着「10 格 = 50.0 mm」的标尺，**实测正好 50mm**。
这证明整条换算链在物理世界上是对的：
`dumpsys display` 的 xdpi/ydpi → 逻辑像素/毫米 → 每格 24.19 × 24.11 逻辑像素 → 5mm 真实间距。
**「屏幕当灯板」的核心前提成立**，无需靠缩放凑数；S5 的校准只需做最后的微调能力。

- **平台通道生效**：`MainActivity.kt` 里的 `bead_light_board/display` 真的取到了面板物理 DPI，
  真机界面显示「物理 DPI：276.46 / 275.52　1 格 = 24.19 × 24.11 逻辑像素」。
- 真机 1:1 模式报告「可见窗口 **48 列 × 30 行**（含边缘不完整格）」，与 widget test 中的断言
  逐字一致 —— 测试预测了真机行为。（完整放得下的是 47×29，第 48 列/第 30 行只露出不到 1 像素。）
- 标尺叠加层在左下角画出「10 格 = 50.0 mm（用尺子量这段）」，右侧竖标尺「50.0 mm」。
- 证据截图在 `build/verify/`（该目录被 gitignore，属临时产物）。

### 用 adb 驱动真机测试时的三个坑

1. **屏幕必须醒着**：黑屏时 `screencap` 得到的是全黑图（约 19KB，一看文件大小就知道）。
   ColorOS 上 `settings put system screen_off_timeout` 会被 `WRITE_SETTINGS` 权限拒绝，
   `svc power stayon true` 也未必拦得住息屏 —— 最稳的是每次操作前先
   `adb shell input keyevent KEYCODE_WAKEUP`。
2. **坐标空间**：`input tap X Y` 用的是**当前旋转方向**下的显示坐标
   （横屏就是 2560×1600 空间），不是 `wm size` 报的 1600×2560。
3. **别在用户正在操作平板时注入触摸**：会与用户的手势互相干扰，表现为
   "控件自己变了 / 点击没反应 / 原点莫名偏移"，极难排查。注入前先确认没人在用。

## MARD 真实色卡接入记录（2026-10）

### 数据来源与交叉验证

| 项 | 值 |
|---|---|
| 仓库 | [HansBug/pindou-color-data](https://github.com/HansBug/pindou-color-data)（"拼豆色卡四件套交付目录"） |
| 采用文件 | `mard-221-alfonse-doudou/colors.json` → `mard.json`（221 色）<br>`mard-291-github/colors.json` → `mard291.json`（291 色） |
| 该仓库的方法论 | 交叉验证 xiaoana、Zippland/perler-beads、PinDou colorSystemMapping、get-colors-from-beans 等来源；对上游重复/缺失色号做了修正与标注 |

我自己做的校验（`test/assets/assets_validation_test.dart` + 一次性比对脚本）：

- 两个 221 来源：**色号集合完全一致**（各 0 个独有）；
  **144 个 HEX 一致、77 个不同** —— 与仓库 README 的自述**分毫不差**，说明解析无误。
- 221/291 均为 **0 个非 6 位 HEX、0 个重复色号**，可直接通过本项目 schema。
- 291 是 221 的超集（221 的色号被 291 全部覆盖）。

> ⚠️ **77 个 HEX 有分歧**，且来源数据**没有色名**。本仓库采用其推荐的 alfonse-doudou 版，
> 并把这条写进了 `mard.json` 的 `source` 字段。哪一版更接近实物，只能拿着实物色卡核。

### ⚠️ 网络坑：raw.githubusercontent.com 在本机不可达

`raw.githubusercontent.com` 与 `cdn.jsdelivr.net` 在本机 DNS/连接均失败
（web_fetch 直接报 "resolves to a non-public IP address"）。可用通道：

| 通道 | 结果 |
|---|---|
| `https://gcore.jsdelivr.net/gh/<owner>/<repo>@<branch>/<path>` | ✅ 可用（本次采用） |
| `https://ghproxy.net/https://raw.githubusercontent.com/...` | ✅ 可用（与上者字节数一致，可互相印证） |
| `https://api.github.com/repos/<owner>/<repo>` | ✅ 可用（仓库元数据） |
| `cdn.jsdelivr.net` / `raw.githubusercontent.com` / `raw.gitmirror.com` | ❌ 不可用 |

### ⚠️ PowerShell 取网络的坑

`Invoke-WebRequest` 在这个 PowerShell 里 `.Content` 是**字符串**、不是 byte[]；
我两次误用 `[System.Text.Encoding]::UTF8.GetString($r.Content)` 并把 `WriteAllBytes` 传字符串，
结果把整份 JSON 打进了终端（浪费上下文）。**正确姿势**：
`Invoke-WebRequest -OutFile <path>` 落盘，再用
`Get-Content <path> -Raw -Encoding UTF8 | ConvertFrom-Json` 解析，且**只打印统计摘要**。

### 验证：单测与真机结果逐色号一致

示例图（暖白背景 + 红心）→ 52×52，用 MARD 221 量化：

| 色号 | 单测格数 | 真机格数 |
|---|---:|---:|
| H19 #F2EEE5 | 2045 | 2045 |
| F9 #E0677A | 551 | 551 |
| F19 #BE454A | 39 | 39 |
| E11 / F14 / E15 | 19 / 16 / 15 | 19 / 16 / 15 |

合计 2704 ✓。**两边逐色号一致**，说明流水线在 isolate 里与单测里行为相同。

> 教训：中途真机曾出现"浅色被量化成近黑色"的结果，我一度判定是量化 bug。
> 实际原因是一串**盲点击**把相册选择器打开、选中了用户相册里的一张深色截图。
> **看到与单测不符的真机结果时，先确认输入是什么**，再怀疑代码。


### 真机证据（OPPO Pad）

## S10 真机验证记录（图纸编辑器）

### 真机证据（OPPO Pad）

| 验证项 | 证据 |
|---|---|
| 编辑入口 | 顶部面板末尾的**铅笔图标**（图标而非文字，避免面板再多占一行） |
| 编辑工具栏 | 底部工具栏顶替引导面板：工具[画笔/填充/吸管] 对称[无/左右/上下/四向] 撤销/重做/重来/完成 + T01–T08 色卡 |
| 真实颜色 | 编辑模式下**不再高亮/压暗/闪烁**，显示图纸真实颜色（引导高亮是拼豆时才需要的） |
| 绘制 | 选 T07 后横竖各画一笔，蓝点清晰可见；`撤销` 按钮随即变亮、`重做` 保持灰色 |
| 撤销 | 连点两次撤销，两笔都被撤掉 |
| **编辑跨重启保留** | `am force-stop` 后重启并重新打开项目：蓝色笔画仍在；色号条新增 `T07 剩 14`；总进度 2093 → **2079**（2093−14=2079 分毫不差）；已完成色数 1/2 → **1/3** |

### 交互设计

- **单指绘制、双指平移缩放**（画图类应用的通行手感）。
  实现在 `GridCanvas`：`pointerCount == 1` 走绘制，否则走平移缩放。
- **落笔要画在 `onScaleStart`**：单纯点一下不会触发 `onScaleUpdate`，
  只在 update 里画会导致"点一下没反应"。
- **拖动要插值**：手指快划时两次回调之间可能隔好几格，用 Bresenham 补齐，否则笔画断续。
- **一笔 = 一步撤销**：`beginBatch` / `record` / `endBatch`，全无变化的批不入栈
  （避免"撤销了但什么都没变"）。
- 撤销栈只存**稀疏差异**（哪格从什么色变成什么色），不存整图快照：
  52×52 一次填充最多 2704 个改动，整图快照每步就是 5KB 起。
- **对称绘制**：左右/上下/四向，落在对称轴上会自动去重（29 宽的中轴格只改一次）。
- **重来**（恢复成进入编辑时的样子）本身也是一步可撤销的操作，所以不需要二次确认弹窗。
- 已知限制：**没有"擦成空格子"**。`BeadPattern` 要求每格都有色号，没有"无豆"的概念；
  想支持需要在数据模型里加哨兵值，并同时改渲染/统计/序列化 —— 留作后续。

### ⚠️ 三个测试挖出来的真问题（都已修）

1. **`rootBundle.loadString` 默认缓存 Future，会把色卡"卡死"**。
   缓存下来的 Future 属于创建它的那个 fake-async zone，于是 widget test 里
   **第一个测试能加载色卡、后续测试永远等不到** —— 而且**不报错**，只是色号悄悄
   退化成 `?N`（`colorCodeOf` 的越界兜底把问题藏住了）。
   修法：`loadString(path, cache: false)`；顺带给色卡加载加 3s 超时并把失败显示到界面。
   这个坑在真机上同样可能是隐患（例如热重载后色卡不再更新）。
2. **就地修改不会触发重绘**。`GridPainter.shouldRepaint` 用 `identical(pattern/progress)`
   判断，而图纸与进度都是**就地修改同一个对象** → 比不出变化 → 画布不重绘。
   S6 的整色标记之所以看起来正常，纯属巧合（那时顺带改了 `activeColorIndex`）；
   **逐格标记其实一直不会刷新**。修法：加一个内容版本号 `revision`，内容变化时递增。
3. **编辑模式下不能开高亮/闪烁**。否则编辑时图案被高亮盖住看不清，
   而且闪烁动画会让 `pumpAndSettle` 永远等不到静止（测试直接超时）。

## M5 真机验证记录（项目保存与加载）

### 真机证据（OPPO Pad，未 root，`run-as` 查看私有目录）

| 验证项 | 证据 |
|---|---|
| 保存为新项目 | 网格页点「已导入图纸 52 × 52 · 点此保存」→ 对话框默认名取自图片名（「示例图」）→ 保存 |
| 文件真的落盘 | `app_flutter/projects/p1791965301747383_0.json`，11140 字节 |
| 文件内容可读 | 缩进 JSON：`schemaVersion/id/name/createdAt/updatedAt/paletteId/rows/cols/cells/placed/completedColors`；`cells` 的 base64 长度 7212 = ⌈52×52×2/3⌉×4，`placed` 为 3608 = ⌈52×52/3⌉×4，**与位图字节数分毫不差** |
| 自动保存 | 标记当前色完成后 `updatedAt` 从 `08:08:21` 变为 `08:08:56`，`completedColors` 同步写入 |
| **强杀重启后进度还在** | `am force-stop` 后重启 → 我的图纸显示 **77%（2093/2704）**，正是重启前标记完成的那一色（2093/2704 = 77.4%） |
| 项目列表 | 显示名称、`52 × 52 · 2 色 · 来自 示例图 · 刚刚`、进度条与百分比；有 ⋮ 菜单（重命名/删除） |

### 存储设计

- **每个项目一个 JSON 文件**（`app_flutter/projects/<id>.json`），**不维护索引文件**：
  列表直接从目录扫出来，就少了一份"可能与实际不同步"的状态 —— 索引与实际文件不一致
  是这类实现最经典的 bug 来源。52×52 项目约 11KB，几十个项目也就几百 KB，扫描毫无压力。
- 图纸色号与进度位图用 **base64** 存进 JSON：文件仍可用文本编辑器打开（元数据可读），
  位图部分不直观但另有 `rows/cols/completedColors` 可供人核对。
- 色号索引**显式按小端序**写出，不依赖平台字节序（有单测钉死 `0x1234 → [0x34,0x12]`）。
- **坏文件不致命**：单个项目文件损坏只跳过它并提示，其余照常列出（"文件即数据库"必须有的容错）。
- 位图长度必须等于 `rows × cols`（进度）或 `rows × cols × 2`（图纸），不符即报错 ——
  **宁可明确失败，也不要加载出错位的进度**（那比丢进度更糟）。
- 自动保存 **防抖 800ms**：逐格标记时会连点，每次写文件既慢又费闪存；
  退出页面时再补一次立即保存。

### ⚠️ 两个值得记下的坑

1. **`TextEditingController` 用完立刻 dispose 会崩**。
   `await showDialog(...)` 返回后马上 `controller.dispose()`，
   对话框**退场动画还在用它** → `A TextEditingController was used after being disposed`。
   修法：把输入框做成 `StatefulWidget`（`core/widgets/text_input_dialog.dart`），
   让 controller 的生命周期与对话框完全一致。这是 widget test 抓出来的真 bug。
2. **往已经很挤的顶部面板加控件会撞坏手势测试**。
   加"保存图纸"按钮后，S5 的两个捏合缩放测试开始失败 —— 面板多一行，
   测试的捏合坐标落到了面板上。这提醒了真正的 UX 问题：顶部面板已经遮住约一半屏幕。
   最终改为**复用已有的「已导入图纸」徽章**（点它即保存），一个控件兼两职，面板不再变高。

## M1 真机验证记录（图片导入 → 裁剪 → 像素化 → 量化）

### 真机证据（OPPO Pad）

| 验证项 | 证据 |
|---|---|
| 相册选图 | 点「选择图片」正常唤起系统照片选择器（Android 14 照片选择器，无需存储权限） |
| 取消路径 | 在选择器里按返回，App 不崩、仍停在导入页 |
| 内置示例图 | 「用示例图试试」直接进入裁剪页，全程不碰相册 |
| 自绘裁剪 | 心形示例图显示在取景框内，底部实时显示「选区 480 × 480 像素 → 52 × 52 格，每格约 85 个像素」（480²/2704 = 85.2，吻合） |
| 量化结果 | 生成后色号条为 **T04 剩 2093 + T05 剩 611 = 2704**，正好等于 52×52；总览里能看清红色心形轮廓 |
| 图纸接入网格 | 顶部出现「已导入图纸 52 × 52」徽章，尺寸预设与合成图案**自动置灰**（避免点了没反应） |
| 稳定性 | 全流程无 FATAL / AndroidRuntime 异常 |

> **隐私**：验证过程中系统选择器会列出真实相册内容，我**没有点开任何一张私人照片**，
> 改用「内置示例图」这条路径完成端到端验证。

### 量化算法

- 色彩空间用 **CIE Lab（D65）+ CIE76 欧氏距离**，而不是直接比 RGB：
  RGB 距离与人眼感受不成比例，深色与饱和区尤其明显。
  单测里有一条专门证明这点：#800080 在 [红, 蓝] 色卡里 Lab 判给蓝，而 RGB 距离完全打平。
- 参考值单测：白/黑/红/绿/蓝的 Lab 与标准表一致（红 L=53.24 / a=80.09 / b=67.20 等）。
- 降采样用**面积平均**（不是最近邻）：每格取选区内的平均色，照片缩小时不会出现摩尔纹式的丢格。
- 透明像素按 alpha 合成到**暖白 #E4E2DE**（不是纯白，也不是丢弃），可配置。

### ⚠️ 环境坑：Kotlin 增量编译在 Windows 上偶发失败

加 `image_picker` 后构建报：

```
Execution failed for task ':image_picker_android:compileDebugKotlin'.
> java.lang.Exception: Could not close incremental caches in
  build/image_picker_android/kotlin/compileDebugKotlin/cacheable/caches-jvm/...
```

删缓存、停 Gradle 守护进程都**无效**；`--stacktrace` 里**没有任何文件系统异常**
（没有 AccessDenied / IOException），是编译器自身关闭增量缓存时的故障。

修法（已写进 `android/gradle.properties`）：

```properties
kotlin.incremental=false
kotlin.compiler.execution.strategy=in-process
```

关掉增量编译 + 把编译器放进 Gradle 进程内，避开那条代码路径。代价是增量构建稍慢，但**确定性**。

### 依赖与限制

- 新增依赖：`image ^4.12.0`（解码/裁剪/像素操作）、`image_picker ^1.2.4`（相册）。
- `pub add` 会再次报 "Building with plugins requires symlink support / Developer Mode"
  —— 只影响 **Windows 桌面版**；Android 构建与安装完全正常。
- 选图时用 `maxWidth/maxHeight = 2048` 限制长边：52×52 图纸每格 10 像素也只要 520px，
  2048 足够，却避免了把 5000 万像素原图整张解码（省内存省时间）。

## S7 真机验证记录（护眼 / 沉浸式 / 屏幕常亮）

| 验证项 | 证据 |
|---|---|
| 沉浸式全屏 | 进入网格页后**状态栏（时间/电量）完全消失**，网格从屏幕最顶端铺满（此前第一行点被状态栏压住） |
| 屏幕常亮 | `adb shell dumpsys window` 里本应用窗口标志为 `fl=KEEP_SCREEN_ON ...`，自写平台通道生效（未用任何插件） |
| 护眼面板 | 底部弹出面板：总开关、亮度 85%、暖色 25%、低对比/屏幕常亮/沉浸式三个开关、完成按钮，全部可用 |
| 软件调光 | 把亮度拖低后整屏明显变暗（截图体积从 384KB 降到 266KB，可侧面印证） |
| 低对比模式 | 网格线更暗、点径更小；配色仍无纯白纯黑 |

> ⚠️ **调光与引导的取舍**：软件调光会**同时压暗引导高亮**。
> 拖到很低（如 15%）时整个图案都会变得很淡，反而看不清该往哪放豆。
> 建议亮度留在 70%~85%；若希望我把下限抬高（例如最多只允许调暗 50%），说一声即可改。


## S6 真机验证记录（单色高亮 / 分步引导 / 进度）

| 验证项 | 证据 |
|---|---|
| 进度统计 | 界面显示「总进度 78%（2116/2704 颗 · 已完成 1/5 色）」；2116/2704 = 78.25%，与显示一致 |
| 单色高亮 | 选中 T01 后，图纸边框那一圈（T01）全部亮起为高亮色；其余色压暗 |
| 已完成变灰 | 标记 T05 完成后，占 2116 格的背景色整片变灰，色号块显示 `T05 ✓ 剩 0` |
| 分步自动跳色 | 点「标记当前色完成」后**自动跳到下一个未完成的颜色**（T05 → T01），面板同步显示「当前色 T01 剩 204 颗（共 204 颗）」 |
| 色号条按用量降序 | `T05 2116 / T01 204 / T03 143 / T04 142 / T02 99` |
| 未选色时按钮置灰 | 「标记当前色完成」在未选色时禁用 |

> **进度是内存态，不持久化**（S6 有意如此）：重启后进度归零，等 S9 做项目保存时
> 与图纸一起落库。校准参数则是持久化的（见上）。
>
> ⚠️ 踩坑记录：闪烁用的 `AnimationController` 若一直 `repeat()`，
> `pumpAndSettle` 会**永远等不到静止**（widget test 直接超时）。
> 现在只在"选了色 + 开了闪烁"时才启动动画，既是测试需要，也省电。


## S5 真机验证记录（对齐校准 + 锁定 + 持久化）

全部在 OPPO Pad 上实测通过：

| 验证项 | 证据 |
|---|---|
| 微调按钮 | 连点两次「网格右移（0.5mm）」，校准文件里 `originDx = 4.8374804132149505` ＝ 2 × 0.5mm × 4.83748 px/mm，**分毫不差** |
| 持久化 | 文件落在 `/data/data/com.dsh.beadlightboard/app_flutter/calibration.json`，是可读的缩进 JSON |
| 重启恢复 | 冷启动后界面显示「原点 (4.8, 0.0)」；且点锁定时写回的文件仍保留 4.8375（若没加载成功就会写成 0 —— 这条推理本身就是证明） |
| 锁定 | 锁定状态下点「网格右移」，文件里的 `originDx` **纹丝不动** |
| 四角锚点 | 屏幕四角画出 L 形标记（上方被控制面板遮住属正常） |
| 严格 1:1 指示 | 默认显示「校准：严格 1:1（未做手动缩放）」；一旦捏合缩放会变成告警色的「已手动缩放 ×…，当前不是严格 1:1」 |

> 控制面板覆盖屏幕顶部约 146 逻辑像素，而 1:1 窗口从屏幕 (0,0) 开始，
> 所以实际拼豆时应点「隐藏控件」把整屏让给网格（S7 会做沉浸式与自动隐藏）。

## ⚠️ Windows 开发人员模式未开启（影响面：仅 Windows 桌面版）

`flutter pub add path_provider` 会报：
`Building with plugins requires symlink support. Please enable Developer Mode...`

- **Android 构建不受影响**（已实测 `flutter build apk --debug` 成功，插件正常工作）。
- 受影响的是 **Windows 桌面版**：只要项目里有带原生代码的插件，`flutter build windows` 就会失败。
  要启用：设置 → 系统 → 开发者选项 → 开发人员模式（需管理员权限）。
  如果以后要做"大显示器平放"那套（见上文尺寸测算），需要先开这个。
- 顺带：这次构建自动往 Android SDK 里装了 **CMake 3.22.1**（Flutter 的 native assets 相关）。
  本项目 `android/gradle.properties` 已加 `android.builder.sdkDownload=false`，
  以后缺组件会显式报错，而不是静默下载 GB 级内容。

### 已定的显示策略（使用者已决策）

- **采用「分区/窗口式 1:1」**：屏幕只铺 1:1 的一块窗口（本机理论上限约 47×29 格），
  可平移，用四角锚点把物理板的对应区域对准；逐块拼。同一机制自动兼容 29×29 整板。
- 使用者多数图案为「几十 × 几十格」的中等尺寸，窗口按**图案实际包围盒**定即可，不必死切象限。

### 交互硬约束：板子会盖住整块屏幕 ⚠️

52×52 板（260mm）在**两个方向上都大于**屏幕（235.2 × 147.5mm），
也就是**板子一放上去，用户完全无法触摸屏幕**。因此：

- 所有触摸操作必须发生在**抬起板子的时候**（换区时本来就要挪板子，天然吻合）；
- 更顺的方案是用**平板侧边硬件键（音量键）或蓝牙遥控器**切换区域/色号 ——
  这些按钮在屏幕外，板子挡不住；
- S4/S5 的 UI 必须按"随时触摸不可用"来设计，**不能依赖需要随时点屏幕的交互**。

## PowerShell 脚本的 BOM 规则（与上面第 2 条相反！）

- **Gradle/Kotlin 构建文件**：必须**无 BOM** —— Flutter 用行首锚定正则文本解析它们。
- **Windows PowerShell 5.1 的 `.ps1` 脚本**：含中文时**必须带 UTF-8 BOM**，
  否则 PS 5.1 按 GBK 解码，中文变乱码、并可能吃掉引号导致整脚本解析失败（实测踩过）。
- 最省事的规则：**交给 PowerShell 执行的脚本一律只用 ASCII 内容**，
  中文放到命令行的 `-Command` 里（命令行走 UTF-16，不受文件编码影响）。

## 常用命令

```powershell
# 静态分析 + 测试（本项目每次改动都要跑）
flutter analyze
flutter test

# 真机（Android 平板，先开 USB 调试）
flutter devices
flutter run -d <device-id>

# 出调试包（自己用，release 也用 debug 签名，无需 keystore）
flutter build apk --debug
flutter build apk --release
```

## 包名与发布

- 项目名 `bead_light_board`，Android 包名 **`com.dsh.beadlightboard`**。
- **仅供个人使用，不上架**：release 构建沿用 debug 签名，不需要 keystore；
  不需要 Play 商店元数据。
- iOS/iPad 无法在这台 Windows 机器上构建（需要 macOS + Xcode）。
