# ReaAssetFlow

在 Reaper 中根据字段规则对 item 进行批量命名和渲染输出后，直接通过 WAAPI 一键导入 Wwise，并自动构建指定层级结构。

---

## 环境要求

- Windows 10/11
- Reaper + [ReaImGui](https://github.com/cfillion/reaimgui)（通过 ReaPack 安装）
- Wwise 2024.1+，已启用 WAAPI（默认端口 8080）
- Python 3.8+

---

## 安装

1. 基础功能安装：双击根目录下的 `setup.bat`。
2. 可选 LLM 功能安装：如需启用 LLM 辅助命名/结构建议，再运行 `setup-llm.bat`。

> 说明：LLM 功能除了 Python 依赖，还需要本机安装并启动 Ollama 服务（`ollama serve`）以及拉取模型。

---

## 在 Reaper 中注册脚本

Actions → Show action list → **ReaScript: Load** → 选择 `ReaAssetFlow.lua`。

建议为其绑定快捷键或添加到工具栏。

---

## 使用流程

### 1. 命名 item

**Auto Renamer** 支持用以下字段组合成命名 pattern：

| Token | 来源 |
|-------|------|
| `$track` | item 所在轨道名 |
| `$marker` | item 起点左侧最近的 Marker 名 |
| `$region` | item 所在 Region 名 |
| `$idx` / `$idx2` / `$idx3` | 同一分组内的序号（1 / 01 / 001） |

在 Transfer Panel 的 **Auto Renamer** 区填写 pattern（如 `$track_$marker_$idx2`），点击 **Auto Name** 批量写入选中 item 的名称。

### 2. 配置导入参数

在 **Wwise Importer** 区填写：

| 字段 | 说明 |
|------|------|
| Project Path | Wwise 工程 `.wproj` 路径（Browse 选取） |
| Originals Folder Path | WAV 存放目录（Wwise Originals/SFX/ 下的子目录） |
| WorkUnit / Import Destination | 点击 **Load WorkUnits** 后选择，再点 **Load Targets** 选择导入节点 |
| Wwise Structures | 配置层级结构，用 `$track`、`$marker`、`$item` 等 token 组合命名规则 |
| If Name Exists | `useExisting`（复用）/ `createNew`（新建）/ `replaceExisting`（替换） |

点击 **Preview Structure** 可预览每个 item 将导入到哪个 Wwise 路径。

**Presets**：可将当前面板配置保存为预设，下次一键加载。

### 3. Transfer to Wwise

点击 **Transfer to Wwise**，脚本将：

1. 验证 WAAPI 连接与目标路径
2. 弹出 Reaper 渲染对话框 — Source 选 **Selected items (stems)**，Filename 保持 `$item`，点击 Render
3. 渲染完成后自动导入 Wwise，弹窗显示结果

---

## Perforce

默认 `p4_policy: auto`：导入时自动尝试对相关 `.wwu` 和音频文件执行 `p4 edit` / `p4 add`，`p4` 不可用时仅打印警告，不中止导入。

如需调整，在仓库根目录放置 `config.local.json`（不提交 Git），例如：

```json
{"p4_policy": "required"}
```

可选值：`auto`（默认）/ `required`（失败则中止）/ `off`（不调用）。

---

## 常见问题

**"Cannot connect to Wwise"**
- 确认 Wwise 已打开
- Wwise → User Preferences → 勾选 **Enable Wwise Authoring API**
- 确认端口与 Wwise 设置一致（默认 8080）

**渲染后未找到 WAV 文件**
- 渲染对话框中 Source 必须为 **Selected items (stems)**
- Filename 必须保持 `$item`

**预览路径与预期不符**
- 检查 item 是否已在 Auto Renamer 中命名
- 确认 token（`$track`、`$marker`、`$item`）在当前 pattern 下能正确展开
