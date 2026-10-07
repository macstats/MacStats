# AGENTS.md — mac-stats（本仓库内 agent 的工作约定）

MacStats 是一个 macOS 菜单栏系统监控 App：纯 Swift、零第三方依赖，`Package.swift`
只做包描述，真正的构建链是手写 `swiftc` 脚本 `Scripts/build.sh`。下面所有命令都在
仓库根目录执行。

## 常用命令

```bash
bash Scripts/build.sh debug          # 快速 debug 构建，产物 .build/debug/MacStats
bash Scripts/build.sh release        # 通用二进制 release（arm64 + x86_64）
./script/build_and_run.sh            # kill → 构建 → 以真实 .app 启动（dist/MacStats.app）
./script/build_and_run.sh --verify   # 启动 2s 后检查进程存活，失败非零退出
bash Scripts/verify.sh               # ★ 一条命令验证：宏探测 → debug 构建 → bench 冒烟 → 启动校验
bash Scripts/verify.sh --skip-app    # 跳过启动校验（显式 SKIP 且退出码 0；工具链/构建失败仍非零）
bash Scripts/bench.sh 200            # 采样微基准（内部会先跑一次 debug 构建）
swift build --target MacStatsCore    # CLT-only 也能跑的纯逻辑编译校验（不碰 SwiftUI 宏）
.build/debug/MacStats --benchmark 200
.build/debug/MacStats --snapshot /tmp/macstats-snapshot.png         # 渲染弹层为 PNG
.build/debug/MacStats --snapshot /tmp/macstats-snapshot-dark.png dark
```

`Scripts/verify.sh` 的语义：非交互、幂等。[0/4] 用 `@State` 探针确认 SwiftUI 宏可编译，
失败即退出码 1（环境不可编译不算通过，不做 SKIP 掩盖）；[1/4] debug 构建、[2/4] bench 冒烟；
[3/4] 启动校验在 `--skip-app`、`VERIFY_SKIP_LAUNCH=1` 或非 Aqua GUI 会话（CI / SSH）时打印
SKIP 原因并保持退出码 0，汇总行写明"未校验启动"，校验通过后会 `pkill -x MacStats` 清掉本次
启动的进程。需要重新生成 README 截图时，把 `--snapshot` 的路径换成 `assets/screenshot.png`
（会覆盖仓库里的图片，注意别误提交）。

## 硬性约束

- **零外部依赖**：只用 Apple 系统框架（AppKit、SwiftUI、IOKit、Combine、CoreWLAN、
  CoreLocation、ServiceManagement 等）。不加第三方包、不依赖 brew、不联网下载；新代码
  必须能被 `Scripts/build.sh` 直接编译。
- **构建环境**：`Scripts/build.sh` / `Scripts/bench.sh` / `Scripts/verify.sh` 在只装 Xcode
  Command Line Tools 的机器上就能跑通（本机即如此）。两条红线：
  1. **不要用 `@State`**（以及 `#Preview`、`@Entry` 等）——macOS 26+ SDK 把它们实现成外部宏，
     插件只随完整 Xcode 分发，CLT-only 编译必然失败；UI 状态用 `@StateObject` /
     `@ObservedObject` / `Binding` / `@Environment`（这些仍是普通 property wrapper）。
  2. `swift test` 需要完整 Xcode 的 `XCTest.framework`，CLT-only 下用
     `bash Tests/run-tests.sh`（Swift Testing + 插件路径）替代。
- **快照调试**：`MACSTATS_POPOVER_HEIGHT=1700 .build/debug/MacStats --snapshot /tmp/full.png`
  可以渲染出完整高度（默认 620 只截到折叠线以上），用于检查下方面板。
- **性能护栏**：任何改动后跑 `bash Scripts/bench.sh 200`，采样 pass 的 avg/p95 必须与
  `docs/performance.md` 记录保持同一数量级（v2.0 基线：refresh avg 0.049 ms、
  p95 0.053 ms、最差 0.074 ms）。数量级偏差视为性能回退，先用 `--benchmark` 的
  per-monitor 明细归因再交付。
- **Git / 发布纪律**：未经明确要求不 commit、不 push、不改部署配置
  （`.github/**`、打包/签名/发布脚本）。
- 不做任务之外的重构：`Scripts/bundle.sh`、`Scripts/dmg.sh`、`.github/**`、`docs/**`
  保持只读，除非任务点名。

## 代码布局与设计语言

- `Sources/MacStats/`：`main.swift`（入口 + `--benchmark`/`--snapshot`）、`App/`（AppDelegate、
  状态栏控制器）、`Monitors/`（各子系统采样）、`Models/`、`ViewModels/`、`Views/`
  （含 `Components/`）、`Design/`（调色板/字体 token）、`Preferences/`、`Support/`
  （Benchmark、Snapshot 等）。
- 视觉规范唯一来源是 `docs/design-spec.md`（"Precision Instrument"：单一焦点面板、封闭
  调色板、tabular 数字）；性能方法与数据在 `docs/performance.md`。改 UI 或采样前先读这两份。
- 菜单栏 App 以 `.accessory` 运行（无 Dock 图标、无主窗口），这是刻意行为，不是启动 bug。

## 编排

- 未引入 Orca workspace recipe（orca.yaml）：本 App 只能在 macOS 上构建与运行，云端
  sandbox/VM 型 recipe 无意义，也缺少 provider/scope 等必要输入，故不创建。
