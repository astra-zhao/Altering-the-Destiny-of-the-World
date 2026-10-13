import type { StoryNode } from './types';

export const NODES: Record<string, StoryNode> = {
  N1: {
    id: 'N1',
    title: 'N1 · 登基夜',
    body:
      '天启崩逝，朱由检仓促继位。宫灯未稳，边报与朝争已同时压来。\n\n你是崇祯——这一夜，先动哪一步，将牵动往后整条世界线。',
    choices: [
      {
        id: 'A',
        text: '先稳朝堂，召对阁臣',
        effects: { deltas: { 朝堂信任: 8 } },
      },
      {
        id: 'B',
        text: '先问辽东军情，点名袁崇焕',
        effects: {
          deltas: { 辽东稳固: 5, 朝堂信任: -3 },
          setFlags: { 结交袁崇焕: true },
        },
      },
      {
        id: 'C',
        text: '先查库房与粮储',
        effects: {
          deltas: { 民心: 3 },
          setFlags: { 国库知底: true },
        },
      },
    ],
    next: 'N2',
  },
  N2: {
    id: 'N2',
    title: 'N2 · 边报入京',
    body:
      '八百里加急入京：后金压境，袁崇焕请饷请权。朝堂上有人主战、有人观望，也有人已在算计督师的下场。\n\n（短视频占位：边报递入午门的十五秒战报影像）',
    videoPlaceholder: '【短视频①占位】边报 / 战报 · 15–25 秒',
    choices: [
      {
        id: 'A',
        text: '准饷并授便宜行事',
        effects: {
          deltas: { 辽东稳固: 12, 国库: -10, 后金压力: -5 },
          ifFlagBonus: { flag: '结交袁崇焕', deltas: { 辽东稳固: 5 } },
        },
      },
      {
        id: 'B',
        text: '准饷但派监军同往',
        effects: {
          deltas: { 辽东稳固: 6, 朝堂信任: 5 },
          setFlags: { 袁信任微损: true },
        },
      },
      {
        id: 'C',
        text: '缓议，先内帑救急京畿',
        effects: {
          deltas: { 民心: 8, 国库: -5, 后金压力: 8, 辽东稳固: -5 },
        },
      },
    ],
    next: 'N3',
  },
  N3: {
    id: 'N3',
    title: 'N3 · 批红小关',
    body: '御案上压着五道奏折。同意、驳回或留中——每笔朱批都在挤兑国库、边防与人心。',
    choices: [],
    next: 'N4',
    kind: 'minigame',
  },
  N4: {
    id: 'N4',
    title: 'N4 · 袁崇焕生死',
    body:
      '反间与朝议汹汹。有人跪请寸磔督师，有人说杀袁即弃辽。午门外鼓声未歇——朱笔落处，便是一条新的世界线。\n\n（短视频②占位：朝审 / 物议 · 20–30 秒）',
    videoPlaceholder: '【短视频②占位】朝审 / 物议 · 20–30 秒',
    choices: [
      {
        id: 'A',
        text: '处死（史实向）',
        effects: {
          yuan: '已死',
          deltas: { 辽东稳固: -25, 后金压力: 15, 朝堂信任: 5, 世界线偏移: 5 },
        },
      },
      {
        id: 'B',
        text: '下狱但暂不杀',
        effects: {
          yuan: '存活但闲置',
          deltas: { 辽东稳固: -10, 朝堂信任: 8, 世界线偏移: 15 },
        },
      },
      {
        id: 'C',
        text: '赦免并复辽职',
        effects: {
          yuan: '存活且可用',
          deltas: { 辽东稳固: 15, 朝堂信任: -15, 世界线偏移: 35 },
          setFlags: { 宦官文官反弹: true },
        },
      },
      {
        id: 'D',
        text: '赦免但调离前线、改任京营',
        requireFlag: '结交袁崇焕',
        effects: {
          yuan: '存活且京营',
          deltas: { 辽东稳固: 5, 朝堂信任: -5, 世界线偏移: 25 },
        },
      },
    ],
    next: 'N5',
  },
  N5: {
    id: 'N5',
    title: 'N5 · 辽东一局',
    body: '三城布防对后金压力。兵力总和固定；袁的状态决定是否有袁部/弱支援。',
    choices: [],
    next: 'N6',
    kind: 'minigame',
  },
  N6: {
    id: 'N6',
    title: 'N6 · 内帑与民变',
    body:
      '京畿缺粮，催科与裁饷撕扯。街市谣传流民将至，户部与内廷互相推诿。\n\n（短视频③占位：民情 / 灾赈 · 15–25 秒）',
    videoPlaceholder: '【短视频③占位】民情 / 灾赈 · 15–25 秒',
    choices: [
      {
        id: 'A',
        text: '开海税补饷',
        effects: {
          deltas: { 国库: 15, 朝堂信任: -8, 世界线偏移: 10 },
          setFlags: { 开海税: true },
        },
      },
      {
        id: 'B',
        text: '强征加派',
        effects: {
          deltas: { 国库: 10, 民心: -15, 后金压力: 5 },
        },
      },
      {
        id: 'C',
        text: '发内帑赈灾并缓征',
        effects: {
          deltas: { 国库: -12, 民心: 15, 朝堂信任: 5 },
        },
      },
    ],
    next: 'N7',
  },
  N7: {
    id: 'N7',
    title: 'N7 · 终局抉择',
    body: '多方压力到临界。数值面板就在眼前——这一次总抉择，将裁定世界线停在哪一种结局。',
    choices: [],
    next: 'ending',
    kind: 'story',
  },
};


