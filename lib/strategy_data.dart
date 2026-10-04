// lib/strategy_data.dart — 戦法マッピングデータ

enum OppCastle {
  mino('美濃囲い', '2八玉・3八金・3七銀の振り飛車定番。横からの攻めに強い。端攻めや上部（玉頭）からの攻めに弱点がある。完成6手。'),
  anaguma('穴熊', '9九玉を隅深く潜らせた最強の持久戦囲い。縦横どちらにも強い。一度組めば終盤は無敵だが完成に15手以上かかる。'),
  yagura('矢倉', '8八玉・7八金・7七銀・6七金の居飛車代表囲い。縦の攻めに非常に強い。横から崩されると弱く完成に8手かかる。'),
  kanabusho('金無双', '8八玉・7八金・6八金の金2枚並び。上部への攻めには強い。横（コビン）からの攻めに弱点があり端が薄い。完成5手。'),
  fune('舟囲い', '5八玉・4八金・6八金の最短形。3手で完成し急戦に素早く対応できる。非常に薄く横からの攻めに弱い。長期戦不向き。'),
  ginkan('銀冠', '8八玉・7八金・8七銀の銀を頭に乗せた形。美濃の発展形で上部（玉頭）からの攻めに厚い。完成に10手かかる。');

  final String label;
  final String desc;
  const OppCastle(this.label, this.desc);
}

enum OppStrategy {
  shiken('四間飛車'),
  sanken('三間飛車'),
  naka('中飛車'),
  mukai('向かい飛車'),
  ibisha('居飛車');

  final String label;
  const OppStrategy(this.label);
}

enum WarType { kyusen, jikusen }

class StrategyRec {
  final String name;
  final int stars;
  final WarType warType;
  final bool isHard;
  final String point;
  final String detail;

  const StrategyRec({
    required this.name,
    required this.stars,
    required this.warType,
    this.isHard = false,
    required this.point,
    required this.detail,
  });
}

const Map<(OppCastle, OppStrategy), List<StrategyRec>> kStrategyMap = {
  // ===== 美濃囲い対策 =====
  (OppCastle.mino, OppStrategy.shiken): [
    StrategyRec(
      name: '棒銀（急戦）',
      stars: 3,
      warType: WarType.kyusen,
      point: '3筋から銀を繰り出し端を直撃',
      detail: '▲3七銀→3六銀と進出。美濃の端（9筋・3筋）は薄く棒銀が刺さりやすい。銀を取られた後も桂馬で補強して続ける。',
    ),
    StrategyRec(
      name: '右四間飛車',
      stars: 3,
      warType: WarType.kyusen,
      point: '角頭を4筋から集中攻撃',
      detail: '飛車を4筋に振り、角・銀・桂を4筋に集結。美濃が完成する前に仕掛けるのがポイント。角を取れれば駒損なしで優勢になる。',
    ),
    StrategyRec(
      name: '穴熊（持久戦）',
      stars: 2,
      warType: WarType.jikusen,
      point: '堅さで上回り長期戦に',
      detail: '穴熊は美濃より堅く、長期戦になれば駒得が活きてくる。ただし組むまでに手数がかかり相手に攻めを許しやすい。',
    ),
  ],
  (OppCastle.mino, OppStrategy.sanken): [
    StrategyRec(
      name: '棒銀',
      stars: 3,
      warType: WarType.kyusen,
      point: '角の利きが3筋なので棒銀が通りやすい',
      detail: '三間飛車は角が3筋を向いているため棒銀の援護が薄い。早めに3筋から銀を繰り出す。相手が石田流に組む前に仕掛けることが大切。',
    ),
    StrategyRec(
      name: '端攻め重視',
      stars: 2,
      warType: WarType.kyusen,
      point: '1筋から美濃の上部を崩す',
      detail: '1筋の歩を突き捨て桂馬・香車で端を突破する。三間飛車は端の守りが薄くなりやすく、端攻めが決まりやすい。',
    ),
  ],
  (OppCastle.mino, OppStrategy.naka): [
    StrategyRec(
      name: '超速（3七銀戦法）',
      stars: 3,
      warType: WarType.kyusen,
      isHard: true,
      point: '中飛車への最強急戦定跡',
      detail: '▲3七銀→4六銀と繰り出し5筋の飛車に圧力をかける。中飛車に対する現代の主力戦法。定跡が深いが覚える価値が高い。',
    ),
    StrategyRec(
      name: '左美濃急戦',
      stars: 2,
      warType: WarType.kyusen,
      point: '左美濃から仕掛ける速攻',
      detail: '左美濃に組んで中飛車の飛車先を受けつつ急戦を仕掛ける。超速より単純でわかりやすく、初中級者にもおすすめ。',
    ),
  ],
  (OppCastle.mino, OppStrategy.mukai): [
    StrategyRec(
      name: '棒銀',
      stars: 3,
      warType: WarType.kyusen,
      point: '飛車のぶつかりを利用して先攻',
      detail: '向かい飛車は飛車が向かい合う形になる。棒銀で先攻して飛車交換に持ち込むか、銀得を狙う。飛車交換後は打ち込みに注意。',
    ),
    StrategyRec(
      name: '右四間飛車',
      stars: 2,
      warType: WarType.kyusen,
      point: '4筋から角を分断',
      detail: '向かい飛車に対しても右四間は有効。4筋から攻め、飛車と角の連携を断ち切る。',
    ),
  ],
  (OppCastle.mino, OppStrategy.ibisha): [
    StrategyRec(
      name: '矢倉囲い',
      stars: 3,
      warType: WarType.jikusen,
      point: '相居飛車の基本形',
      detail: '相居飛車では矢倉が基本。▲7八金→6七金→7七角と組み上げる。相手より先に完成させることを意識して指す。',
    ),
    StrategyRec(
      name: '雁木囲い',
      stars: 2,
      warType: WarType.jikusen,
      point: '現代的で対応しやすい',
      detail: '矢倉崩しに強い現代的囲い。急戦にも対応しやすく、様々な戦法に柔軟に対応できる万能形。',
    ),
  ],

  // ===== 穴熊対策 =====
  (OppCastle.anaguma, OppStrategy.shiken): [
    StrategyRec(
      name: '左美濃急戦',
      stars: 3,
      warType: WarType.kyusen,
      point: '穴熊完成前に仕掛けることが絶対条件',
      detail: '穴熊が完成してしまうと攻め方が非常に難しくなる。▲4五歩などで仕掛けを急ぐ。左美濃に組んで攻撃態勢を整えてから突撃する。',
    ),
    StrategyRec(
      name: '銀冠（持久戦）',
      stars: 2,
      warType: WarType.jikusen,
      point: '穴熊より上部を厚くして対抗',
      detail: '相穴熊は先手が有利になりやすい。銀冠で上部を手厚くし、穴熊の弱点（上部）を突く持久戦。時間をかけて攻撃態勢を整える。',
    ),
  ],
  (OppCastle.anaguma, OppStrategy.sanken): [
    StrategyRec(
      name: '速攻（端攻め）',
      stars: 3,
      warType: WarType.kyusen,
      point: '穴熊完成前が唯一のチャンス',
      detail: '穴熊が完成すると崩せなくなる。端を突き捨て早期に戦いを起こす。1筋や3筋から速攻を仕掛けて主導権を握る。',
    ),
    StrategyRec(
      name: '銀冠（持久戦）',
      stars: 2,
      warType: WarType.jikusen,
      point: '上部から圧力をかける',
      detail: '銀冠で上部を固め、穴熊の弱点（頭）を突く。三間飛車穴熊は端の守りが薄いので端攻めも有効。',
    ),
  ],
  (OppCastle.anaguma, OppStrategy.naka): [
    StrategyRec(
      name: '超速（3七銀戦法）',
      stars: 3,
      warType: WarType.kyusen,
      isHard: true,
      point: '中飛車穴熊は組みが遅い弱点を突く',
      detail: '中飛車は穴熊に組む際に手数がかかる。超速で先攻して穴熊完成前に仕掛けることができる。',
    ),
    StrategyRec(
      name: '左美濃急戦',
      stars: 2,
      warType: WarType.kyusen,
      point: '速攻で穴熊完成を防ぐ',
      detail: '左美濃に組んで5筋から圧力をかける。穴熊の完成を許さない速攻型で中飛車穴熊の弱点を突く。',
    ),
  ],
  (OppCastle.anaguma, OppStrategy.mukai): [
    StrategyRec(
      name: '急戦速攻',
      stars: 3,
      warType: WarType.kyusen,
      point: '穴熊完成前の端攻めが最善',
      detail: '向かい飛車から穴熊に組む手順中に端を突き捨て速攻で崩す。穴熊完成後は攻め方が限られるため完成前の速攻一択。',
    ),
  ],
  (OppCastle.anaguma, OppStrategy.ibisha): [
    StrategyRec(
      name: '銀冠穴熊（持久戦）',
      stars: 3,
      warType: WarType.jikusen,
      point: '相穴熊なら銀冠穴熊で上部を固める',
      detail: '相居飛車の穴熊戦では銀冠穴熊が定番。銀を頭に乗せることで上部からの攻めに強くなり、穴熊より優秀な形になる。',
    ),
    StrategyRec(
      name: '玉頭位取り',
      stars: 2,
      warType: WarType.jikusen,
      isHard: true,
      point: '中央制圧で穴熊の弱点を突く',
      detail: '穴熊の弱点は上部。中央から位を取り上部を制圧する戦い方。習得に時間がかかるが完成すれば強力。',
    ),
  ],

  // ===== 矢倉対策 =====
  (OppCastle.yagura, OppStrategy.shiken): [
    StrategyRec(
      name: '棒銀急戦',
      stars: 3,
      warType: WarType.kyusen,
      point: '矢倉+振り飛車の珍しい組合せに速攻',
      detail: '矢倉から振り飛車を選ぶのは稀な形。矢倉の組み直しの手数を逆用して棒銀で速攻をかける。',
    ),
    StrategyRec(
      name: '右四間飛車',
      stars: 2,
      warType: WarType.kyusen,
      point: '矢倉の弱点・角頭を狙う',
      detail: '矢倉の弱点は3七角の筋と角頭。右四間で角頭を集中攻撃する。',
    ),
  ],
  (OppCastle.yagura, OppStrategy.sanken): [
    StrategyRec(
      name: '急戦棒銀',
      stars: 3,
      warType: WarType.kyusen,
      point: '矢倉+三間は組合せが成立しにくい',
      detail: '矢倉と三間飛車は相性が悪く相手の形が乱れやすい。素直に急戦で対応し、形の乱れを突く。',
    ),
  ],
  (OppCastle.yagura, OppStrategy.naka): [
    StrategyRec(
      name: '超速（3七銀）',
      stars: 3,
      warType: WarType.kyusen,
      isHard: true,
      point: '矢倉でも超速は有効',
      detail: '矢倉に組みながら3七銀から超速をかける。中飛車への対策として矢倉でも超速が機能する。',
    ),
  ],
  (OppCastle.yagura, OppStrategy.mukai): [
    StrategyRec(
      name: '急戦矢倉',
      stars: 2,
      warType: WarType.kyusen,
      point: '矢倉から急戦に切り替え',
      detail: '矢倉に組みながら急戦に転じる。向かい飛車との飛車交換も視野に入れて指す。',
    ),
  ],
  (OppCastle.yagura, OppStrategy.ibisha): [
    StrategyRec(
      name: '急戦矢倉（右四間・棒銀）',
      stars: 3,
      warType: WarType.kyusen,
      point: '矢倉への急戦で先攻する',
      detail: '右四間や棒銀など多彩な急戦手段がある。相手の矢倉完成を待たずに仕掛けることで主導権を握る。',
    ),
    StrategyRec(
      name: '相矢倉（持久戦）',
      stars: 2,
      warType: WarType.jikusen,
      isHard: true,
      point: '定跡が豊富な深い戦い',
      detail: '互いに矢倉を組んだ相矢倉は定跡が非常に豊富。深い読みと定跡知識が必要だが覚えれば強力。',
    ),
    StrategyRec(
      name: '雁木（現代的持久戦）',
      stars: 2,
      warType: WarType.jikusen,
      point: '矢倉崩しに強い現代形',
      detail: '矢倉に対して雁木は崩しやすいとされる。現代プロでも多用される戦法で比較的習得しやすい。',
    ),
  ],

  // ===== 金無双対策 =====
  (OppCastle.kanabusho, OppStrategy.shiken): [
    StrategyRec(
      name: '棒金',
      stars: 3,
      warType: WarType.kyusen,
      point: '金無双の金を狙い撃ち',
      detail: '金を前進させて金無双の金にぶつける「棒金」が有効。金無双は金が横に並ぶため縦攻めに弱い弱点がある。',
    ),
    StrategyRec(
      name: '棒銀（端攻め）',
      stars: 2,
      warType: WarType.kyusen,
      point: '端から金無双を崩す',
      detail: '端攻めで金無双の薄い端を突く。銀を繰り出し端から侵入する。棒金と組み合わせると効果的。',
    ),
  ],
  (OppCastle.kanabusho, OppStrategy.sanken): [
    StrategyRec(
      name: '棒銀',
      stars: 3,
      warType: WarType.kyusen,
      point: '3筋から速攻',
      detail: '三間飛車の金無双には棒銀が最も単純で効果的。端と3筋から挟み撃ちにする。',
    ),
  ],
  (OppCastle.kanabusho, OppStrategy.naka): [
    StrategyRec(
      name: '端攻め重視',
      stars: 3,
      warType: WarType.kyusen,
      point: '金無双の弱点（端）を直撃',
      detail: '中飛車の金無双は端が薄い。1筋から端攻めをしかけることで金無双の形を崩す。',
    ),
    StrategyRec(
      name: '超速',
      stars: 2,
      warType: WarType.kyusen,
      isHard: true,
      point: '中飛車には鉄板の急戦',
      detail: '金無双に関わらず中飛車には超速が有効。3七銀から速攻をかけて5筋を制圧する。',
    ),
  ],
  (OppCastle.kanabusho, OppStrategy.mukai): [
    StrategyRec(
      name: '棒銀',
      stars: 2,
      warType: WarType.kyusen,
      point: '飛車交換から速攻',
      detail: '向かい飛車から金無双は稀な形。棒銀で対応し飛車交換に持ち込む。金無双の縦の弱点を突く。',
    ),
  ],
  (OppCastle.kanabusho, OppStrategy.ibisha): [
    StrategyRec(
      name: '矢倉急戦',
      stars: 3,
      warType: WarType.kyusen,
      point: '金無双は縦攻めに弱い',
      detail: '矢倉から急戦をしかける。金無双は横には強いが縦（上部）の攻めに弱い弱点がある。矢倉から縦攻めで崩す。',
    ),
  ],

  // ===== 舟囲い対策 =====
  (OppCastle.fune, OppStrategy.shiken): [
    StrategyRec(
      name: '棒銀',
      stars: 3,
      warType: WarType.kyusen,
      point: '薄い舟囲いを素早く崩す',
      detail: '舟囲いは仮の囲いで非常に薄い。棒銀で素早く仕掛け囲い直す前に崩す。飛車先突破が決まれば大優勢。',
    ),
    StrategyRec(
      name: '右四間飛車',
      stars: 3,
      warType: WarType.kyusen,
      point: '4筋から薄い玉を直撃',
      detail: '舟囲いの薄さを利用した右四間急戦。4筋に駒を集め薄い玉を直撃する。',
    ),
  ],
  (OppCastle.fune, OppStrategy.sanken): [
    StrategyRec(
      name: '棒銀',
      stars: 3,
      warType: WarType.kyusen,
      point: '薄い舟囲いを速攻で崩す',
      detail: '舟囲いは薄いため速攻が最善。三間飛車+舟囲いには棒銀で対応。石田流に組む前に仕掛ける。',
    ),
  ],
  (OppCastle.fune, OppStrategy.naka): [
    StrategyRec(
      name: '超速（3七銀）',
      stars: 3,
      warType: WarType.kyusen,
      isHard: true,
      point: '中飛車には超速が鉄板',
      detail: '舟囲い+中飛車には超速が最も効果的。舟囲いの薄さもあり速攻が決まりやすい。',
    ),
  ],
  (OppCastle.fune, OppStrategy.mukai): [
    StrategyRec(
      name: '棒銀',
      stars: 3,
      warType: WarType.kyusen,
      point: '飛車交換を狙う速攻',
      detail: '向かい飛車+舟囲いには棒銀で飛車交換に持ち込む。薄い舟囲いは交換後の打ち込みに弱い。',
    ),
  ],
  (OppCastle.fune, OppStrategy.ibisha): [
    StrategyRec(
      name: '矢倉（持久戦）',
      stars: 2,
      warType: WarType.jikusen,
      point: '舟囲いは仮の囲い。本格戦前に組み直す',
      detail: '相手の舟囲いは仮の形で本格的な囲いに組み直してくる。矢倉や雁木で迎え打つか、相手が組み直す前に急戦を仕掛ける。',
    ),
    StrategyRec(
      name: '雁木（現代形）',
      stars: 2,
      warType: WarType.jikusen,
      point: '現代的で対応しやすい',
      detail: '雁木に組んで様子を見る。舟囲いは薄いため、こちらが急戦に転じても対応が難しい。',
    ),
  ],

  // ===== 銀冠対策 =====
  (OppCastle.ginkan, OppStrategy.shiken): [
    StrategyRec(
      name: '銀冠急戦',
      stars: 3,
      warType: WarType.kyusen,
      point: '銀冠完成前に速攻か同型で対抗',
      detail: '銀冠は組むのに手数がかかる。完成前に急戦で崩すか、こちらも銀冠に組んで上部で戦う。',
    ),
    StrategyRec(
      name: '穴熊（持久戦）',
      stars: 2,
      warType: WarType.jikusen,
      point: '銀冠より堅い陣地で上回る',
      detail: '穴熊は銀冠より堅い。穴熊で長期戦に持ち込み駒得で勝負する。ただし銀冠は上部に強いため正確な攻めが必要。',
    ),
  ],
  (OppCastle.ginkan, OppStrategy.sanken): [
    StrategyRec(
      name: '急戦棒銀',
      stars: 3,
      warType: WarType.kyusen,
      point: '銀冠完成前に速攻',
      detail: '銀冠は組むのに手数がかかる。棒銀で銀冠完成前に仕掛ける。石田流に組む前に仕掛けることが重要。',
    ),
  ],
  (OppCastle.ginkan, OppStrategy.naka): [
    StrategyRec(
      name: '超速（3七銀）',
      stars: 3,
      warType: WarType.kyusen,
      isHard: true,
      point: '中飛車には超速が鉄板',
      detail: '銀冠+中飛車にも超速は有効。5筋への圧力で主導権を握る。',
    ),
  ],
  (OppCastle.ginkan, OppStrategy.mukai): [
    StrategyRec(
      name: '棒銀急戦',
      stars: 2,
      warType: WarType.kyusen,
      point: '銀冠完成前の速攻',
      detail: '向かい飛車+銀冠には棒銀で先攻。飛車交換を狙いながら銀冠の形を乱す。',
    ),
  ],
  (OppCastle.ginkan, OppStrategy.ibisha): [
    StrategyRec(
      name: '銀冠穴熊（持久戦）',
      stars: 3,
      warType: WarType.jikusen,
      point: '銀冠の強さに穴熊の堅さを加えた最強形',
      detail: '銀冠穴熊は銀冠の上部の強さに穴熊の堅さを加えた囲い。長期戦で絶大な効果を発揮する。',
    ),
    StrategyRec(
      name: '相銀冠（持久戦）',
      stars: 2,
      warType: WarType.jikusen,
      point: '同じ銀冠で上部戦に',
      detail: '相銀冠は上部での戦いになる。終盤の速度勝負になることが多く、端攻めの早さが勝敗を分ける。',
    ),
  ],
};
