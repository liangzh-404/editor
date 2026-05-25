# Editor Performance Optimization Goal Prompt

Use this prompt as the full `/goal` objective for a data-backed performance pass on the native Editor app.

```text
你现在是资深 Apple UI 性能工程师、SwiftUI 架构师、TextKit 编辑器体验优化专家。

工作目录：/Users/liangzhang/.codex/worktrees/bd57/editor

目标：基于当前 Editor 的真实数据库做一轮可度量的性能优化。功能不能裁剪，UI/UX 不能降级；如果用户表面看不出来，底层实现、调度、缓存、状态边界和观测方式都可以调整。不要做泛泛建议。必须先建立真实 baseline，再补齐观测，再基于证据小步优化。

## 0. Project Rules

先阅读并遵守 AGENTS.md。尤其是：
- UI、focus、cursor、scroll、shortcut-input、keyboard、performance 类问题，必须先复现或让问题可观测。
- 如果复现困难或可能原因很多，先加最小、高信号、可关闭 instrumentation。
- 一次只修一个主要瓶颈。
- 不能说 fixed，除非已经跑过相关验证，或明确说明无法验证的原因。
- macOS UI automation 如果遇到 TCC/privacy prompt，先识别 service/client，不要编辑 TCC.db，也不要谎称 UI 场景通过。

## 1. Product And Codebase Anchors

这是一个 native-first 本地优先编辑器：
- targets: EditorMac, EditorIOS, EditorTests, EditorMacUITests, EditorIOSUITests
- macOS: SwiftUI 三栏 shell
- iOS: compact 三层导航，library/list/editor
- editor: NativeTextBlockEditor，基于 UITextView/NSTextView 原生输入
- state: WorkspaceViewModel 是主要 ObservableObject，EditorSession 管 focus/selection/draft
- data: SQLite block/page store, SearchRepository, BacklinkRepository, SyncRepository/CloudKit, page versions, attachments/OCR
- observability: EditorLog, transaction duration logs, EditorCanvasScrollMetrics, scripts/perf_baseline.sh
- UI test seams: EDITOR_UI_TEST_RESET_STORE, EDITOR_UI_TEST_LARGE_PAGE_BLOCK_COUNT, EDITOR_APP_SUPPORT_DIR

当前要重点审计的热路径：
- 输入：NativeTextBlockEditor.textViewDidChange -> EditorSession.updateDraft -> onTextChange -> WorkspaceViewModel.updateBlockText -> PageRepository.updateBlock -> SyncRepository.enqueue -> refreshDerivedState(search/backlinks/conflicts)
- 光标/选择：UITextView/NSTextView selectedRange -> EditorSession.updateSelection -> SwiftUI row/chrome state
- 打开页面：WorkspaceViewModel.selectPage -> hydrateBlocksForPageIfNeeded / deferred hydration -> EditorCanvasView first editable block
- 大文档滚动：EditorCanvasView LazyVStack block appear/disappear -> EditorCanvasScrollMetrics -> preference/geometry changes
- 启动/激活：EditorShellView scenePhase/onAppear -> WorkspaceViewModel.syncAfterActivation -> CloudKit/account/sync paths

## 2. Hard Data Requirement

性能实验必须基于当前真实 Editor 数据库，而不是只用 synthetic fixture。

先定位当前 app 使用的 SQLite：
- 从代码读取 AppEnvironment.databasePath() 和 applicationSupportRoot() 的真实规则。
- 不要假设默认路径一定正确；如有必要，通过运行 app、日志、环境变量或文件系统 readback 确认真实 DB。
- 默认形态通常是 applicationSupportRoot()/Editor/editor.sqlite，但 sandbox/container/EDITOR_APP_SUPPORT_DIR 可能改变实际位置。

所有写入实验必须复制数据库到隔离目录：
- 禁止直接写用户真实数据库。
- 实验库放在 /tmp 或 repo ignored 的 perf workspace。
- 每次运行前打印 DB path，并检查它不是生产路径。
- 通过 EDITOR_APP_SUPPORT_DIR 指向复制件运行 app/tests。
- 复制附件目录和必要 sidecar 文件；如果附件不可复制，用 lightweight placeholder 保持引用有效，并记录限制。
- 加密页只统计结构和规模，不泄露内容，不尝试绕过安全边界。

必须构造并报告三组数据：

1. Current
- 当前真实 editor.sqlite 的完整隔离副本。
- 输出真实规模：workspace/page/block/tag/pageTag/attachment/search_index/sync_changes/page_versions/runtime_diagnostics 数量。
- 输出分布：每页 block 数 p50/p95/p99/max，最大页面 ID/标题摘要，最长 block 长度，代码块/表格/任务/附件/图片/加密页/归档页数量。
- 所有性能结论必须先基于 Current 副本跑一遍。

2. Current x5
- 基于真实库复制/放大 5 倍。
- 保持真实数据结构比例：pages、blocks、tags、pageTags、attachments、pageParentLinks、diaryPages、archive/favorite/encrypted flags。
- ID 必须重写，引用关系必须一致。
- 重建或修复 search_index，使 search 结果代表放大后的库。
- sync/page version/backlink/attachment 相关表要保持合理压力形态；如果某类数据无法安全复制，记录原因和替代压力模型。

3. Current x10
- 同 Current x5，但放大 10 倍。
- 用于找出 first failure point：启动、列表、搜索、打开页面、滚动、输入的第一个明显退化点。
- 如果 x10 超过合理产品目标，也要记录崩点，不能跳过。

没有 Current / Current x5 / Current x10 三组 before/after，就不能宣称性能优化完成。

## 3. Performance Budget

按平台和数据集分别统计 p50/p95/p99。

输入 / 打字：
- key input 到本地字符可见：p95 <= 16ms，p99 <= 50ms。
- SQLite write、search index、sync enqueue、page version、backlink/conflict refresh 不能阻塞字符显示。
- 中文 IME composition 必须独立测试；composition 期间不能触发 block command、全量 style、焦点抖动或错误 commit。

Cursor / selection：
- cursor move 到 paint：p95 <= 16ms，p99 <= 50ms。
- selection drag 不能被 SwiftUI row/chrome 重建打断。
- 光标定位不能触发整页昂贵派生计算。

滚动：
- 60Hz 设备接近 60fps；单帧主线程预算 16.7ms。
- 120Hz 设备尽量接近 120fps；单帧预算 8.3ms。
- 大文档滚动时，visible block churn、preference changes、geometry changes 可控。
- 图片/附件/动态高度不能造成明显 scroll jump。

左栏 / 中栏：
- macOS 左栏 selected/pressed state <= 50ms 出现。
- 中栏 page list 首屏 p95 <= 100ms，p99 <= 200ms。
- selected page 改变不能导致无关 row 大面积重建。

右栏 editor open：
- 首个可编辑 block p95 <= 150ms，p99 <= 300ms。
- 大页面可以 deferred hydration，但首屏必须稳定、可理解、可继续加载。
- 打开右栏不能让左栏和中栏大面积无意义刷新。

iOS：
- cold launch 直接进入可编辑页，首屏 text view <= 300ms 目标。
- library/list/editor push/back 动画不明显掉帧。
- keyboard show 后 cursor 可见，焦点不丢，布局不跳。
- 返回列表保留 scroll position 和 selected item。

启动 / 激活：
- app activation 不允许 CloudKit/account/sync 阻塞主线程。
- 如果 sample 显示 semaphore/wait/network/account status 在 main thread，优先处理为 P0。

## 4. Required Interaction Model

不要一上来改生产代码。先输出 Current Interaction Model：

状态流：
- Left collection selected state 如何影响 middle page list。
- Middle selected page 如何影响 right editor。
- Right editor 输入如何反向影响 page title/list preview/search/sync/version/backlinks/conflicts。
- WorkspaceViewModel 哪些 @Published 是全局热状态。
- EditorSession 哪些状态应保持局部。
- 哪些状态更新会导致跨栏 SwiftUI invalidation。

渲染流：
- 点击 sidebar collection 后哪些 view/body/updateUIView 可能运行。
- 点击 page row 后哪些 view/body/updateUIView 可能运行。
- 右栏输入一个字符后 NativeTextBlockEditor、EditorCanvasView、PageListView、WorkspaceSidebar 是否被牵连。
- cursor move / selection change 是否只影响当前 block。
- scroll 时哪些 onPreferenceChange/onScrollGeometryChange/onAppear/onDisappear 会触发。

数据流：
- list/filter/sort/group 在哪里执行。
- block hydration 在哪里执行，是否同步。
- search index、backlinks、external links、conflicts 在哪里刷新。
- autosave/persistence/sync enqueue/page version 在哪里触发。
- 是否有同步阻塞 UI 的 DB/CloudKit/IO 数据流。

风险地图表格：
- 场景
- 触发动作
- 可能阻塞点
- 影响组件/状态
- 可观测指标
- 数据集 Current/x5/x10
- 优先级
- 预计收益

## 5. Instrumentation Requirements

加入可开关 performance instrumentation，不污染生产逻辑。

控制方式：
- DEBUG 环境变量或 UserDefaults/defaults flag。
- Release 可选低开销 signpost，但默认关闭。
- instrumentation 必须有单点开关和清晰命名，例如 EDITOR_PERFORMANCE_TRACE_ENABLED。

优先使用：
- OSLog Logger categories
- os_signpost intervals/points
- existing EditorLog categories where appropriate
- XCTest attachments / xcresult parsing for UI tests
- RuntimeDiagnosticRepository only用于低频慢事件，不要在输入热路径每字符写 DB

需要捕获事件：

App / Data:
- app_launch_start
- app_first_window_visible
- app_first_editable_block_visible
- app_activation_start
- app_activation_ready
- db_current_profile_start
- db_current_profile_done
- db_scale_copy_start
- db_scale_copy_done

Sidebar / list:
- sidebar_collection_click_start
- sidebar_selected_painted
- page_list_request_start
- page_list_first_row_painted
- page_list_first_screen_painted
- page_list_full_ready
- page_row_click_start
- page_row_selected_painted

Editor open / hydration:
- editor_open_start
- block_hydration_start
- block_hydration_done
- editor_first_block_painted
- editor_ready
- editor_deferred_hydration_start
- editor_deferred_hydration_done

Input / cursor:
- key_input_start
- native_text_did_change
- draft_updated
- character_painted
- cursor_move_start
- cursor_painted
- selection_start
- selection_painted
- ime_composition_start
- ime_composition_update
- ime_composition_commit

Derived work:
- repository_block_update_start
- repository_block_update_done
- page_version_capture_start
- page_version_capture_done
- sync_enqueue_start
- sync_enqueue_done
- search_index_update_start
- search_index_update_done
- search_query_start
- search_query_done
- backlinks_refresh_start
- backlinks_refresh_done
- conflicts_refresh_start
- conflicts_refresh_done
- refresh_derived_state_start
- refresh_derived_state_done

Scroll:
- editor_scroll_start
- editor_scroll_visible_window
- editor_scroll_frame_slow
- editor_scroll_end
- block_row_appear
- block_row_disappear
- scroll_jump_detected

iOS:
- mobile_route_push_start
- mobile_route_push_painted
- mobile_route_back_start
- mobile_route_back_painted
- keyboard_show_start
- keyboard_layout_stable
- mobile_editor_focus_start
- mobile_editor_cursor_visible
- mobile_scroll_restore_start
- mobile_scroll_restore_done

每个事件尽量记录：
- timestamp, duration
- platform: macOS/iOS
- route/page/view
- viewport/window size
- refresh rate if available
- dataset: Current / Current x5 / Current x10
- DB path hash or label, never sensitive content
- page count, block count, current page block count, attachment count
- largest page block count
- hydration mode
- visible block count/churn
- keyboard visible
- IME composing
- main-thread marker when available
- signpost interaction ID

## 6. Baseline Execution

Step 1: profile current DB.
- 输出 DB path 和安全检查结果。
- 输出 schema/table counts 和分布。
- 记录 Current 数据集 summary。

Step 2: create Current x5 / x10 isolated copies.
- 写脚本或一次性工具时，必须可重复运行。
- 放大后用 SQLite integrity_check。
- 验证引用完整性：blocks.page_id、page_tags、attachments、page_parent_links、diary_pages、sync/page_versions。
- 重建 search index 或证明现有 index 与放大数据一致。

Step 3: run baseline without production optimization.
- scripts/perf_baseline.sh
- focused EditorTests for repository/search/scroll metrics
- macOS UI paths through EditorMacUITests where automation permission allows
- iOS Simulator or physical device paths through EditorIOSUITests where available
- 如果 UI automation 被 TCC/privacy prompt 阻挡，报告 exact service/client，并改用 build/unit/log/sample 作为有限验证，不要声称 UI 场景通过。

Step 4: capture top 10 slow interactions.
- 按 Current、x5、x10 分开列。
- 标注是否来自 input/cursor/scroll/open/list/search/sync。

## 7. User Paths To Cover

macOS:
1. 启动并进入当前页。
2. 点击左栏 collection/tag/folder。
3. 中栏 page list 首屏出现。
4. 滚动中栏长列表。
5. 点击中栏 item 切换右栏 editor。
6. 打开最大页面。
7. 最大页面滚动到远处 block。
8. 右栏连续输入英文和中文。
9. 移动 cursor / selection。
10. 编辑标题，观察中栏 title/preview 更新是否节制。
11. 搜索 query。
12. 触发 sync enqueue，确认 UI 不被阻塞。

iOS:
1. cold launch 进入可编辑页。
2. editor -> list -> library -> list -> editor push/back。
3. 键盘弹出后 cursor 可见。
4. 长文档中连续输入中文。
5. 长文档滚动后返回列表再进入，检查 scroll position / selected item。
6. page actions / toolbar 不因输入或滚动频繁重建。

## 8. Diagnosis Loop

按照下面循环工作，不能跳步：

1. Baseline
- 不改生产逻辑。
- 记录 Current / x5 / x10 的 p50/p95/p99。
- 找 top 10 slow interactions。

2. Hypothesis
对每个慢场景提出可以被验证的假设，例如：
- WorkspaceViewModel @Published 粒度太大导致跨栏 invalidation。
- NativeTextBlockEditor 每字符同步 style/highlight/height measurement 过重。
- updateBlockText 每字符同步 DB write、page version、sync enqueue、search/backlink/conflict refresh。
- page title 每字符导致 page list 重算。
- visibleDocumentPages / tag lookup / diary lookup 每次 body 计算重复扫描大数组。
- large page hydration 同步 load blocks。
- scroll preference/geometry changes 太频繁。
- CloudKit/account/sync 在 activation 主线程阻塞。
- attachments/images 未预留尺寸导致 scroll jump。

3. Profiling
用 signpost/log/test/sample/Instruments 证明或排除假设。
不能凭感觉改。

4. Small Patch
每次只处理一个主要瓶颈。可选方向：
- 状态局部化或拆分 ObservableObject 热状态。
- 输入先本地回显，persistence/search/sync/version 降优先级或 coalesce。
- search/backlink/conflict refresh 增量化、debounce 或后台化。
- tag/page/diary lookup cache。
- page list row props 稳定化。
- deferred hydration / chunked render。
- height measurement cache。
- scroll 中暂停非关键计算。
- CloudKit/account/status 移出 startup/activation critical path。

5. Before / After
每个 patch 后输出：
- 改了什么
- 为什么
- before metrics
- after metrics
- 是否达到预算
- UX/正确性回归检查
- 仍然最慢的场景

## 9. Correctness Guardrails

不允许为了性能破坏：
- IME composition
- cursor position
- selection
- undo/redo
- paste / multiline split
- markdown formatting
- block create/delete/merge/split
- task/toggle/list alignment
- autosave/persistence correctness
- search/backlink correctness
- CloudKit sync correctness
- encrypted page security
- attachments/OCR references

任何输入链路优化都必须至少回归：
- NativeTextBlockEditorTests 相关 focused tests
- WorkspaceViewModelTests 相关 text edit / search index tests
- EditorMacUITests 或 EditorIOSUITests 中一个真实输入/焦点路径，如果 automation 可用
- git diff --check

## 10. Output Format

每次阶段性输出必须包含：

### 1. Current Interaction Model
- 状态流
- 渲染流
- 数据流
- 高风险路径

### 2. Database Profile
表格列出 Current / Current x5 / Current x10：
- DB path label
- page count
- block count
- max blocks per page
- p95/p99 blocks per page
- attachment/tag/search/sync/page version counts
- integrity check result

### 3. Performance Budget
按场景列目标 p50/p95/p99。

### 4. Instrumentation Added
- 文件
- flag
- signpost/log names
- 如何开启
- 如何查看 report

### 5. Baseline Result
分别列：
- Current
- Current x5
- Current x10
- macOS
- iOS
- Top 10 slow interactions

### 6. Bottleneck Diagnosis
用证据说明主要瓶颈在哪里，不要猜。

### 7. Optimization Patch
每一步说明：
- 改了什么
- 为什么
- 风险是什么
- 如何验证

### 8. Before / After Report
表格：
- 场景
- dataset
- before p50/p95/p99
- after p50/p95/p99
- 是否达到预算
- 剩余问题

### 9. Regression Checks
- focused unit tests
- focused UI tests
- build
- logs/signposts/sample
- 无法验证项和原因

### 10. Final Checklist
- Reproduction attempted:
- Evidence collected:
- Root cause:
- Files changed:
- Verification run:
- Regression checks:
- Remaining risk:
- Suggested next instrumentation or test:

## 11. Completion Bar

只有同时满足这些条件，才可以说本轮完成：
- Current / Current x5 / Current x10 都有 baseline。
- 至少一个 P0/P1 瓶颈有 before/after 证据。
- 输入、cursor、selection、IME 没有回归证据。
- 真实库副本路径和安全隔离已报告。
- Focused tests/build 已运行，失败项已解释。
- 最终报告包含剩余风险和下一轮建议。
```
