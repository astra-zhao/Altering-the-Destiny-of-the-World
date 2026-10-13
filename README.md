# 《改命：天下》 / Altering the Destiny of the World

崇祯线 M0 灰盒（N1–N7 + 结局）。Vite + TypeScript，可在本地直接游玩。

Chongzhen-line M0 greybox (N1–N7 plus endings). Vite + TypeScript; playable locally.

## 本地运行 / Run locally

```bash
git clone https://github.com/astra-zhao/Altering-the-Destiny-of-the-World.git
cd Altering-the-Destiny-of-the-World/web
npm install
npm run dev
```

终端会打印本地地址，在浏览器中打开即可。

Open the local URL printed in the terminal.

说明 / Notes:

- AI 支线默认关闭。 / AI side-branches are off by default.
- 调试面板显示数值。 / The debug panel shows stats.

产品与测试文档在仓库根目录：`M0-崇祯线节点大纲.md`、`M0-测试用例表.md`。游戏源码在 `web/`。

Product and QA docs are at the repo root (`M0-崇祯线节点大纲.md`, `M0-测试用例表.md`). Game source is under `web/`.

## 构建 / Build

```bash
cd web
npm run build
```
