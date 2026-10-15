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
- 已按 charset_used.txt（540 字，取自项目 godot 目录与 v1.2 页面中出现的字符）做子集。游戏里出现新汉字时，用同一命令重新生成：`pyftsubset <原字体> --text-file=charset_used.txt --layout-features='kern,liga,locl' --output-file=<out>`。
- 子集化属于 OFL 允许的修改版；因本包不使用保留字体名 "Source"，文件名用 Noto。

## 三、配乐
- Floating Lanterns · John Bartmann · CC0（结局页底部署名，原文：「配乐：Floating Lanterns · John Bartmann · CC0」）。

## 四、游戏内 Credits 建议文案
- 字体：Noto Serif/Sans CJK SC（SIL OFL 1.1）
- 配乐：Floating Lanterns · John Bartmann · CC0
- 美术：AI 辅助生成（Grok Bot，2026-10-15），后期由 Alice 处理
