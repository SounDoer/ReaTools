# ReaAssetFlow — Product Requirements Document

**版本**: v0.1
**日期**: 2026-04-20
**状态**: MVP 开发中

---

## 1. 背景与目标

### 1.1 背景

游戏音频设计师在 DAW（数字音频工作站）中制作完音频资产后，需要手动将文件导出、复制到游戏音频中间件的指定目录，再逐一创建层级结构和容器对象。这个过程重复、繁琐，且容易因手动操作引入不一致性。

### 1.2 目标

构建一个自动化工具，让音频设计师能够从 Reaper 直接将渲染好的音频资产按规范快速导入 Wwise，同时将命名规范与层级结构固化为可复用的配置文件，保证团队协作时的一致性。

### 1.3 初期范围

- DAW：**Reaper**
- 音频中间件：**Wwise**
- 使用者：个人 → 小规模团队

---

## 2. 用户与使用场景

### 2.1 目标用户

- **主要**：音频设计师（个人），熟悉 Wwise 和 Reaper，Python 不精通但能读懂
- **次要**：小型游戏音频团队（2–5 人），需要统一的命名规范和导入流程

### 2.2 典型使用场景

**场景：脚步声资产导入**

1. 音频设计师在 Reaper 时间轴上用 Region 标注各变体，Region 名即目标文件名
   - 示例：`FS_Sneaker_Dirt_Walk_01`、`FS_Sneaker_Dirt_Walk_02`、`FS_Sneaker_Dirt_Run_01`
2. 在 Reaper 内执行渲染（Render by Regions）
3. 触发 ReaScript，ReaScript 调用外部 Python 脚本
4. Python 脚本将 WAV 文件复制到 Wwise Originals 指定目录
5. Python 脚本通过 WAAPI 在 Wwise 中指定路径下创建对应的 Sound SFX 对象
6. 设计师在 Wwise 中看到新导入的对象，继续配置参数

---

## 3. 功能需求

### 3.1 MVP 功能（v0.1，已实现）

#### F1：Item 自动命名
- **Reaper 侧**：只需 **ReaScript: Load `scripts/ReaAssetFlow.lua`**；Auto name（Marker / Region / 轨道 + pattern）与导入 UI 均在同一脚本内
- 名称写入 item Notes（用于 `$item` 渲染 token）和 take 名称（显示在时间轴上）

#### F2：Transfer Panel（ImGui UI）
- `ReaAssetFlow.lua`：基于 ReaImGui 的浮动面板，统一管理导入全流程
- 支持从 Wwise 动态拉取 WorkUnit 和导入目标列表（带本地缓存）
- 支持配置多层 Wwise 结构（ActorMixer / Random Container / Sound SFX），使用 token 组合命名
- 导入前预览每个 item 对应的 Wwise 路径，检测路径碰撞

#### F3：Wwise 结构化导入
- `wwise_import.py`：通过 WAAPI（`ak.wwise.core.audio.import`）按结构化路径创建 Sound SFX 对象
- 支持 `useExisting` / `createNew` / `replaceExisting` 三种冲突策略
- 导入前验证 WAAPI 连接和目标路径，渲染后自动清理 staging 临时目录

#### F4：配置与状态
- **无仓库级 `config.json`**：`wwise_import.py` 内置 `DEFAULT_CONFIG`（`waapi_url`、默认导入目标、`p4_policy` 等）；导入时的工程路径、子目录、目标、结构等由 **Transfer Panel** 与 `rtw_request.json` 提供
- **可选**：本机根目录仍可放置 `config.local.json` / `config.json` 覆盖默认键（例如仅覆盖 `p4_policy`）；不随 Git 分发
- **`_state/rtw_ui_state.json`**：面板持久化（Git 忽略）

#### F5：一键环境部署
- 提供 `setup.bat`，自动检测 Python、安装 `requirements.txt`（含 `waapi-client`）
- 面向不会写代码的团队成员，确保零门槛部署

### 3.2 后续迭代功能（v0.2+，优先级待定）

| 功能 | 描述 |
|---|---|
| 命名规范校验 | 导入时检测文件名是否符合已有规范，不符合则提示 |
| 规范模板管理 | 从现有 Wwise 工程结构中读取并保存为规范模板 |
| 批量参数设置 | 支持在配置中指定 Wwise 对象属性（音量、优先级等） |
| 右键打开 Reaper | 在 Wwise 中右键对象，打开对应的 Reaper 工程文件（nice-to-have）|

---

## 4. 技术架构

### 4.1 整体流程

```
[Reaper]
  │  用户完成渲染（Render by Regions）
  │  触发 ReaScript（Lua）
  ▼
[ReaScript]
  │  调用 GetLastRenderFiles() 获取渲染文件列表
  │  以参数形式启动外部 Python 脚本
  ▼
[Python 脚本]
  │  读取 rtw_request.json + 内置默认 / 可选本机 config 覆盖
  │  复制 WAV → Wwise Originals 目录
  │  通过 WAAPI 在 Wwise 中创建 Sound SFX 对象
  ▼
[Wwise]（通过 WAAPI WebSocket 连接，需保持打开状态）
```

### 4.2 技术选型

| 组件 | 技术 |
|---|---|
| Reaper 端触发 | ReaScript（Lua） |
| 核心逻辑 | Python 3.x |
| Wwise 通信 | `waapi-client`（官方 Python 库） |
| 配置格式 | 运行时 JSON（request / ui_state）+ Python 内置默认 |
| 环境部署 | `setup.bat`（Windows） |

### 4.3 依赖说明

- **Reaper**：已安装，版本不限
- **Wwise**：已安装并打开（WAAPI 需要 Wwise 保持运行状态）
- **Python 3.x**：通过 `setup.bat` 引导安装
- **waapi-client**：`pip install waapi-client`

### 4.4 目录结构

```
ReaAssetFlow/
├── PRD.md                       # 本文档
├── README.md                    # 使用说明
├── setup.bat                    # 一键环境部署脚本
├── tests/                       # pytest（wwise_import 纯函数）
└── scripts/
    ├── ReaAssetFlow.lua           # 主工作流（Transfer Panel，ImGui UI，含 Auto name）
    └── wwise_import.py          # Python 核心导入脚本（WAAPI）
```

---

## 5. 非功能需求

- **易用性**：非程序员的音频设计师能在 5 分钟内完成环境部署并成功运行第一次导入
- **可配置性**：路径与结构通过 Transfer Panel 与运行时 JSON 配置，高级项可通过可选本机 JSON 覆盖默认
- **可扩展性**：Python 脚本结构清晰，便于后续添加层级创建、规范校验等功能
- **跨机器**：仓库不含机器路径；各机器在面板中选择本机 `.wproj` 即可

---

## 6. 不在范围内（MVP）

- 命名规范校验与提示
- Mac 支持（当前仅 Windows）
- Wwise 右键菜单集成

---

## 7. 开放问题

| 问题 | 状态 |
|---|---|
| Wwise 版本兼容性范围 | 待确认 |
| 若 WAAPI 连接失败的错误处理策略 | 待设计 |
| 团队共享配置时本地路径如何管理 | 仓库不含路径；各机面板选 `.wproj`，状态在 `_state/`；可选本机 JSON 仅覆盖高级默认 |

---

## 8. 参考资料

- [ReaWwise 官方 GitHub](https://github.com/audiokinetic/ReaWwise)
- [Wwise-MCP（WAAPI + MCP 实验项目）](https://github.com/BilkentAudio/Wwise-MCP)
- [waapi-client Python 库](https://pypi.org/project/waapi-client/)
- [Audiokinetic WAAPI 文档](https://www.audiokinetic.com/library/edge/?source=SDK&id=waapi.html)
- [Connecting Wwise and REAPER: WAAPI Transfer](https://blog.audiokinetic.com/connecting-wwise-and-reaper-part-1-waapi-transfer/)
