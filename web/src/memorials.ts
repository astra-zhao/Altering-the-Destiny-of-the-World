import type { Memorial } from './types';

/** N3 五道奏折：同意/驳回/留中；ideal 外算轻微错批惩罚 */
export const MEMORIALS: Memorial[] = [
  {
    id: 'M1',
    title: '发袁饷',
    summary: '辽东催饷至急。准发则边防可稳，国库必紧。',
    ideal: '同意',
    effects: {
      同意: { deltas: { 国库: -8, 辽东稳固: 8 } },
      驳回: { deltas: { 辽东稳固: -5, 后金压力: 3 } },
      留中: { deltas: { 辽东稳固: -2 } },
    },
    wrongPenalty: { deltas: { 朝堂信任: -2 } },
  },
  {
    id: 'M2',
    title: '裁冗员',
    summary: '户部请裁京中冗员省饷。能省钱，必触朝堂利益。',
    ideal: '同意',
    effects: {
      同意: { deltas: { 国库: 6, 朝堂信任: -4 } },
      驳回: { deltas: { 朝堂信任: 2 } },
      留中: { deltas: { 朝堂信任: -1 } },
    },
    wrongPenalty: { deltas: { 民心: -1 } },
  },
  {
    id: 'M3',
    title: '赈灾',
    summary: '京畿附近报灾。赈则安民，不赈则流民。',
    ideal: '同意',
    effects: {
      同意: { deltas: { 国库: -6, 民心: 10 } },
      驳回: { deltas: { 民心: -8 } },
      留中: { deltas: { 民心: -2 } },
    },
    wrongPenalty: { deltas: { 朝堂信任: -1 } },
  },
  {
    id: 'M4',
    title: '宦官安置',
    summary: '内廷请安置闲散宦官。处置失当，朝堂与民心两伤。',
    ideal: '驳回',
    effects: {
      同意: { deltas: { 朝堂信任: -3, 民心: 2 } },
      驳回: { deltas: { 朝堂信任: 4 }, setFlags: { 清洗阉余: true } },
      留中: { deltas: { 朝堂信任: 1 } },
    },
    wrongPenalty: { deltas: { 民心: -2 } },
  },
  {
    id: 'M5',
    title: '科举名额',
    summary: '礼部请增乡试名额以收士心。花费不大，却能动摇门第平衡。',
    ideal: '留中',
    effects: {
      同意: { deltas: { 朝堂信任: 5, 国库: -3, 民心: 2 } },
      驳回: { deltas: { 朝堂信任: -4 } },
      留中: { deltas: { 朝堂信任: 2 } },
    },
    wrongPenalty: { deltas: { 朝堂信任: -2 } },
  },
];

/** 跳过 = 平：不改核心变量 */
export const N3_SKIP_PING = { deltas: {} as const };
