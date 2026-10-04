// 自由将棋ホーム画面（メニュー）
import 'package:flutter/material.dart';
import 'free_shogi_setup_screen.dart';
import '../services/free_shogi_service.dart';
import '../models/free_shogi_config.dart';
import '../game_screen.dart';
import '../theme/app_theme.dart';

class FreeShogiFiHomeScreen extends StatefulWidget {
  const FreeShogiFiHomeScreen({super.key});

  @override
  State<FreeShogiFiHomeScreen> createState() => _FreeShogiFiHomeScreenState();
}

class _FreeShogiFiHomeScreenState extends State<FreeShogiFiHomeScreen> {
  final service = FreeShogiFiemplateService();
  late Future<List<FreeShogiFiemplateEntry>> templatesFuture;

  @override
  void initState() {
    super.initState();
    templatesFuture = service.getLocalTemplates();
  }

  void _navigateToSetup([FreeShogiFiemplateEntry? template]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FreeShogiFiSetupScreen(initialTemplate: template),
      ),
    );
    if (result != null) {
      setState(() {
        templatesFuture = service.getLocalTemplates();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('自由将棋'),
        backgroundColor: AppTheme.surface,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 説明
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '駒に異なるポイント値を設定。予算内で自由に駒を配置して将棋を指します。'
                  '配置をテンプレートとして保存し、ネットワーク対局で使用できます。',
                  style: TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(height: 24),

              // 新規作成ボタン
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _navigateToSetup(),
                  icon: const Icon(Icons.add),
                  label: const Text('新規配置を作成'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 標準配置クイックスタート
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GameScreen(
                          settings: GameSettings(
                            mode: GameMode.vsAI,
                            aiLevel: AILevel.medium,
                          ),
                        ),
                      ),
                    );
                  },
                  child: const Text('標準将棋で遊ぶ'),
                ),
              ),
              const SizedBox(height: 24),

              // 保存済みテンプレート一覧
              const Text(
                '保存済みテンプレート',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<FreeShogiFiemplateEntry>>(
                future: templatesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('エラー: ${snapshot.error}'));
                  }
                  final templates = snapshot.data ?? [];
                  if (templates.isEmpty) {
                    return Center(
                      child: Text(
                        'テンプレートはまだありません',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: templates.length,
                    itemBuilder: (context, idx) {
                      final tmpl = templates[idx];
                      return Card(
                        child: ListTile(
                          title: Text(tmpl.name),
                          subtitle: Text(tmpl.description),
                          trailing: PopupMenuButton(
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                child: const Text('編集'),
                                onTap: () => _navigateToSetup(tmpl),
                              ),
                              PopupMenuItem(
                                child: const Text('対局開始'),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => GameScreen(
                                        settings: GameSettings(
                                          mode: GameMode.vsAI,
                                          aiLevel: AILevel.medium,
                                        ),
                                        initialBoard: tmpl.p1Board,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              PopupMenuItem(
                                child: const Text('削除'),
                                onTap: () async {
                                  await service.deleteLocalTemplate(tmpl.id);
                                  setState(() {
                                    templatesFuture = service.getLocalTemplates();
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
