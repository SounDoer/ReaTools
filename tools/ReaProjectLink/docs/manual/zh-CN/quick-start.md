# ReaProjectLink 快速上手

这一篇只讲最常用的操作和必须记住的规则。想了解细节，再看 [完整手册](README.md)。

## 它做什么

![ReaProjectLink 的两个方向](images/01-overview.png)

- **Master Project**（混音工程）把画面、Marker、Region 发布为 **Reference**，发给各部门。
- **Source Project**（对白、音乐、音效等部门的工程）把做好的 WAV 发布为 **Delivery**，交回 Master。
- 发布方点 `Publish`，接收方看到更新后自己点 `Synchronize` / `Sync`。没有人能直接改别人的工程。

每发布一次就是一个新的 **Revision**（`r1`、`r2`……）。

## 第一次使用

1. 在 REAPER 里**先保存工程**，放在大家都能访问的共享位置。
2. 打开 ReaProjectLink 窗口，点 `Initialize Master Project` 或 `Initialize Source Project`。

![初始化页面](images/03-setup.png)

工程里原来就有的内容不会被自动接管，只有按下面流程登记、同步的内容才由 ReaProjectLink 管理。

## Master 负责人

### 发布 Reference

1. 在 REAPER 里选中画面轨道，按住 `Shift` 点选要发给各部门的 Marker 和 Region（不要用 `Ctrl`，会复制 Marker）。Selected 下会列出选中的内容：

   ![选中轨道、Marker 和 Region](images/03-master-selected.png)

2. 点 `Register`，这些内容出现在 Registered 下：

   ![登记完成](images/03-master-registered.png)

3. 点 `Review and Publish`，确认内容后点 `Publish`：

   ![Reference 发布检查](images/03-reference-publish-review.png)

4. 卡片显示 `Published r1`，发布完成：

   ![Reference 发布完成](images/03-reference-published.png)

之后画面或 Marker 有变化：已登记的内容直接改，新加的 Marker / Region 先 `Register`，再 `Review and Publish`。

### 导入各部门的 Delivery

1. 在 Deliveries 卡片点 `+`，选择对方工程旁边的 `_ReaProjectLink/<工程名>/delivery.json`：

   ![选择 delivery.json](images/03-choose-delivery-json.png)

2. 为每条交付轨道选择导入位置（第一次用默认的 `New Track` 即可），点 `Import`：

   ![导入页面](images/03-add-delivery-lanes.png)

3. 这一行显示 `Up to Date · r1`，音频导入到时间线上，位置和对方工程里一致：

   ![导入完成](images/03-delivery-imported.png)

### 同步更新

1. 对方发布新版本后，对应一行会显示 `r2 Available · Have r1`，点 `Sync`：

   ![有新的 Delivery](images/04-delivery-update-available.png)

2. 确认要替换的 Item 数量，点 `Sync`。原来的 Item 会整体换成新版本：

   ![同步检查](images/04-delivery-sync-review.png)

3. 这一行变回 `Up to Date · r2`。记得保存工程。

   ![同步完成](images/04-delivery-synced.png)

## 各部门（Source Project）

### 订阅 Reference

1. 在 Reference 卡片点 `Choose reference.json`，选择 Master 工程旁边的 `_ReaProjectLink/<工程名>/reference.json`：

   ![选择 reference.json](images/03-choose-reference-json.png)

2. 卡片显示 `Reference r1 Available`，点 `Review Update`：

   ![有可同步的 Reference](images/03-source-reference-available.png)

3. 点 `Synchronize`：

   ![Reference 同步检查](images/03-reference-update-review.png)

4. 画面、Marker、Region 出现在和 Master 相同的时间位置，卡片显示 `Up to Date`：

   ![同步后的时间线](images/03-source-synchronized-timeline.png)

以后 Master 发布新画面，卡片会显示 `Reference r2 Available`，同样点 `Review Update` → `Synchronize`：

![有新的 Reference](images/05-reference-update-available.png)

### 交付音频

1. 把要交付的音频放在专门的交付轨道上（必须是 WAV）。选中这些轨道，Delivery 卡片的 Selected 会列出它们：

   ![选中交付轨道](images/03-delivery-tracks-selected.png)

2. 点 `Register`。只需要登记一次，之后轨道上增删改的 Item 都会自动算进下一次发布：

   ![交付轨道登记完成](images/03-delivery-tracks-registered.png)

3. 点 `Review and Publish`，确认轨道和 Item 数量后点 `Publish`：

   ![Delivery 发布检查](images/03-delivery-publish-review.png)

4. 卡片显示 `Last Published r1`，Master 那边就能导入了：

   ![Delivery 发布完成](images/03-delivery-published.png)

改完了就再 `Review and Publish` 一次，Master 那边会看到新版本。

## 必须记住的规则

| 规则 | 不遵守会怎样 |
|------|------------|
| 工程先保存，再用 ReaProjectLink | 窗口只显示 `Save this project in REAPER to use ReaProjectLink.` |
| 交付轨道上不挂 FX，效果先 bounce 进 WAV | 发布会被拦下（见下图）；FX 效果不会带给 Master |
| 在 Master 里只在**轨道**上混音（音量、声像、FX、自动化） | 对同步进来的 **Item** 做的修改，下次同步会被替换掉 |
| 同步、导入之后记得保存工程 | 同步只修改工程，不会自动保存 |
| 换新版画面时用新的文件名，不要覆盖原文件 | 各部门同步时会报错，需要重新发布 |
| 不要手动改动 `_ReaProjectLink` 文件夹 | 别的工程会读不到你发布的内容 |
| 没有后台自动检查；想看有没有更新，点右上角 `Check Now` | 打开窗口、切换工程标签时也会自动检查一次 |

交付轨道挂了 FX 时，发布会被拦下：

![轨道上有 FX 被拦下](images/05-delivery-fx-blocked.png)

## 遇到问题

| 情况 | 看这里 |
|------|-------|
| 发布被拦下，`Publish` 点不了 | [发布被拦下时](05-source-tasks.md#发布被拦下时) |
| 想在 Master 里改某段音频又不想被覆盖 | [把 Item 留作本地内容](04-master-tasks.md#把-item-留作本地内容) |
| 新版本有问题，要退回旧版本 | [回退到旧的 Revision](04-master-tasks.md#回退到旧的-revision) |
| 要多交或少交一条轨道 | [增加或减少 Delivery Track](05-source-tasks.md#增加或减少-delivery-track) |
| `Couldn't Reach`、`Couldn't Read` 等报错 | [常见问题](06-troubleshooting.md) |
| 想完整跟着做一遍 | [第一次完整走一遍](03-first-walkthrough.md) |
