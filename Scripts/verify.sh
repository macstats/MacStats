#!/usr/bin/env bash
# MacStats 一条命令验证入口：工具链探测 → debug 构建 → bench 冒烟 → 可选启动校验。
#
# 用法：
#   bash Scripts/verify.sh                              # 完整验证
#   bash Scripts/verify.sh --skip-app                   # 跳过启动校验（等价 VERIFY_SKIP_LAUNCH=1）
#   VERIFY_BENCH_ITERATIONS=50 bash Scripts/verify.sh   # 改 bench 冒烟迭代数（默认 20）
#
# 步骤：
#   [0/4] 工具链探测：用 @State 探针确认 SwiftUI 宏（SwiftUIMacros）可编译
#   [1/4] bash Scripts/build.sh debug
#   [2/4] bash Scripts/bench.sh 20（内部会再跑一次 debug 构建）
#   [3/4] ./script/build_and_run.sh --verify（启动后 2s 检查进程存活；通过后 pkill -x MacStats 清理）
#
# 退出码：
#   0 = 工具链探测 + 构建 + 冒烟通过，且启动校验通过或 SKIP
#   1 = 工具链探测失败 / 构建失败 / 冒烟失败 / GUI 会话内启动校验失败
#   2 = 参数错误
#
# SKIP 语义（只作用于第 3 步启动校验，终局汇总会写明“未校验启动”；
# 工具链与构建失败一律非零退出，不做 SKIP 掩盖）：
#   - --skip-app 或 VERIFY_SKIP_LAUNCH=1：显式跳过，退出码仍为 0
#   - launchctl managername 不是 Aqua（CI / SSH 等无 GUI 会话）：自动跳过并打印原因，退出码仍为 0
set -euo pipefail

usage() {
    echo "用法: bash Scripts/verify.sh [--skip-app]" >&2
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="MacStats"
BENCH_ITERATIONS="${VERIFY_BENCH_ITERATIONS:-20}"
SKIP_LAUNCH="${VERIFY_SKIP_LAUNCH:-0}"
LAUNCH_STATUS="UNKNOWN"

for arg in "$@"; do
    case "$arg" in
        --skip-app) SKIP_LAUNCH=1 ;;
        -h|--help) usage; exit 0 ;;
        *) usage; exit 2 ;;
    esac
done

LOG_DIR="$(mktemp -d "${TMPDIR:-/tmp}/macstats-verify.XXXXXX")"
PROBE_LOG="$LOG_DIR/toolchain-probe.log"
BUILD_LOG="$LOG_DIR/build.log"

TOTAL_START=$SECONDS
LAUNCHED=0

cleanup() {
    status=$?
    if [ "$LAUNCHED" = "1" ]; then
        pkill -x "$APP_NAME" >/dev/null 2>&1 || true
    fi
    rm -rf "$LOG_DIR"
    exit "$status"
}
trap cleanup EXIT

echo "MacStats verify — $(date '+%Y-%m-%d %H:%M:%S')"
echo "repo: ${ROOT_DIR}"

echo
echo "==> [0/4] 工具链探测：SwiftUI 能否编译（CLT-only 亦可）"
SDK_PATH="$(xcrun --show-sdk-path 2>/dev/null || true)"
if printf '%s\n' \
    'import SwiftUI' \
    'struct VerifyProbe: View { var body: some View { Text("probe") } }' \
    | swiftc -sdk "${SDK_PATH}" -typecheck - >"${PROBE_LOG}" 2>&1; then
    echo "    [0/4] OK：SwiftUI 可编译（sdk: ${SDK_PATH}）"
else
    echo "    [0/4] FAILED：当前工具链编译不了 SwiftUI" >&2
    echo "    xcode-select -p = $(xcode-select -p 2>/dev/null || echo 未知)" >&2
    echo "    sdk = ${SDK_PATH:-未知}" >&2
    echo "    探针错误（首条）：" >&2
    grep -m1 'error:' "${PROBE_LOG}" >&2 || true
    echo "    真实原因：工具链不完整（缺 SDK 或 SwiftUI 模块）；安装 Xcode Command Line Tools" >&2
    echo "    （xcode-select --install）后重跑。" >&2
    echo "    注意：本项目不能用 @State 等 SwiftUI 宏（macOS 26+ SDK 把它们实现为外部宏，插件只在" >&2
    echo "    完整 Xcode 里），UI 状态请用 @StateObject/@ObservedObject/Binding。" >&2
    echo "    环境不可编译不算通过，本脚本以非零退出码结束；纯逻辑编译校验可用 swift build --target MacStatsCore。" >&2
    exit 1
fi

echo
echo "==> [1/4] debug 构建：bash Scripts/build.sh debug"
STEP_START=$SECONDS
if bash Scripts/build.sh debug 2>&1 | tee "${BUILD_LOG}"; then
    echo "    [1/4] OK（$((SECONDS - STEP_START))s）"
else
    rc="${PIPESTATUS[0]}"
    echo "    [1/4] FAILED（exit=${rc}，$((SECONDS - STEP_START))s）" >&2
    grep -m1 'error:' "${BUILD_LOG}" >&2 || true
    exit 1
fi

echo
echo "==> [2/4] bench 冒烟：bash Scripts/bench.sh ${BENCH_ITERATIONS}"
STEP_START=$SECONDS
if bash Scripts/bench.sh "${BENCH_ITERATIONS}"; then
    echo "    [2/4] OK（$((SECONDS - STEP_START))s）"
else
    rc=$?
    echo "    [2/4] FAILED（exit=${rc}，$((SECONDS - STEP_START))s）" >&2
    exit 1
fi

echo
echo "==> [3/4] 启动校验：./script/build_and_run.sh --verify"
STEP_START=$SECONDS
if [ "${SKIP_LAUNCH}" = "1" ]; then
    LAUNCH_STATUS="SKIP（未校验启动：--skip-app / VERIFY_SKIP_LAUNCH=1）"
    echo "    SKIP：已显式跳过启动校验；本次未校验启动。"
else
    GUI_DOMAIN="$(launchctl managername 2>/dev/null || true)"
    if [ "${GUI_DOMAIN}" != "Aqua" ]; then
        LAUNCH_STATUS="SKIP（未校验启动：非 Aqua GUI 会话）"
        echo "    SKIP：非 Aqua GUI 会话（launchctl managername=${GUI_DOMAIN:-未知}），菜单栏 App 无法在此环境启动；本次未校验启动。"
    else
        LAUNCHED=1
        if ./script/build_and_run.sh --verify; then
            pkill -x "${APP_NAME}" >/dev/null 2>&1 || true
            LAUNCHED=0
            LAUNCH_STATUS="OK"
            echo "    [3/4] OK：进程存活校验通过，已清理本次启动的 ${APP_NAME}（$((SECONDS - STEP_START))s）"
        else
            rc=$?
            echo "    [3/4] FAILED（exit=${rc}，$((SECONDS - STEP_START))s）" >&2
            exit 1
        fi
    fi
fi

echo
echo "==> verify 完成：工具链探测 OK + 构建 OK + bench(${BENCH_ITERATIONS}) OK + 启动校验 ${LAUNCH_STATUS}"
echo "    总用时 $((SECONDS - TOTAL_START))s"
