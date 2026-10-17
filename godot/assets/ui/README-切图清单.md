# 改命：天下 UI v1.2 切图包（平铺）

放入 `godot/assets/ui/`。全部 1280×720 基准，PNG 透明底（bg_* 为 JPG）。界面文字一律用字体节点，不烤图（仅 stamp_* 为印章图）。
授权与来源见 `ATTRIBUTION.md`，字体许可见 `OFL.txt`。

## 九宫格（NinePatchRect patch_margin）
| 文件 | 尺寸 | 四边 margin (L/T/R/B) | 用途 |
|---|---|---|---|
| panel_frame_s.png | 115×86 | 10/10/10/10 | HUD 条、提示条、小面板（中心已带深色底） |
| panel_frame_m.png | 230×172 | 20/20/20/20 | 内政卡、简战标题牌 |
| panel_frame_l.png | 299×224 | 26/26/26/26 | 简战大面板、帮我选面板 |
| panel_advisor.png | 470×214 | 20/20/20/20 | 「帮我选」面板（可直接按尺寸用） |
| card_neizheng_{normal,hover,pressed,disabled,selected}.png | 272×132 | 20/20/20/20 | 内政卡五态；练兵未选城时用 disabled |
| hud_chip_{normal,disabled}.png | 158×46 | 10/10/10/10 | 顶部资源条 |
| row_recommend_{normal,hover,pressed,disabled,selected}.png | 446×42 | 6/6/6/6 | 帮我选推荐行 |
| plaque_cinnabar_{normal,hover,pressed,disabled,selected}.png | 96×34 | 8/8/8/8 | 主行动印章下的朱红名牌（文字用 Label） |
| tile_stat.png | 180×66 | 6/6/6/6 | 结局数据砖底 |
| bar_bg.png / bar_fill_gold.png / bar_fill_cinnabar.png | 64×12 / 64×10 | 6/0/6/0 | 进度条（战斗进度用 gold，世界线用 cinnabar） |

## 按钮与印章（不拉伸，居中放置）
- btn_action_{march,siege,hold}_{normal,hover,pressed,disabled,selected}.png 144×144（含光晕留白，有效圆盘约 120）：行军/攻城/固守。图标已提亮并加深色衬底，小屏可辨；hover 外圈金光，selected 光更强。名牌用 plaque_cinnabar 叠 Label。
- btn_next_turn_{normal,hover,pressed,disabled}.png 188×188（有效圆约 168）：朱砂印泥「下一回合」，文字用 Label 叠加（Noto Serif SC Bold 28px，近白）。
- city_badge_{ming,jin,contested}_{normal,hover,selected}.png 104×104（有效圆 84）：城池印章，名称与兵力用 Label 叠加。
- ring_select.png 160×160：选中城外圈光环；bubble_step.png 32×32：①②③ 引导气泡底，数字用 Label。
- stamp_{win,lose,draw}.png 160×160：简战结果印章（含字）。
- advisor_avatar.png 120×120：谋士头像（中性）。

## 图标（各 64 与 96 两档）
icon_{grain,silver,lianbing,march,siege,hold,minxin,liaodong,pressure,turn,volume,worldline}_{64,96}.png：粮草、银两、练兵、行军、攻城、固守、民心、辽东稳固、后金压力、回合、音量、世界线。

## 背景与卷轴
bg_map_liaodong.jpg / bg_battle_banners.jpg / bg_ending_night.jpg（1280×720）。ending_scroll.png 1144×682：结局卷轴，纸面区域约 x 4%–96%、y 9%–69%，下卷轴杆 y 70%–76%；按钮放在卷轴下方。

## 字体
NotoSerifSC-Bold、NotoSansSC-Regular、NotoSansSC-Bold（.otf 给 Godot，.woff2 给 H5）。当前文件是 985 字子集，含「差」、序章和确认框用字，以及全部可打印 ASCII 和半角 `=`。字表见 `charset_used.txt`。Godot 只引用 otf；woff2 不进 Godot 导出包。
推荐字号：标题 Serif Bold 32–46；卡片名 Serif Bold 22–26；数字 Serif Bold 19–22；正文/说明 Sans Regular 15–18；名牌 Serif Bold 20。
颜色：金 #D4A84B、近白 #F5EDE0、得 #9AD98A、失 #F0A27A、朱砂 #8B1E1E、警示 #E85D4C。

## 交互态约定
hover/selected 要明显亮起：主行动印章直接换 hover/selected 图；卡片、城印同理。disabled 去色压暗，并在卡内用 Label 写原因（如「请先选中己方城池」）。

## 全部文件
| 文件 | 尺寸 |
|---|---|
| `advisor_avatar.png` | 120×120 |
| `bar_bg.png` | 64×12 |
| `bar_fill_cinnabar.png` | 64×10 |
| `bar_fill_gold.png` | 64×10 |
| `bg_battle_banners.jpg` | 1280×720 |
| `bg_ending_night.jpg` | 1280×720 |
| `bg_map_liaodong.jpg` | 1280×720 |
| `btn_action_hold_disabled.png` | 144×144 |
| `btn_action_hold_hover.png` | 144×144 |
| `btn_action_hold_normal.png` | 144×144 |
| `btn_action_hold_pressed.png` | 144×144 |
| `btn_action_hold_selected.png` | 144×144 |
| `btn_action_march_disabled.png` | 144×144 |
| `btn_action_march_hover.png` | 144×144 |
| `btn_action_march_normal.png` | 144×144 |
| `btn_action_march_pressed.png` | 144×144 |
| `btn_action_march_selected.png` | 144×144 |
| `btn_action_siege_disabled.png` | 144×144 |
| `btn_action_siege_hover.png` | 144×144 |
| `btn_action_siege_normal.png` | 144×144 |
| `btn_action_siege_pressed.png` | 144×144 |
| `btn_action_siege_selected.png` | 144×144 |
| `btn_next_turn_disabled.png` | 188×188 |
| `btn_next_turn_hover.png` | 188×188 |
| `btn_next_turn_normal.png` | 188×188 |
| `btn_next_turn_pressed.png` | 188×188 |
| `btn_next_turn_selected.png` | 188×188 |
| `bubble_step.png` | 32×32 |
| `card_neizheng_disabled.png` | 272×132 |
| `card_neizheng_hover.png` | 272×132 |
| `card_neizheng_normal.png` | 272×132 |
| `card_neizheng_pressed.png` | 272×132 |
| `card_neizheng_selected.png` | 272×132 |
| `city_badge_contested_hover.png` | 104×104 |
| `city_badge_contested_normal.png` | 104×104 |
| `city_badge_contested_selected.png` | 104×104 |
| `city_badge_jin_hover.png` | 104×104 |
| `city_badge_jin_normal.png` | 104×104 |
| `city_badge_jin_selected.png` | 104×104 |
| `city_badge_ming_hover.png` | 104×104 |
| `city_badge_ming_normal.png` | 104×104 |
| `city_badge_ming_selected.png` | 104×104 |
| `ending_scroll.png` | 1144×682 |
| `hud_chip_disabled.png` | 158×46 |
| `hud_chip_normal.png` | 158×46 |
| `icon_grain_64.png` | 64×64 |
| `icon_grain_96.png` | 96×96 |
| `icon_hold_64.png` | 64×64 |
| `icon_hold_96.png` | 96×96 |
| `icon_lianbing_64.png` | 64×64 |
| `icon_lianbing_96.png` | 96×96 |
| `icon_liaodong_64.png` | 64×64 |
| `icon_liaodong_96.png` | 96×96 |
| `icon_march_64.png` | 64×64 |
| `icon_march_96.png` | 96×96 |
| `icon_minxin_64.png` | 64×64 |
| `icon_minxin_96.png` | 96×96 |
| `icon_pressure_64.png` | 64×64 |
| `icon_pressure_96.png` | 96×96 |
| `icon_siege_64.png` | 64×64 |
| `icon_siege_96.png` | 96×96 |
| `icon_silver_64.png` | 64×64 |
| `icon_silver_96.png` | 96×96 |
| `icon_turn_64.png` | 64×64 |
| `icon_turn_96.png` | 96×96 |
| `icon_volume_64.png` | 64×64 |
| `icon_volume_96.png` | 96×96 |
| `icon_worldline_64.png` | 64×64 |
| `icon_worldline_96.png` | 96×96 |
| `panel_advisor.png` | 470×214 |
| `panel_frame_l.png` | 299×224 |
| `panel_frame_m.png` | 230×172 |
| `panel_frame_s.png` | 115×86 |
| `plaque_cinnabar_disabled.png` | 96×34 |
| `plaque_cinnabar_hover.png` | 96×34 |
| `plaque_cinnabar_normal.png` | 96×34 |
| `plaque_cinnabar_pressed.png` | 96×34 |
| `plaque_cinnabar_selected.png` | 96×34 |
| `ring_select.png` | 160×160 |
| `row_recommend_disabled.png` | 446×42 |
| `row_recommend_hover.png` | 446×42 |
| `row_recommend_normal.png` | 446×42 |
| `row_recommend_pressed.png` | 446×42 |
| `row_recommend_selected.png` | 446×42 |
| `stamp_draw.png` | 160×160 |
| `stamp_lose.png` | 160×160 |
| `stamp_win.png` | 160×160 |
| `tile_stat.png` | 180×66 |
