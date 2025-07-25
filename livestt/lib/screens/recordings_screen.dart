import 'package:flutter/material.dart';
import 'recording_detail_screen.dart';

class RecordingsScreen extends StatefulWidget {
  const RecordingsScreen({super.key});

  @override
  State<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends State<RecordingsScreen> {
  final TextEditingController _searchController = TextEditingController();
  
  // Sample recording data
  final List<Map<String, dynamic>> _dummySessions = [
    {
      'id': '1',
      'name': 'Meeting Recording 2024-01-15',
      'duration': '15:30',
      'date': '2024-01-15 14:30',
      'textCount': 45,
    },
    {
      'id': '2', 
      'name': 'Lecture Recording 2024-01-14',
      'duration': '42:15',
      'date': '2024-01-14 10:00',
      'textCount': 128,
    },
    {
      'id': '3',
      'name': 'Interview Recording 2024-01-13', 
      'duration': '28:45',
      'date': '2024-01-13 16:20',
      'textCount': 67,
    },
  ];
  
  List<Map<String, dynamic>> _filteredSessions = [];

  @override
  void initState() {
    super.initState();
    _filteredSessions = List.from(_dummySessions);
    _searchController.addListener(_filterSessions);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterSessions() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredSessions = List.from(_dummySessions);
      } else {
        _filteredSessions = _dummySessions.where((session) {
          return session['name'].toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recordings'),
        centerTitle: true,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 검색 바
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search recordings...',
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey[600]!),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
              ),
            ),
          ),
          
          // 녹음 목록
          Expanded(
            child: _filteredSessions.isEmpty
                ? const Center(
                    child: Text(
                      '저장된 녹음이 없습니다.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredSessions.length,
                    itemBuilder: (context, index) {
                      final session = _filteredSessions[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.blue,
                            child: Icon(Icons.audiotrack, color: Colors.white),
                          ),
                          title: Text(
                            session['name'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('📅 ${session['date']}'),
                              Row(
                                children: [
                                  Text('⏱️ ${session['duration']}'),
                                  const SizedBox(width: 16),
                                  Text('📝 ${session['textCount']}개 텍스트'),
                                ],
                              ),
                            ],
                          ),
                          trailing: PopupMenuButton(
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'play',
                                child: Row(
                                  children: [
                                    Icon(Icons.play_arrow),
                                    SizedBox(width: 8),
                                    Text('재생'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'export',
                                child: Row(
                                  children: [
                                    Icon(Icons.download),
                                    SizedBox(width: 8),
                                    Text('내보내기'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('삭제', style: TextStyle(color: Colors.red)),
                                  ],
                                ),
                              ),
                            ],
                            onSelected: (value) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('2단계: $value 기능 (UI만)')),
                              );
                            },
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RecordingDetailScreen(
                                  sessionId: session['id'],
                                  sessionName: session['name'],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}