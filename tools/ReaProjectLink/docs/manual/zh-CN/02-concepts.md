# 2. 核心概念

ReaProjectLink 的界面是英文的。这一篇把界面上会反复出现的词先解释清楚，后面的教程直接用这些英文原词。

| 界面上的词 | 一句话解释 |
|------------|------------|
| Source Project | 上游工程：对白、音乐、音效。发布音频，接收画面 |
| Master Project | 整合和混音的工程。发布画面，接收音频 |
| Delivery Track | Source Project 里登记为"要交付"的轨道 |
| Delivery | 一个 Source Project 交给 Master Project 的全部音频 |
| Reference | Master Project 发给各 Source Project 的画面、Marker 和 Region |
| Revision | 每次发布生成的版本号，显示为 r1、r2…… |
| Register / Unregister | 把 REAPER 里选中的轨道、Marker、Region 登记给 ReaProjectLink 管理 / 取消登记 |
| Publish | 把当前登记的内容发布成一个新 Revision，别人才能拿到 |
| Synchronize | 把别人发布的某个 Revision 同步进自己的工程 |
| Synchronized | 由 ReaProjectLink 同步进来、受它管理的内容 |
| `_ReaProjectLink` | 工程旁边自动生成的发布文件夹 |

## Source Project 和 Master Project

每个工程在第一次使用 ReaProjectLink 时，要选择自己是哪一种：

- **Source Project**：对白、音乐、音效各自的工作工程。一个项目里可以有很多个。
- **Master Project**：把所有部门的音频汇总起来混音的工程。一个项目通常只有一个。

一个 `.rpp` 只能是其中一种。

## Delivery Track

Source Project 里不是所有轨道都会被交出去。你需要明确告诉 ReaProjectLink："这几条轨道上的音频是要交付的。"被登记的轨道就叫 Delivery Track。

Delivery Track 上放的应该是**已经弹出好的 WAV**。发布时，ReaProjectLink 原样复制 WAV 文件本身，不会帮你渲染：

- Item 的位置、长度、淡入淡出、Item 音量会带过去；
- 轨道上的 FX、Take FX、轨道音量和声像、自动化**不会**带过去。

如果 Delivery Track 或 Item 上还挂着 FX，发布时会被拦下来提醒你先 bounce。

## Delivery 和 Reference

两个方向，两个名字：

- **Delivery**：Source Project → Master Project。内容是所有 Delivery Track 上的音频。
- **Reference**：Master Project → Source Project。内容是 Master Project 登记的画面轨道、Marker 和 Region。

每个 Source Project 有自己的一份 Delivery；整个项目只有一份 Reference，所有 Source Project 都对着它工作。

## Revision

每次 Publish 都会生成一个新的 Revision，界面上显示为 `r1`、`r2`、`r3`……

- Delivery 的 Revision 和 Reference 的 Revision 各自独立计数。
- 每个 Revision 都是**完整的一版**，不是"这次改动的部分"。
- 旧的 Revision 会保留下来，不会被覆盖。

Source Project 发布 Delivery 时，会记下它是对着 Reference 的哪个 Revision 做的。Master Project 因此能看出某个部门是不是还在用旧画面。

## Register 和 Unregister

ReaProjectLink 不会自己猜哪些东西要交、哪些要发。所有要管理的对象都要你先在 REAPER 里选中，再点 `Register`：

- 在 Source Project 里，Register 的是 Delivery Track；
- 在 Master Project 里，Register 的是画面轨道、Marker 和 Region。

不想再管理某个对象时，选中它点 `Unregister`。Unregister 不会删除 REAPER 里的东西，只是 ReaProjectLink 不再管它。

## Publish 和 Synchronize

这是最重要的两个动作：

- **Publish**：把你登记的内容打包，写进共享目录，生成一个新 Revision。点之前会有一个检查页面（Review），列出这次会发布什么。
- **Synchronize**：把对方发布的某个 Revision 拉进你的工程。点之前同样有一个检查页面，告诉你会增加、替换什么。

**保存工程不等于发布。** 你怎么改、存多少次，对方都看不到，直到你 Publish。同理，对方发布了新 Revision，你的工程也不会自己变，直到你 Synchronize。

## Synchronized 的内容和你自己的内容

同步进来的东西由 ReaProjectLink 管理，界面上叫 Synchronized：

- 在 Source Project 里，同步进来的画面轨道、Marker、Region 是 Synchronized 的；
- 在 Master Project 里，从 Delivery 导入的音频 Item 是 Synchronized 的。

Synchronized 的内容会在下一次 Synchronize 时**整批换成新版本**。所以：

- 不要指望在 Master Project 里直接改某段导入进来的对白，下次同步就会被换掉。真需要改，让对白那边改完重新发布；或者把这段音频挪到别的轨道，并确认把它保留为本地内容，之后它就不再被替换（见 [4. Master Project 日常操作](04-master-tasks.md)）。
- 你自己在工程里新加的轨道和 Item 不受影响。

## `_ReaProjectLink` 发布文件夹

第一次 Publish 时，ReaProjectLink 会在 `.rpp` 所在目录下建一个 `_ReaProjectLink` 文件夹，里面是发布出去的所有东西：

```text
Dialogue/
  Demo_Dialogue.rpp
  _ReaProjectLink/
    Demo_Dialogue/
      delivery.json         ← 最新 Revision 的入口，Master Project 选这个文件
      history/              ← 每个 Revision 的记录
      media/                ← 复制出来的 WAV
```

Master Project 那边发布 Reference 时，结构一样，入口文件叫 `reference.json`。

对方订阅你时，选的就是这个 `delivery.json` 或 `reference.json`。所以工程要放在大家都能访问的共享位置。这个文件夹由 ReaProjectLink 自己维护，**不要手动修改或删除里面的文件**。

## 时间线怎么对齐

Source Project 第一次同步 Reference 时，默认使用 Mirror Master Timeline：直接采用 Master Project 的时间码偏移和帧率，画面、Marker、Region 都放在和 Master Project 完全相同的时间位置上。

所以只要大家都同步了同一个 Reference，你在自己工程里 01:00:10:00 放的对白，导入 Master Project 后也会在 01:00:10:00。

下一篇：[3. 第一次完整走一遍](03-first-walkthrough.md)
