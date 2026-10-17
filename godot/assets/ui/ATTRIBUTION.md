# 素材来源与授权记录（v1.2 切图包）

> 上架前需统一复核，下面只记录事实，不代表已做法务确认。

## 一、手绘类图像（AI 生成）
- 范围：panel_frame_*、card_*、btn_action_*、btn_next_turn_*、city_badge_*、icon_*、advisor_avatar、ending_scroll、bg_*.jpg，以及它们的各状态变体。
- 生成工具：Grok Bot 内置图像生成功能（GenerateImage），由 Alice 在 2026-10-15 生成；随后用 PIL 做抠图、缩放、九宫格裁切与状态着色（亮度/发光）。
- 授权状态：AI 生成内容，无第三方素材混入；版权归属、平台（Steam/H5 渠道）对 AI 素材的披露要求，**待上架前统一核对**。
- 提示词中未指定真实人物或既有 IP；图中界面文字均不烤入（stamp_win/lose/draw 的「胜/负/平」字为 Noto Serif CJK SC Bold 渲染后的印章图）。
- 备注：处理后的中间素材在 /workspace/改命天下/ui-design-v1/v1.2/assets/，切图脚本为 ../make_slices.py；生成时的原始提示词未单独归档。

## 二、字体（SIL OFL 1.1，可商用、可嵌入，不得单独售卖，须随附许可）
| 文件 | 来源字体 | 许可 |
|---|---|---|
| NotoSerifSC-Bold.otf / .woff2 | Noto Serif CJK SC Bold（与思源宋体同源设计） | SIL OFL 1.1，见 OFL.txt |
| NotoSansSC-Regular.otf / .woff2 | Noto Sans CJK SC Regular（与思源黑体同源设计） | 同上 |
| NotoSansSC-Bold.otf / .woff2 | Noto Sans CJK SC Bold | 同上 |
- 当前 otf / woff2 是 985 字子集，覆盖界面用字，包含「差」，以及序章、副标和确认框用到的「七书党十宗岁年旱熹陕凉删役末苍除」，另有全部可打印 ASCII（U+0020–U+007E，含半角 `=`）、→、≥、≤ 和全角空格。完整字表是同目录 `charset_used.txt`。字体里没有 ✗，界面用 `icon_cross_32.png`。
- Godot 工程只加载三份 `.otf`。`.woff2` 是同子集的 H5 备用副本，导出预设排除 `*.woff2`，避免和 otf 一起打进 Godot 包。
- 子集化属于 OFL 允许的修改版；因本包不使用保留字体名 "Source"，文件名用 Noto。

## 三、配乐
- Floating Lanterns · John Bartmann · CC0（结局页底部署名，原文：「配乐：Floating Lanterns · John Bartmann · CC0」）。

## 四、S1 龙椅背墙贴片
- 文件：`assets/s1/throne_backwall.png`（1024×802，RGBA）。进包只有这一张；原图和叠合预览不进包。
- 来源：GenerateImage（AI 生成），2026-10-16。提示词：「晚明皇家宝座大殿背墙，朱漆金雕云龙，正面正投影」。之后做了裁切，并在上缘 150px、左右缘 170px 羽化，下缘不羽化。
- 不是自行绘制，也不是购买素材。不能当成没有版权风险。上架前要和手绘氛围图一起复核。

## 五、标题页与序章底图（v1.4）
- 文件：`bg_story_s1.jpg`（1280×720）。标题页和序章共用。
- 来源：Alice《UI v1.4-title》（2026-10-17）复用的 v1.3 登基夜氛围底 `bg_story_s1.jpg`。该包里的原图是指向 v1.3 的符号链接，没有随 zip 进来。游戏里这一张是从标题页、序章成稿去掉说明里的遮罩后拼回的；菜单挡住的中部按左右两侧殿堂颜色补过，不是新调用 GenerateImage。
- 序章文字框用已有 `panel_frame_l.png`（说明里的 `frame_ornate.png`，九宫格边距 26）。按钮是色值，不是新切图。
- 授权状态与第一节手绘氛围图相同。上架前要复核，不能写成没有版权风险。

## 六、游戏内 Credits 建议文案
- 字体：Noto Serif/Sans CJK SC（SIL OFL 1.1）
- 配乐：Floating Lanterns · John Bartmann · CC0
- 美术：AI 辅助生成（Grok Bot，2026-10-15），后期由 Alice 处理
