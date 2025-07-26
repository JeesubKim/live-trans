import 'package:flutter/material.dart';
import 'recording_detail_screen.dart';
import '../widgets/global_toast.dart';
import '../data/dummy_data.dart';

class RecordingsScreen extends StatefulWidget {
  const RecordingsScreen({super.key});

  @override
  State<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends State<RecordingsScreen> {
  final TextEditingController _searchController = TextEditingController();
  
  List<Map<String, dynamic>> _filteredSessions = [];

  @override
  void initState() {
    super.initState();
    _filteredSessions = DummyData.getRecordingsList();
    _searchController.addListener(_filterSessions);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterSessions() {
    final query = _searchController.text.toLowerCase();
    final allSessions = DummyData.getRecordingsList();
    setState(() {
      if (query.isEmpty) {
        _filteredSessions = allSessions;
      } else {
        _filteredSessions = allSessions.where((session) {
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
          // Search bar
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
          
          // Recording list
          Expanded(
            child: _filteredSessions.isEmpty
                ? const Center(
                    child: Text(
                      'No saved recordings.',
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
                                  Text('📝 ${session['textCount']} texts'),
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
                                    Text('Play'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'export',
                                child: Row(
                                  children: [
                                    Icon(Icons.download),
                                    SizedBox(width: 8),
                                    Text('Export'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('Delete', style: TextStyle(color: Colors.red)),
                                  ],
                                ),
                              ),
                            ],
                            onSelected: (value) {
                              String message;
                              MessageType type = MessageType.normal;
                              
                              switch (value) {
                                case 'play':
                                  message = 'Playing recording...';
                                  type = MessageType.normal;
                                  break;
                                case 'export':
                                  message = 'Exporting recording...';
                                  type = MessageType.indicator;
                                  break;
                                case 'delete':
                                  message = 'Recording deleted';
                                  type = MessageType.fail;
                                  break;
                                default:
                                  message = 'Stage 2: $value feature (UI only)';
                              }
                              
                              TOAST.sendMessage(type, message);
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