import 'package:flutter/material.dart';

class RecordingDetailScreen extends StatelessWidget {
  final String sessionId;
  final String sessionName;

  const RecordingDetailScreen({
    super.key,
    required this.sessionId,
    required this.sessionName,
  });

  @override
  Widget build(BuildContext context) {
    // 임시 더미 데이터
    final dummyTexts = [
      {'timestamp': '00:00:15', 'text': '안녕하세요. 오늘 회의를 시작하겠습니다.'},
      {'timestamp': '00:00:32', 'text': '첫 번째 안건은 프로젝트 진행 상황입니다.'},
      {'timestamp': '00:01:05', 'text': '현재까지 70% 정도 완료된 상태입니다.'},
      {'timestamp': '00:01:28', 'text': '다음 주까지 테스트를 완료할 예정입니다.'},
      {'timestamp': '00:02:10', 'text': '질문이나 의견이 있으시면 말씀해 주세요.'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('녹음 상세'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('2단계: 공유 기능 (UI만)')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () {
              _showExportDialog(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 녹음 정보 헤더
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sessionName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Row(
                  children: [
                    Icon(Icons.schedule, size: 16, color: Colors.grey),
                    SizedBox(width: 4),
                    Text('총 시간: 15:30'),
                    SizedBox(width: 16),
                    Icon(Icons.text_fields, size: 16, color: Colors.grey),
                    SizedBox(width: 4),
                    Text('텍스트: 45개'),
                  ],
                ),
              ],
            ),
          ),

          // 오디오 플레이어 컨트롤 (임시)
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('2단계: 재생 기능 (UI만)')),
                    );
                  },
                  icon: const Icon(Icons.play_arrow, size: 32),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(
                        value: 0.3,
                        backgroundColor: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 4),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('04:35', style: TextStyle(fontSize: 12)),
                          Text('15:30', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(),

          // STT 텍스트 목록
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: dummyTexts.length,
              itemBuilder: (context, index) {
                final textData = dummyTexts[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                textData['timestamp']!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('2단계: 복사 기능 (UI만)')),
                                );
                              },
                              icon: const Icon(Icons.copy, size: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          textData['text']!,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('내보내기'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.text_snippet),
              title: const Text('텍스트 파일 (.txt)'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('2단계: TXT 내보내기 (UI만)')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: const Text('CSV 파일 (.csv)'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('2단계: CSV 내보내기 (UI만)')),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
        ],
      ),
    );
  }
}