import type { GameState } from './types';

export type EndingId = '甲' | '乙' | '丙' | '丁';

export interface Ending {
  id: EndingId;
  title: string;
  type: string;
  blurb: string;
  historyContrast: string;
  bullets: string[];
}

/** 优先级：甲 > 乙 > 丁 > 丙(兜底)。丁必须在丙兜底前，否则永不可达。 */
export function resolveEnding(state: GameState): Ending {
  const yuanAlive = state.袁崇焕 !== '已死';

  if (
    yuanAlive &&
    state.辽东稳固 >= 60 &&
    state.后金压力 <= 40 &&
    state.民心 >= 45 &&
    state.世界线偏移 >= 40
  ) {
    return {
      id: '甲',
      title: '甲 · 中兴微光',
      type: '中兴向',
      blurb: '边防未塌，民心未散。你没有一步登天，但明朝多了一段本可能失去的喘息。',
      historyContrast:
        '史实里崇祯朝在内忧外患中走向覆灭；此线袁部未绝、辽东仍可战，世界线已明显偏航。',
      bullets: buildBullets(state, [
        '袁崇焕未走史实末路，辽东仍有战力可依',
        `世界线偏移 ${state.世界线偏移}：关键抉择叠出中兴门槛`,
        state.flags.开海税 ? '开海税补饷，财政多了一条活路' : '靠赈与节流硬撑过了最险的民变口',
      ]),
    };
  }

  if ((state.辽东稳固 >= 40 || state.民心 >= 50) && state.国库 >= 20) {
    return {
      id: '乙',
      title: '乙 · 残局续命',
      type: '残局向',
      blurb: '盛世谈不上，但京畿与边防还没一起塌。你改的是崩法，不是立刻改成大同。',
      historyContrast: '史实加速滑向绝境；此线至少拖住了一次总崩溃，留下续命的残局。',
      bullets: buildBullets(state, [
        state.辽东稳固 >= 40 ? '辽东尚未崩盘，争得了时间' : '民心托住了京畿，未先溃于内',
        `国库 ${state.国库}，尚能周转一季粮饷`,
        '未达中兴阈值，但已偏离最坏史实轨道',
      ]),
    };
  }

  if (state.民心 <= 15 || state.国库 <= 5) {
    return {
      id: '丁',
      title: '丁 · 另途崩解',
      type: '残局变体',
      blurb: '外患未至，内乱已先至。你避开了一条旧死法，却走进另一条崩法。',
      historyContrast: '史实多言外患与朝争；此线是民心/财政先见底，崩在内部。',
      bullets: buildBullets(state, [
        state.民心 <= 15 ? `民心仅 ${state.民心}，京畿先乱` : `国库仅 ${state.国库}，粮饷先绝`,
        '改写未带来生路，只换了崩溃的入口',
        '世界线偏了，却偏向更深的黑',
      ]),
    };
  }

  // 丙：史实向或兜底
  return {
    id: '丙',
    title: '丙 · 史实沉响',
    type: '史实向',
    blurb:
      state.袁崇焕 === '已死'
        ? '督师已死，辽事更危。鼓声停处，仍是熟悉的沉响。'
        : '条件未够改命。你走完了一局，世界线仍沉在史实的阴影里。',
    historyContrast:
      '接近史实轨迹：袁崇焕案与边防崩坏互为因果，中兴的门没有打开。',
    bullets: buildBullets(state, [
      state.袁崇焕 === '已死' ? '处死袁崇焕，辽东信任崩塌' : '关键阈值未齐，改写力度不足',
      `辽东 ${state.辽东稳固} / 后金压力 ${state.后金压力}`,
      '结算落入史实沉响（兜底）',
    ]),
  };
}

function buildBullets(state: GameState, base: string[]): string[] {
  const out = [...base];
  while (out.length < 3) out.push(`世界线偏移 ${state.世界线偏移}`);
  return out.slice(0, 3);
}

export function n7ChoiceTexts(state: GameState): { id: string; text: string }[] {
  const canQinWang = state.辽东稳固 >= 50 && state.后金压力 <= 50;
  return [
    {
      id: 'A',
      text: canQinWang
        ? '倾国勤王、御驾北望（边防与压力允许）'
        : '倾国勤王、御驾北望（条件未足，风险极高）',
    },
    {
      id: 'B',
      text:
        state.民心 < 30
          ? '固守京畿、以拖待变（民心不稳，只能死守）'
          : '固守京畿、以拖待变',
    },
    {
      id: 'C',
      text: state.flags.开海税
        ? '议和缓兵、先安内部（有海税底气，略从容）'
        : '议和缓兵、先安内部',
    },
  ];
}
