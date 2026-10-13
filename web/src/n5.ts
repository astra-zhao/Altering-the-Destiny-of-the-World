import type { GameState } from './types';

export type CityId = '宁远' | '锦州' | '山海关';

export const CITIES: CityId[] = ['宁远', '锦州', '山海关'];
export const TOTAL_TROOPS = 10;

export function yuanSupport(state: GameState): 'full' | 'weak' | 'none' {
  if (state.袁崇焕 === '存活且可用') return 'full';
  if (state.袁崇焕 === '存活且京营') return 'weak';
  return 'none';
}

/** 简易胜负：玩家分配 vs 压力需求；袁支援修正阈值 */
export function resolveBattle(
  state: GameState,
  alloc: Record<CityId, number>,
): 'win' | 'lose' | 'draw' {
  const sum = CITIES.reduce((s, c) => s + (alloc[c] ?? 0), 0);
  if (sum !== TOTAL_TROOPS) throw new Error('兵力总和必须为 10');

  // 后金压力越高需求越高；基线每城需要 floor(压力/25) 左右
  const pressure = state.后金压力;
  const baseNeed = Math.max(2, Math.floor(pressure / 22)); // ~2–4
  const needs: Record<CityId, number> = {
    宁远: baseNeed,
    锦州: baseNeed + 1,
    山海关: Math.max(2, baseNeed - 1),
  };

  const support = yuanSupport(state);
  let bonus = 0;
  if (support === 'full') bonus = 2; // 满效力袁部
  else if (support === 'weak') bonus = 1; // 京营弱支援
  if (state.袁崇焕 === '已死') {
    // 已死加难：每城需求 +1
    for (const c of CITIES) needs[c] += 1;
  }

  let held = 0;
  for (const c of CITIES) {
    const power = (alloc[c] ?? 0) + (c === '宁远' ? bonus : Math.floor(bonus / 2));
    if (power >= needs[c]) held += 1;
  }

  if (held >= 3) return 'win';
  if (held === 2) return 'draw';
  return 'lose';
}

export function applyBattleResult(state: GameState, result: 'win' | 'lose' | 'draw'): GameState {
  const next = { ...state, flags: { ...state.flags }, history: [...state.history] };
  if (result === 'win') {
    next.后金压力 = Math.max(0, next.后金压力 - 12);
    next.辽东稳固 = Math.min(100, next.辽东稳固 + 10);
  } else if (result === 'lose') {
    next.后金压力 = Math.min(100, next.后金压力 + 10);
    next.民心 = Math.max(0, next.民心 - 8);
  } else {
    next.后金压力 = Math.min(100, Math.max(0, next.后金压力 + 2));
    next.辽东稳固 = Math.min(100, Math.max(0, next.辽东稳固 + 2));
  }
  next.n5Result = result;
  return next;
}
