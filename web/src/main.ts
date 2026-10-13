import './style.css';
import { NODES } from './content';
import {
  applyEffects,
  applyEffectsTreasuryAware,
  clearSave,
  createInitialState,
  loadState,
  saveState,
} from './engine';
import { MEMORIALS } from './memorials';
import { CITIES, TOTAL_TROOPS, applyBattleResult, resolveBattle, yuanSupport, type CityId } from './n5';
import { n7ChoiceTexts, resolveEnding, type Ending } from './endings';
import type { GameState, PiHongAction, StoryNode } from './types';

const app = document.querySelector<HTMLDivElement>('#app')!;

type Screen = 'title' | 'play' | 'n3' | 'n5' | 'n7' | 'ending' | 'stop';

let state: GameState = createInitialState();
let screen: Screen = 'title';
let showDebug = true;
let n3Index = 0;
let n3Msg = '';
let n5Alloc: Record<CityId, number> = { 宁远: 4, 锦州: 3, 山海关: 3 };
let n5Msg = '';
let lastEnding: Ending | null = null;

function visibleChoices(node: StoryNode) {
  return node.choices.filter((c) => !c.requireFlag || state.flags[c.requireFlag]);
}

function renderStats() {
  const items: [string, string | number][] = [
    ['辽东稳固', state.辽东稳固],
    ['朝堂信任', state.朝堂信任],
    ['民心', state.民心],
    ['国库', state.国库],
    ['后金压力', state.后金压力],
    ['世界线偏移', state.世界线偏移],
    ['袁崇焕', state.袁崇焕],
  ];
  return `<div class="stats">${items
    .map(([k, v]) => `<div class="stat">${k}<br><b>${v}</b></div>`)
    .join('')}</div>`;
}

function renderDebug() {
  if (!showDebug) return '';
  return `<pre class="debug">${JSON.stringify(
    {
      nodeId: state.nodeId,
      n3Result: state.n3Result ?? null,
      n5Result: state.n5Result ?? null,
      n3Index,
      vars: {
        辽东稳固: state.辽东稳固,
        朝堂信任: state.朝堂信任,
        民心: state.民心,
        国库: state.国库,
        后金压力: state.后金压力,
        袁崇焕: state.袁崇焕,
        世界线偏移: state.世界线偏移,
      },
      flags: state.flags,
      history: state.history,
      aiSideEvents: state.aiSideEvents,
    },
    null,
    2,
  )}</pre>`;
}

function bindCommon() {
  document.querySelector('#toggle-debug')?.addEventListener('click', () => {
    showDebug = !showDebug;
    render();
  });
  document.querySelector('#clear-save')?.addEventListener('click', () => {
    clearSave();
    state = createInitialState();
    n3Index = 0;
    n3Msg = '';
    screen = 'title';
    render();
  });
}

function enterNode(nodeId: string) {
  state.nodeId = nodeId;
  if (nodeId === 'N3') {
    n3Index = 0;
    n3Msg = '';
    screen = 'n3';
  } else if (nodeId === 'N5') {
    n5Alloc = { 宁远: 4, 锦州: 3, 山海关: 3 };
    n5Msg = '';
    screen = 'n5';
  } else if (nodeId === 'N7') {
    screen = 'n7';
  } else if (nodeId === 'ending') {
    lastEnding = resolveEnding(state);
    screen = 'ending';
  } else if (nodeId === 'gray_stop') {
    screen = 'stop';
  } else {
    screen = 'play';
  }
  saveState(state);
  render();
}

function finishN3(result: 'pass' | 'fail' | 'skip_ping') {
  state.n3Result = result;
  state.history = [...state.history, `N3:${result}`];
  enterNode('N4');
}

function renderTitle() {
  const hasSave = !!loadState();
  app.innerHTML = `
    <div class="card">
      <div class="row"><span class="badge">M0 灰盒 · Web</span><span class="badge">AI 支线：关</span></div>
      <h1>改命：天下</h1>
      <p class="muted">崇祯线垂直切片。可玩 N1→N7 全链路与结局结算。数值对齐 M0 大纲；调试面板供 Andy 断言。</p>
      <button class="btn primary" id="start">开始 · 崇祯朱由检</button>
      ${hasSave ? '<button class="btn" id="continue">读取存档</button>' : ''}
      <div class="toolbar" style="margin-top:14px">
        <button id="toggle-debug">调试面板</button>
        <button id="clear-save">清空存档</button>
      </div>
      ${renderDebug()}
    </div>`;
  document.querySelector('#start')?.addEventListener('click', () => {
    state = createInitialState();
    n3Index = 0;
    n3Msg = '';
    enterNode('N1');
  });
  document.querySelector('#continue')?.addEventListener('click', () => {
    const s = loadState();
    if (s) {
      state = s;
      if (state.nodeId === 'N3') {
        n3Index = 0;
        screen = 'n3';
      } else if (state.nodeId === 'N5') {
        n5Alloc = { 宁远: 4, 锦州: 3, 山海关: 3 };
        screen = 'n5';
      } else if (state.nodeId === 'N7') screen = 'n7';
      else if (state.nodeId === 'ending') {
        lastEnding = resolveEnding(state);
        screen = 'ending';
      } else if (state.nodeId === 'gray_stop') screen = 'stop';
      else screen = 'play';
      render();
    }
  });
  bindCommon();
}

function renderPlay() {
  const node = NODES[state.nodeId];
  if (!node || node.kind === 'minigame') {
    if (state.nodeId === 'N3') {
      screen = 'n3';
      render();
      return;
    }
    if (state.nodeId === 'N5') {
      screen = 'n5';
      render();
      return;
    }
    screen = 'stop';
    render();
    return;
  }
  const choices = visibleChoices(node);
  app.innerHTML = `
    <div class="card">
      <div class="toolbar">
        <button id="toggle-debug">调试面板</button>
        <button id="to-title">标题</button>
        <button id="clear-save">清空存档</button>
      </div>
      <div class="row"><span class="badge">${node.id}</span><span class="badge">世界线 ${state.世界线偏移}</span></div>
      <h2>${node.title}</h2>
      ${node.videoPlaceholder ? `<div class="video-slot">${node.videoPlaceholder}</div>` : ''}
      <p class="muted">${node.body}</p>
      ${renderStats()}
      <div id="choices">
        ${choices
          .map(
            (c) =>
              `<button class="btn" data-choice="${c.id}"><b>${c.id}.</b> ${c.text}</button>`,
          )
          .join('')}
      </div>
      ${renderDebug()}
    </div>`;

  document.querySelectorAll<HTMLButtonElement>('[data-choice]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const id = btn.dataset.choice!;
      const choice = choices.find((c) => c.id === id);
      if (!choice) return;
      state = applyEffects(state, choice.effects);
      state.history = [...state.history, `${node.id}:${id}`];
      enterNode(node.next);
    });
  });
  document.querySelector('#to-title')?.addEventListener('click', () => {
    screen = 'title';
    render();
  });
  bindCommon();
}

function renderN3() {
  const m = MEMORIALS[n3Index];
  const progress = `${Math.min(n3Index + 1, MEMORIALS.length)} / ${MEMORIALS.length}`;
  app.innerHTML = `
    <div class="card">
      <div class="toolbar">
        <button id="toggle-debug">调试面板</button>
        <button id="to-title">标题</button>
        <button id="clear-save">清空存档</button>
      </div>
      <div class="row"><span class="badge">N3 · 批红</span><span class="badge">奏折 ${progress}</span></div>
      <h2>N3 · 批红小关</h2>
      <p class="muted">限批五道。通关：批完且国库显示 ≥ 0。也可跳过（按「平」结算进下一节）。</p>
      ${renderStats()}
      ${n3Msg ? `<p class="muted" style="color:#e2b27a">${n3Msg}</p>` : ''}
      ${
        m
          ? `<div class="video-slot" style="text-align:left">
              <b>${m.title}</b><br/>${m.summary}
            </div>
            <div class="row">
              <button class="btn" style="flex:1" data-act="同意">同意</button>
              <button class="btn" style="flex:1" data-act="驳回">驳回</button>
              <button class="btn" style="flex:1" data-act="留中">留中</button>
            </div>`
          : ''
      }
      <button class="btn" id="n3-skip">跳过本关（平）</button>
      ${renderDebug()}
    </div>`;

  document.querySelectorAll<HTMLButtonElement>('[data-act]').forEach((btn) => {
    btn.addEventListener('click', () => {
      if (!m) return;
      const act = btn.dataset.act as PiHongAction;
      let effect = m.effects[act];
      if (act !== m.ideal) {
        effect = {
          deltas: {
            ...(effect.deltas ?? {}),
            ...(m.wrongPenalty.deltas ?? {}),
          },
          setFlags: { ...(effect.setFlags ?? {}), ...(m.wrongPenalty.setFlags ?? {}) },
        };
      }
      const { state: next, treasuryWouldBreak } = applyEffectsTreasuryAware(state, effect);
      state = next;
      state.history = [...state.history, `N3:${m.id}:${act}`];
      n3Index += 1;

      if (treasuryWouldBreak) {
        n3Msg = `「${m.title}」会使国库跌破 0（已夹紧为 ${state.国库}）。本关不能「通关」，请跳过（平）或重开。`;
        state.n3Result = 'fail';
        saveState(state);
        render();
        return;
      }

      n3Msg =
        act === m.ideal
          ? `已批「${m.title}」· ${act}`
          : `已批「${m.title}」· ${act}（非理想，有轻微惩罚）`;

      if (n3Index >= MEMORIALS.length) {
        if (state.国库 >= 0) finishN3('pass');
        else {
          n3Msg = '五折已批完，但国库显示 < 0，不能通关。请跳过（平）或重开。';
          state.n3Result = 'fail';
          saveState(state);
          render();
        }
        return;
      }
      saveState(state);
      render();
    });
  });

  document.querySelector('#n3-skip')?.addEventListener('click', () => {
    // 跳过=平（不改变量）。若已因国库跌破标 fail，保留 n3Result=fail，并追加跳过痕迹
    if (state.n3Result === 'fail') {
      state.history = [...state.history, 'N3:fail', 'N3:skip_ping'];
      enterNode('N4');
      return;
    }
    finishN3('skip_ping');
  });
  document.querySelector('#to-title')?.addEventListener('click', () => {
    screen = 'title';
    render();
  });
  bindCommon();
}


function renderN5() {
  const support = yuanSupport(state);
  const supportLabel =
    support === 'full' ? '袁部·满效力' : support === 'weak' ? '京营·弱支援' : state.袁崇焕 === '已死' ? '无袁部·加难' : '无袁部';
  const used = CITIES.reduce((s, c) => s + n5Alloc[c], 0);
  const left = TOTAL_TROOPS - used;
  app.innerHTML = `
    <div class="card">
      <div class="toolbar">
        <button id="toggle-debug">调试面板</button>
        <button id="to-title">标题</button>
        <button id="clear-save">清空存档</button>
      </div>
      <div class="row"><span class="badge">N5 · 调兵</span><span class="badge">${supportLabel}</span><span class="badge">袁：${state.袁崇焕}</span></div>
      <h2>N5 · 辽东一局</h2>
      <p class="muted">将 ${TOTAL_TROOPS} 点兵力分到三城（总和必须为 ${TOTAL_TROOPS}）。胜：后金-12 辽东+10；负：后金+10 民心-8；平：小幅波动。</p>
      ${renderStats()}
      ${n5Msg ? `<p class="muted" style="color:#e2b27a">${n5Msg}</p>` : ''}
      <div class="stats">
        ${CITIES.map(
          (c) => `<div class="stat">${c}<br>
            <button data-city="${c}" data-d="-1">−</button>
            <b id="v-${c}">${n5Alloc[c]}</b>
            <button data-city="${c}" data-d="1">＋</button>
          </div>`,
        ).join('')}
      </div>
      <p class="muted">已分配 ${used} / ${TOTAL_TROOPS}（剩余 ${left}）</p>
      <button class="btn primary" id="n5-fight" ${used !== TOTAL_TROOPS ? 'disabled' : ''}>开战</button>
      <button class="btn" id="n5-skip">跳过本关（平）</button>
      ${renderDebug()}
    </div>`;

  document.querySelectorAll<HTMLButtonElement>('[data-city]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const city = btn.dataset.city as CityId;
      const d = Number(btn.dataset.d);
      const next = n5Alloc[city] + d;
      if (next < 0) return;
      const newUsed = used - n5Alloc[city] + next;
      if (newUsed > TOTAL_TROOPS) return;
      n5Alloc = { ...n5Alloc, [city]: next };
      render();
    });
  });
  document.querySelector('#n5-fight')?.addEventListener('click', () => {
    if (used !== TOTAL_TROOPS) {
      n5Msg = '兵力总和必须为 10';
      render();
      return;
    }
    const result = resolveBattle(state, n5Alloc);
    state = applyBattleResult(state, result);
    state.history = [...state.history, `N5:${result}`];
    enterNode('N6');
  });
  document.querySelector('#n5-skip')?.addEventListener('click', () => {
    state = applyBattleResult(state, 'draw');
    state.n5Result = 'skip';
    state.history = [...state.history, 'N5:skip'];
    enterNode('N6');
  });
  document.querySelector('#to-title')?.addEventListener('click', () => {
    screen = 'title';
    render();
  });
  bindCommon();
}


function applyN7(choiceId: string) {
  if (choiceId === 'A') {
    const ok = state.辽东稳固 >= 50 && state.后金压力 <= 50;
    if (ok) {
      state = applyEffects(state, {
        deltas: { 辽东稳固: 5, 世界线偏移: 10, 朝堂信任: -5 },
        setFlags: { 勤王成功: true },
      });
    } else {
      state = applyEffects(state, {
        deltas: { 后金压力: 8, 民心: -5, 辽东稳固: -5, 世界线偏移: 5 },
      });
    }
  } else if (choiceId === 'B') {
    state = applyEffects(state, {
      deltas: { 朝堂信任: 5, 后金压力: 3, 世界线偏移: 5, 民心: 3 },
    });
  } else {
    state = applyEffects(state, {
      deltas: { 朝堂信任: 8, 辽东稳固: -5, 后金压力: -5, 世界线偏移: 8 },
    });
  }
  state.history = [...state.history, `N7:${choiceId}`];
  state.nodeId = 'ending';
  lastEnding = resolveEnding(state);
  saveState(state);
  screen = 'ending';
  render();
}

function renderN7() {
  const choices = n7ChoiceTexts(state);
  app.innerHTML = `
    <div class="card">
      <div class="toolbar">
        <button id="toggle-debug">调试面板</button>
        <button id="to-title">标题</button>
        <button id="clear-save">清空存档</button>
      </div>
      <div class="row"><span class="badge">N7</span><span class="badge">世界线 ${state.世界线偏移}</span></div>
      <h2>N7 · 终局抉择</h2>
      <p class="muted">多方压力到临界。回顾面板后，做出最后一次总抉择。</p>
      ${renderStats()}
      <div id="choices">
        ${choices
          .map((c) => `<button class="btn" data-n7="${c.id}"><b>${c.id}.</b> ${c.text}</button>`)
          .join('')}
      </div>
      ${renderDebug()}
    </div>`;
  document.querySelectorAll<HTMLButtonElement>('[data-n7]').forEach((btn) => {
    btn.addEventListener('click', () => applyN7(btn.dataset.n7!));
  });
  document.querySelector('#to-title')?.addEventListener('click', () => {
    screen = 'title';
    render();
  });
  bindCommon();
}

function worldLineBar(v: number) {
  const pct = Math.max(0, Math.min(100, v));
  return `<div style="margin:12px 0;background:#2a211c;border-radius:8px;overflow:hidden;border:1px solid var(--line)">
    <div style="width:${pct}%;background:linear-gradient(90deg,#c45c26,#e2b27a);padding:6px 10px;font-size:12px">世界线偏移 ${pct}</div>
  </div>`;
}

function renderEnding() {
  const e = lastEnding ?? resolveEnding(state);
  lastEnding = e;
  app.innerHTML = `
    <div class="card">
      <div class="toolbar">
        <button id="toggle-debug">调试面板</button>
        <button id="clear-save">清空存档</button>
      </div>
      <div class="row"><span class="badge">结局 ${e.id}</span><span class="badge">${e.type}</span></div>
      <h2>${e.title}</h2>
      <p class="muted">${e.blurb}</p>
      ${worldLineBar(state.世界线偏移)}
      ${renderStats()}
      <h3 style="margin-bottom:6px">史实对照</h3>
      <p class="muted">${e.historyContrast}</p>
      <h3 style="margin-bottom:6px">你改写了什么</h3>
      <ul class="muted">${e.bullets.map((b) => `<li>${b}</li>`).join('')}</ul>
      <p class="muted">路径：${state.history.join(' → ')}</p>
      <button class="btn primary" id="restart">再开一局</button>
      <button class="btn" id="to-title">回标题</button>
      ${renderDebug()}
    </div>`;
  document.querySelector('#restart')?.addEventListener('click', () => {
    state = createInitialState();
    lastEnding = null;
    n3Index = 0;
    n3Msg = '';
    enterNode('N1');
  });
  document.querySelector('#to-title')?.addEventListener('click', () => {
    screen = 'title';
    render();
  });
  bindCommon();
}

function renderStop() {
  const n3 = state.n3Result ? `N3 结算：${state.n3Result}` : 'N3 未结算';
  app.innerHTML = `
    <div class="card">
      <div class="toolbar">
        <button id="toggle-debug">调试面板</button>
        <button id="clear-save">清空存档</button>
      </div>
      <h2>灰盒暂止：N7 开发中</h2>
      <p class="muted">已完成至 N6。${n3}。下一刀接终局抉择（N7）。</p>
      ${renderStats()}
      <p class="muted">选择路径：${state.history.join(' → ') || '无'}</p>
      <button class="btn primary" id="restart">再开一局</button>
      <button class="btn" id="to-title">回标题</button>
      ${renderDebug()}
    </div>`;
  document.querySelector('#restart')?.addEventListener('click', () => {
    state = createInitialState();
    n3Index = 0;
    n3Msg = '';
    enterNode('N1');
  });
  document.querySelector('#to-title')?.addEventListener('click', () => {
    screen = 'title';
    render();
  });
  bindCommon();
}

function render() {
  if (screen === 'title') renderTitle();
  else if (screen === 'n3') renderN3();
  else if (screen === 'n5') renderN5();
  else if (screen === 'n7') renderN7();
  else if (screen === 'ending') renderEnding();
  else if (screen === 'stop') renderStop();
  else renderPlay();
}

render();
