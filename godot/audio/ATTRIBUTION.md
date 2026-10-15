# 四条可替换曲目

播放器只认这四个文件名。要换曲，覆盖同名 `.ogg`，在 Godot 4.6.3 的导入里保持 **Loop** 打开（`oggvorbisstr`，`loop=true`，`loop_offset=0`）。代码里播放类型固定为 **Stream**，不要改成 Sample。

授权页面于 2026-10-15 再次打开核对。四首都是页面上写明的 CC0，没有改用 CC-BY 备选。

| 轨 | 文件 | 曲目 | 作者 | 授权页面 |
| --- | --- | --- | --- | --- |
| 地图 | `map.ogg` | Lotus Pond（循环版） | BiteMe Games | <https://bitemegames.itch.io/chinese-game-music> |
| 简战 | `battle.ogg` | Dragon Dance（循环版） | BiteMe Games | 同上，Chinese Game Music |
| 剧情 | `story.ogg` | Orien | Tozan | <https://opengameart.org/content/orien> |
| 结局 | `ending.ogg` | Floating Lanterns | John Bartmann | <https://freemusicarchive.org/music/John_Bartmann/chinese-valentine/floating-lanterns/> |

itch 页面写的是 Creative Commons Zero，商业可用、不要求署名，并写明 “You cannot resell this edit.” 本工程是游戏，不是转售这个素材包。Orien 页面的 Copyright/Attribution Notice 是 CC0，文件为 `orien_2.ogg`。Floating Lanterns 页面链到 CC0 1.0 Universal。

没有采用的备选：Oriental Somber（Tozan，<https://opengameart.org/content/oriental-somber>，页面为 CC0）。原因见 `godot/README.md` 的曲目一节。

## 界面切图（v1.2，2026-10-15）

手绘类图像（面板、城印、印章、图标、谋士头像、卷轴、三张背景）由 Grok Bot 内置图像生成在 **2026-10-15** 生成，Alice 再用 PIL 做抠图、缩放、九宫格和状态着色。没有混入第三方贴图。版权归属和各平台对 AI 素材的披露要求，上架前再统一核对。

字体是 Noto Serif CJK SC Bold、Noto Sans CJK SC Regular / Bold 的 910 字子集（SIL OFL 1.1），文件在 `assets/ui/`，许可全文是 `assets/ui/OFL.txt`。

切图清单、边距和这份说明的细目也在 `assets/ui/README-切图清单.md`、`assets/ui/ATTRIBUTION.md`。

结局页底部署名只用结局曲：配乐：Floating Lanterns · John Bartmann · CC0。地图里的「署名」写全四首、字体和上述美术来源。
