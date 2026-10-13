import type { ChoiceEffect, GameFlags, GameState, StatKey } from './types';

const SAVE_KEY = 'gaiming-tianxia-m0';

const defaultFlags = (): GameFlags => ({
  结交袁崇焕: false,
  清洗阉余: false,
  开海税: false,
  勤王成功: false,
  国库知底: false,
  袁信任微损: false,
  宦官文官反弹: false,
});

export function createInitialState(): GameState {
  return {
    辽东稳固: 35,
    朝堂信任: 40,
    民心: 30,
    国库: 25,
    后金压力: 55,
    袁崇焕: '存活且可用',
    世界线偏移: 0,
    flags: defaultFlags(),
    nodeId: 'N1',
    history: [],
    aiSideEvents: false,
  };
}

function clamp(n: number, min = 0, max = 100) {
  return Math.max(min, Math.min(max, n));
}

export function applyEffects(state: GameState, effects: ChoiceEffect): GameState {
  const next: GameState = {
    ...state,
    flags: { ...state.flags },
    history: [...state.history],
  };

  if (effects.deltas) {
    for (const [k, v] of Object.entries(effects.deltas) as [StatKey, number][]) {
      if (typeof v !== 'number') continue;
      next[k] = clamp(next[k] + v);
    }
  }

  if (effects.yuan) next.袁崇焕 = effects.yuan;

  if (effects.setFlags) {
    next.flags = { ...next.flags, ...effects.setFlags };
  }

  if (effects.ifFlagBonus && next.flags[effects.ifFlagBonus.flag]) {
    for (const [k, v] of Object.entries(effects.ifFlagBonus.deltas) as [StatKey, number][]) {
      if (typeof v !== 'number') continue;
      next[k] = clamp(next[k] + v);
    }
  }

  return next;
}

/** 返回应用后状态，以及国库在夹紧前是否会 < 0 */
export function applyEffectsTreasuryAware(
  state: GameState,
  effects: ChoiceEffect,
): { state: GameState; treasuryWouldBreak: boolean } {
  let projected = state.国库;
  if (effects.deltas?.国库) projected += effects.deltas.国库;
  if (
    effects.ifFlagBonus &&
    state.flags[effects.ifFlagBonus.flag] &&
    effects.ifFlagBonus.deltas.国库
  ) {
    projected += effects.ifFlagBonus.deltas.国库;
  }
  const treasuryWouldBreak = projected < 0;
  return { state: applyEffects(state, effects), treasuryWouldBreak };
}

export function saveState(state: GameState) {
  localStorage.setItem(SAVE_KEY, JSON.stringify(state));
}

export function loadState(): GameState | null {
  const raw = localStorage.getItem(SAVE_KEY);
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw) as GameState;
    parsed.flags = { ...defaultFlags(), ...parsed.flags };
    return parsed;
  } catch {
    return null;
  }
}

export function clearSave() {
  localStorage.removeItem(SAVE_KEY);
}
