export type YuanStatus = '存活且可用' | '存活但闲置' | '存活且京营' | '已死';

export interface GameFlags {
  结交袁崇焕: boolean;
  清洗阉余: boolean;
  开海税: boolean;
  勤王成功: boolean;
  国库知底: boolean;
  袁信任微损: boolean;
  宦官文官反弹: boolean;
}

export interface GameState {
  辽东稳固: number;
  朝堂信任: number;
  民心: number;
  国库: number;
  后金压力: number;
  袁崇焕: YuanStatus;
  世界线偏移: number;
  flags: GameFlags;
  nodeId: string;
  history: string[];
  aiSideEvents: boolean;
  n3Result?: 'pass' | 'fail' | 'skip_ping';
  n5Result?: 'win' | 'lose' | 'draw' | 'skip';
}

export type StatKey =
  | '辽东稳固'
  | '朝堂信任'
  | '民心'
  | '国库'
  | '后金压力'
  | '世界线偏移';

export interface ChoiceEffect {
  deltas?: Partial<Record<StatKey, number>>;
  yuan?: YuanStatus;
  setFlags?: Partial<GameFlags>;
  ifFlagBonus?: { flag: keyof GameFlags; deltas: Partial<Record<StatKey, number>> };
}

export interface Choice {
  id: string;
  text: string;
  requireFlag?: keyof GameFlags;
  effects: ChoiceEffect;
}

export interface StoryNode {
  id: string;
  title: string;
  body: string;
  videoPlaceholder?: string;
  choices: Choice[];
  next: string | 'gray_stop' | 'ending';
  kind?: 'story' | 'minigame';
}

export type PiHongAction = '同意' | '驳回' | '留中';

export interface Memorial {
  id: string;
  title: string;
  summary: string;
  ideal: PiHongAction;
  effects: Record<PiHongAction, ChoiceEffect>;
  wrongPenalty: ChoiceEffect;
}
