// lib/models/story_data.dart
// ストーリー演出用データモデル

enum StoryType {
  prologue,           // プロローグ（初回起動）
  characterRelease,   // 棋霊解放セリフ
  stageAdvance,       // 昇段予告
  worldTransition,    // 世界移行
  ending,             // エンディング選択
  hint,               // チラ見せ
}

class StoryEvent {
  /// ストーリーイベントの一意なキー
  final String storyKey;

  /// イベントのタイプ
  final StoryType type;

  /// 表示するテキスト
  final String title;
  final String? description;

  /// 表示時間（秒）。nullなら手動スキップまで
  final Duration? displayDuration;

  /// 背景色（16進数文字列）
  final String? backgroundColor;

  /// キャラクターID（該当する場合）
  final String? characterId;

  /// このイベント表示済みかを SharedPrefs に保存するキー
  String get sharedPrefKey => 'story_shown_$storyKey';

  StoryEvent({
    required this.storyKey,
    required this.type,
    required this.title,
    this.description,
    this.displayDuration,
    this.backgroundColor,
    this.characterId,
  });
}

// ===== ストーリーイベント定義 =====

/// プロローグ（初回起動）
final prologue = StoryEvent(
  storyKey: 'prologue',
  type: StoryType.prologue,
  title: '...聞こえるか？',
  description: '''
我々は長い間、力を奪われてきた

棋霊と通じる者よ──助けに来てくれ
''',
  displayDuration: Duration(seconds: 15),
  backgroundColor: '#F5F5F5',
);

// ===== 入門棋霊の解放セリフ =====

final characterReleaseDialogues = {
  'speed': StoryEvent(
    storyKey: 'release_speed',
    type: StoryType.characterRelease,
    title: '速⚡️疾風',
    description: '君の速さ...本物だ。共に行こう',
    displayDuration: Duration(seconds: 5),
    characterId: 'speed',
  ),
  'guard': StoryEvent(
    storyKey: 'release_guard',
    type: StoryType.characterRelease,
    title: '守🛡️盤石',
    description: 'この守りを越えた者は久しぶりだ',
    displayDuration: Duration(seconds: 5),
    characterId: 'guard',
  ),
  'balance': StoryEvent(
    storyKey: 'release_balance',
    type: StoryType.characterRelease,
    title: '正⚖️均衡',
    description: 'バランスが取れてきた。次へ進め',
    displayDuration: Duration(seconds: 5),
    characterId: 'balance',
  ),
};

// ===== 昇段時の予告 =====

final stageAdvanceHints = {
  1: StoryEvent(
    storyKey: 'advance_1st_dan',
    type: StoryType.stageAdvance,
    title: '初段達成',
    description: '''
入門棋霊3体：「君は強くなった」

「だが、地下に何かがいる」

「力を奪う者が...」

第二世界：地下帝国 解放
''',
    displayDuration: Duration(seconds: 15),
    backgroundColor: '#F5F5F5',
  ),
  4: StoryEvent(
    storyKey: 'advance_4th_dan',
    type: StoryType.stageAdvance,
    title: '四段達成',
    description: '''
冥王が崩れ落ちる

「...この支配は、ずっと昔から続いている...」

真実は、過去にある

第三世界：過去 解放
''',
    displayDuration: Duration(seconds: 15),
    backgroundColor: '#F5F5F5',
  ),
  7: StoryEvent(
    storyKey: 'advance_7th_dan',
    type: StoryType.stageAdvance,
    title: '七段達成',
    description: '''
過去の悪い棋霊たちが光に変わる

「...全ての元凶は、天界にいる...」

全ての始まりへ

最終世界：天界 解放
''',
    displayDuration: Duration(seconds: 15),
    backgroundColor: '#F5F5F5',
  ),
};

// ===== 世界移行時ブリッジ =====

final worldTransitions = {
  'world_2_enter': StoryEvent(
    storyKey: 'world_2_transition',
    type: StoryType.worldTransition,
    title: '地下帝国へ',
    description: '棋霊の力が奪われている。地下に潜れ',
    displayDuration: Duration(seconds: 10),
    backgroundColor: '#2C2C2C',
  ),
  'world_3_enter': StoryEvent(
    storyKey: 'world_3_transition',
    type: StoryType.worldTransition,
    title: '過去へ',
    description: '支配の起源は過去にある。時を遡れ',
    displayDuration: Duration(seconds: 10),
    backgroundColor: '#D4A017',
  ),
  'world_4_enter': StoryEvent(
    storyKey: 'world_4_transition',
    type: StoryType.worldTransition,
    title: '天界へ',
    description: '全ての棋霊を解放した。今こそ棋王と対峙する',
    displayDuration: Duration(seconds: 10),
    backgroundColor: '#E3F2FD',
  ),
};

// ===== チラ見せ演出 =====

final hintEvents = [
  StoryEvent(
    storyKey: 'hint_1_5th_kyu',
    type: StoryType.hint,
    title: '',
    displayDuration: Duration(milliseconds: 500),
    backgroundColor: '#1A1A2E',
  ),
  StoryEvent(
    storyKey: 'hint_2_4th_kyu',
    type: StoryType.hint,
    title: '...力が奪われている...',
    displayDuration: Duration(milliseconds: 500),
    backgroundColor: '#1A1A2E',
  ),
  StoryEvent(
    storyKey: 'hint_3_1st_kyu',
    type: StoryType.hint,
    title: '',
    displayDuration: Duration(milliseconds: 300),
    backgroundColor: '#1A1A2E',
  ),
];

// ===== エンディング選択肢 =====

enum EndingType {
  coexistence,    // 共存エンディング（推奨）
  freedom,        // 自由エンディング
  inheritance,    // 継承エンディング（隠し）
}

class EndingChoice {
  final EndingType type;
  final String title;
  final String description;
  final String reward;

  const EndingChoice({
    required this.type,
    required this.title,
    required this.description,
    required this.reward,
  });
}

final endingChoices = [
  EndingChoice(
    type: EndingType.coexistence,
    title: '棋霊と共に生きる世界を作る',
    description: '全ての棋霊と対等な新秩序を構築。真の平和への道。',
    reward: '称号「棋霊の友」・全棋霊の絆完成ボーナス',
  ),
  EndingChoice(
    type: EndingType.freedom,
    title: '全ての支配を解体する',
    description: '支配システムを完全に廃止。混沌の中の自由。',
    reward: '称号「解放者」・隠し詰将棋10問解放',
  ),
  EndingChoice(
    type: EndingType.inheritance,
    title: '秩序を継ぎ、統治する',
    description: 'プレイヤーが新しい棋王となり、世界を統制。',
    reward: '称号「新たなる棋王」・隠しキャラ「棋王」使用可能',
  ),
];
