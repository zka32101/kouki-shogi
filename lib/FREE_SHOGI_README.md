# 自由将棋（Free Shogi）機能概要

## 概要
標準的な将棋のルールを維持しつつ、駒の初期配置を自由に設定できる機能。各駒にポイント値を設定し、予算内で好きなように配置できます。

## 駒のポイント値
| 駒 | ポイント | 駒 | ポイント |
|-----|---------|-----|---------|
| 歩 | 1 | 香 | 3 |
| 桂 | 3 | 銀 | 4 |
| 金 | 5 | 角 | 8 |
| 飛 | 10 | 玉 | 0（固定） |

成駒は元の駒より1～2高め。

**デフォルト予算**: 各プレイヤー 60 ポイント

## ファイル構成

### モデル
- **`lib/models/free_shogi_config.dart`**
  - `FreeShogiFiece`: 駒ポイント定義
  - `FreeShogiFiemplateEntry`: テンプレートモデル

### サービス
- **`lib/services/free_shogi_service.dart`**
  - テンプレートの保存・読込（SharedPrefs + Firestore）
  - ローカルテンプレート管理
  - クラウドテンプレート同期

### 画面
- **`lib/screens/free_shogi_home_screen.dart`**
  - メニュー・テンプレート一覧表示
  - テンプレート管理（新規作成・編集・削除）

- **`lib/screens/free_shogi_setup_screen.dart`**
  - 駒配置エディタ
  - ポイント残量表示
  - 盤面上でのクリック配置・ロング押し削除

## 使用方法

### 1. ホーム画面を開く
```dart
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => const FreeShogiFiHomeScreen()),
);
```

### 2. 新規配置を作成
- 「新規配置を作成」ボタンをタップ
- 先手/後手を切り替え
- 駒を選択してクリックで配置
- ロングプレスで削除
- 「保存」でテンプレートに保存

### 3. テンプレートから対局開始（未実装）
- 保存済みテンプレートをタップ
- 「対局開始」で配置を使用して対局を開始
- ネットワーク対局での対戦相手に配置を送信

## 次実装予定

### Phase 2: 対局連携
- [ ] 配置したボード状態をMatch開始時に適用
- [ ] ローカル対局（AI）に対応
- [ ] ネットワーク対局マッチング時に配置テンプレートを選択

### Phase 3: ネットワーク連携
- [ ] テンプレートをFirestoreで共有
- [ ] 相手プレイヤーの配置を事前確認
- [ ] 対局戦績とテンプレート履歴

### Phase 4: バリエーション
- [ ] ルール変更: 予算額を変更可能にする
- [ ] プリセット配置（穴熊vs居飛車 等）
- [ ] ハンディキャップ配置（平手・十枚落ち等）

## 制限事項（現在）
- 玉は必ず配置が必要（2歩等の基本ルール適用）
- 反則チェック（２歩等）は対局開始時に実施
- テンプレートはローカルのみ（Firestore連携は未実装）
- 配置履歴・統計情報は未実装

## コード例

### テンプレートの保存
```dart
final service = FreeShogiFiemplateService();
final template = FreeShogiFiemplateEntry(
  id: 'my_template_1',
  name: 'マイ配置',
  p1Board: p1Board,
  p2Board: p2Board,
);
await service.saveLocalTemplate(template);
```

### テンプレートの読込
```dart
final templates = await service.getLocalTemplates();
```

### ポイント計算
```dart
final total = FreeShogiFiece.calculateTotal(pieceMap);
```

## TODO
- Firestore連携でテンプレート共有
- ネットワーク対局との統合
- UIの細部改善（ボード表示、駒選択UI）
- 配置バリデーション（玉の位置等）
- テンプレートのプレビュー機能
