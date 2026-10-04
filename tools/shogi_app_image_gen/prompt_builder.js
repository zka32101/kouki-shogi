// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// shogi_app ユーザーアイコンキャラクター画像 プロンプト設計
// lib/character_icons.dart の allCharacterIcons（12種）に対応。
// キャラクターは固定12種で少数のため、card_crown のようなハッシュ選択の
// バリエーション辞書ではなく、1キャラ1文の手書きプロンプトを直接定義する。
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// character_icons.dart の id と対応させること
const CHARACTERS = [
  {
    id: 'samurai',
    nameJp: '武士',
    accentHex: '#1565C0',
    desc: 'a noble samurai warrior with a proud determined expression, dark navy blue traditional armor (yoroi) with subtle gold trim, katana sheathed at the hip',
  },
  {
    id: 'ninja',
    nameJp: '忍者',
    accentHex: '#37474F',
    desc: 'a stealthy ninja shrouded in dark slate-grey garb, half-masked face with sharp focused eyes, shuriken tucked at the belt',
  },
  {
    id: 'kenshi',
    nameJp: '剣士',
    accentHex: '#455A64',
    desc: 'a master swordsman in a calm ready stance, focused serene expression, minimalist grey traditional attire, single katana drawn and gleaming',
  },
  {
    id: 'shogun',
    nameJp: '将軍',
    accentHex: '#B8860B',
    desc: 'a regal shogun ruler wearing ornate golden-brown lacquered armor and an imposing kabuto helmet, commanding authoritative expression',
  },
  {
    id: 'tengu',
    nameJp: '天狗',
    accentHex: '#C62828',
    desc: 'a mythical tengu mountain spirit with red skin and a cute rounded long nose, feathered cloak, playful mischievous expression, no human features',
  },
  {
    id: 'ryuou',
    nameJp: '龍王',
    accentHex: '#4A148C',
    desc: 'a legendary young dragon king face, majestic deep-purple scales, big round glowing golden eyes, small cute horns, regal but adorable mythical presence, no human features',
  },
  {
    id: 'kitsunebi',
    nameJp: '狐火',
    accentHex: '#E65100',
    desc: 'a mystical fox spirit face wreathed in blue-orange fox fire flames, big bright eyes with a cute clever expression, no human features',
  },
  {
    id: 'taka',
    nameJp: '鷹',
    accentHex: '#4E342E',
    desc: 'a majestic hawk with sharp piercing eyes and richly detailed dark brown feathers, noble bird of prey in a proud pose, no human features',
  },
  {
    id: 'tora',
    nameJp: '虎',
    accentHex: '#F57F17',
    desc: 'a cute powerful tiger cub face with amber-orange striped fur, big bright golden eyes, confident but adorable expression, no human features',
  },
  {
    id: 'ookami',
    nameJp: '狼',
    accentHex: '#546E7A',
    desc: 'a lone wolf with sleek blue-grey fur and piercing pale yellow eyes, solitary noble predator gazing forward, no human features',
  },
  {
    id: 'oni',
    nameJp: '鬼',
    accentHex: '#880E4F',
    desc: 'a small cute oni demon with deep crimson-magenta skin, tiny curved horns, an impish cheerful fanged grin, traditional Japanese demon mask motif, no human features',
  },
  {
    id: 'sennin',
    nameJp: '仙人',
    accentHex: '#00695C',
    desc: 'an immortal sage hermit with a long flowing white beard, teal-green robes, a serene wise expression and a subtle mystical aura, holding a wooden staff',
  },
];

// 全キャラ共通のアートスタイル（将棋アプリの「墨・金・朱・藍・松葉」和トーン世界観に統一）
// アイコン用途のため、顔がフレームいっぱいに大きく写るクローズアップと、
// 小さく表示されても魅力が伝わる「少しかわいらしい」チビ寄りの雰囲気を指定する。
const STYLE_SUFFIX =
  'extreme close-up face portrait, face and head fill almost the entire frame, ' +
  'cute chibi-influenced game avatar style, big sparkling expressive eyes, soft rounded features, endearing charming look, ' +
  'Japanese ink painting (sumi-e) accents fused with clean digital game icon illustration, ' +
  'circular icon composition with clear silhouette, ' +
  'soft rim lighting, subtle gold and vermillion accent linework, ' +
  'muted elegant ink-wash background, high detail digital illustration, ' +
  'no text no watermark no border no signature';

const NEGATIVE_PROMPT = [
  'text, words, letters, numbers, watermark, signature',
  'multiple characters, crowd',
  'full body, wide shot, distant, small face, cut off head',
  'western medieval armor, western fantasy style',
  'photorealistic photo, 3d render',
  'scary, grotesque, disturbing, realistic gore',
  'ugly, blurry, low quality, deformed, mutated, malformed',
  'extra limbs, bad anatomy, extra fingers',
].join(', ');

function buildPrompt(character) {
  const prompt = [
    character.desc,
    `accent color ${character.accentHex} used in clothing or aura highlights`,
    STYLE_SUFFIX,
  ]
    .filter(Boolean)
    .join(', ');

  return { prompt, negativePrompt: NEGATIVE_PROMPT };
}

module.exports = { CHARACTERS, buildPrompt };
