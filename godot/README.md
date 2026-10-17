# 《改命：天下》v0.2 M0 · Godot 工程

空壳策略大地图。用 **Godot 4.6.3** 打开即可在 macOS（Apple Silicon / M4）上运行。本里程碑没有回合模拟、简战、3D 剧情或 BGM。

`web/` 里的文字灰盒已归档，不再作为产品形态，请不要在那条线上改玩法。

## 在 Mac mini M4 上打开

1. 安装 **Godot 4.6.3-stable** 标准版（GDScript，不要下带 .NET / C# 的版本）。
   - 版本页：<https://godotengine.org/download/archive/4.6.3-stable/>
   - macOS Universal（含 Apple Silicon）：<https://github.com/godotengine/godot/releases/download/4.6.3-stable/Godot_v4.6.3-stable_macos.universal.zip>
2. 解压后把 `Godot.app` 放进「应用程序」。若系统提示无法验证开发者：在 Finder 里对 Godot **右键 → 打开**，或到「系统设置 → 隐私与安全性」里允许。
3. 启动 Godot，选 **Import**，指向本目录的 `project.godot`（仓库里的 `godot/project.godot`）。
4. 打开后看项目设置：`config/features` 含 `4.6` 与 `Forward Plus`，应用名是「改命：天下」，主场景是 `scenes/big_map.tscn`。
5. 按 **F5**（或右上角播放）运行。

首次打开会在本地生成 `godot/.godot/`（编辑器缓存），已写入仓库 `.gitignore`，不要提交。

## 跑起来之后应看到

- 示意大地图，六座可点城池（大纲冻结，不是占位名）：
  - **京师**（明，首都）
  - **保定**（明）
  - **大同**（明，边镇）
  - **宁远**（明，袁系前线）
  - **锦州**（争议/后金压境）
  - **沈阳**（后金）
- 实线是邻接，**大同—宁远** 的虚线标着「远」。坐标只是示意。
- 右侧局面是大纲初值，不会随点击变化：回合第 1 / 10、银两 40、粮草 45、民心 35、辽东稳固 40、后金压力 50、世界线偏移 0、袁崇焕「前线可用」。
- 点一座城，下方面板写出归属、备注和邻接。
- **「切换→抉择→写回（M1 占位）」** 只说明以后的剧情回路（切场景、抉择、把变量写回面板、回到地图）。M0 不进入 S1/S2/S3，也不改局面。

界面中文用内嵌的文泉驿微米黑子集（`theme/WenQuanYiMicroHei-Subset.ttf`，Apache-2.0，见同目录许可文本）。系统字体只作缺字回退，不依赖本机是否安装苹方。

## 目录

| 路径 | 作用 |
| --- | --- |
| `project.godot` | 工程入口，钉死 4.6 / Forward Plus |
| `scenes/big_map.tscn` | 主场景（地图 + 局面 + 城池面板） |
| `scripts/big_map.gd` | 点城与 M1 占位按钮 |
| `scripts/map_canvas.gd` | 示意底图与邻接线 |
| `data/campaign_baseline.gd` | 六城、邻接、局面初值 |
| `theme/` | 系统中文字体主题 |

后续 3D 剧情仍用这个工程。H5 导出再评估要不要改 Compatibility 渲染器；M0 首个目标机器是 Mac，所以用 Forward Plus。
