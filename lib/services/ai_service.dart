// lib/services/ai_service.dart — Claude AI 解説・コーチサービス
import 'package:cloud_functions/cloud_functions.dart';

class AIService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// 盤面・局面について自然言語で質問する
  static Future<String> explainPosition(String boardJson, String question) async {
    try {
      final result = await _functions
          .httpsCallable('explainPosition')
          .call({'boardJson': boardJson, 'question': question});
      return (result.data as Map<dynamic, dynamic>)['answer'] as String? ??
          '回答を取得できませんでした';
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'internal' && e.message?.contains('API key not configured') == true) {
        return '（AI解説にはサーバー設定が必要です）\n質問: $question\n\nこの局面では駒の連携と王の安全を意識して指してみましょう。';
      }
      return 'AI解説エラー: ${e.message}';
    } catch (e) {
      return 'エラーが発生しました: $e';
    }
  }

  /// 対局後のコーチフィードバック
  static Future<String> generateCoachFeedback(String gameResult, String playStyle) async {
    try {
      final result = await _functions
          .httpsCallable('generateCoachFeedback')
          .call({'gameResult': gameResult, 'playStyle': playStyle});
      return (result.data as Map<dynamic, dynamic>)['feedback'] as String? ??
          'フィードバックを取得できませんでした';
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'internal' && e.message?.contains('API key not configured') == true) {
        return '（AIコーチ機能はサーバー設定後に有効になります）\n\n今局はよく頑張りました！次の対局では序盤の囲いをしっかり作ることを意識してみましょう。';
      }
      return 'AIコーチエラー: ${e.message}';
    } catch (e) {
      return 'エラーが発生しました: $e';
    }
  }

  /// 盤面画像からOCR解析（Cloud Vision + Claude）
  static Future<String> analyzeBoardFromImage(String imagePath) async {
    return '（OCR分析機能は次バージョンで対応予定です）\n撮影した盤面を解析してAIが局面評価をお知らせします。';
  }
}
