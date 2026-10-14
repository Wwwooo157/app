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
