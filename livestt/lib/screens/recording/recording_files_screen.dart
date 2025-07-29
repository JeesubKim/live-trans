import 'package:flutter/material.dart';
import 'recording_detail_screen.dart';
import '../../utils/global_toast.dart';
import '../../services/subtitle_file_manager.dart';
import 'dart:io';

class RecordingFilesScreen extends StatefulWidget {
  const RecordingFilesScreen({super.key});

  @override
  State<RecordingFilesScreen> createState() => _RecordingFilesScreenState();
}

class _RecordingFilesScreenState extends State<RecordingFilesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final SubtitleFileManager _fileManager = SubtitleFileManager();
  
  List<Map<String, dynamic>> _filteredSessions = [];
  
  // Multi-select state
  bool _isMultiSelectMode = false;
  Set<String> _selectedItems = <String>{};

  @override
  void initState() {
    super.initState();
    _loadRecordings();
    _searchController.addListener(_filterSessions);
  }

  Future<void> _loadRecordings() async {
    try {
      final files = await _fileManager.listSubtitleFiles();
      final recordings = <Map<String, dynamic>>[];
      
      for (final file in files) {
        if (file is File) {
          final metadata = await _fileManager.getFileMetadata(file.path);
          if (metadata != null) {
            final stat = await file.stat();
            recordings.add({
              'id': file.path,
              'name': metadata.title,
              'date': _formatDate(metadata.created),
              'duration': _formatDuration(metadata.duration ?? Duration.zero),
              'textCount': 'Unknown', // We'll need to load the file to count
              'filePath': file.path,
              'created': metadata.created,
            });
          }
        }
      }
      
      // Sort by creation date (newest first)
      recordings.sort((a, b) => (b['created'] as DateTime).compareTo(a['created'] as DateTime));
      
      setState(() {
        _filteredSessions = recordings;
      });
    } catch (e) {
      print('Error loading recordings: $e');
      setState(() {
        _filteredSessions = [];
      });
    }
  }
  
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
  
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterSessions() async {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      _loadRecordings(); // Reload all recordings
    } else {
      // Filter current sessions
      setState(() {
        _filteredSessions = _filteredSessions.where((session) {
          return session['name'].toString().toLowerCase().contains(query);
        }).toList();
      });
    }
  }
  
  // Multi-select methods
  void _enterMultiSelectMode(String itemId) {
    setState(() {
      _isMultiSelectMode = true;
      _selectedItems.add(itemId);
    });
  }
  
  void _exitMultiSelectMode() {
    setState(() {
      _isMultiSelectMode = false;
      _selectedItems.clear();
    });
  }
  
  void _toggleItemSelection(String itemId) {
    setState(() {
      if (_selectedItems.contains(itemId)) {
        _selectedItems.remove(itemId);
        if (_selectedItems.isEmpty) {
          _isMultiSelectMode = false;
        }
      } else {
        _selectedItems.add(itemId);
      }
    });
  }
  
  void _selectAllItems() {
    setState(() {
      _selectedItems.clear();
      for (final session in _filteredSessions) {
        _selectedItems.add(session['id'] as String);
      }
    });
  }
  
  void _deselectAllItems() {
    setState(() {
      _selectedItems.clear();
      // Keep multiselect mode active when deselecting all via checkbox
    });
  }
  
  bool get _isAllSelected => _selectedItems.length == _filteredSessions.length && _filteredSessions.isNotEmpty;
  bool get _isPartiallySelected => _selectedItems.isNotEmpty && !_isAllSelected;
  
  Future<void> _deleteSelectedItems() async {
    try {
      for (final itemId in _selectedItems) {
        await _fileManager.deleteSubtitleFile(itemId);
      }
      
      globalToast.success('${_selectedItems.length} recordings deleted');
      _exitMultiSelectMode();
      _loadRecordings(); // Reload the list
    } catch (e) {
      globalToast.error('Failed to delete recordings: $e');
    }
  }
  
  Future<void> _deleteSingleItem(String itemId, String itemName) async {
    final confirmed = await _showDeleteConfirmation(itemName);
    if (confirmed) {
      try {
        await _fileManager.deleteSubtitleFile(itemId);
        globalToast.success('Recording deleted');
        _loadRecordings(); // Reload the list
      } catch (e) {
        globalToast.error('Failed to delete recording: $e');
      }
    }
  }
  
  Future<bool> _showDeleteConfirmation(String itemName) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Recording'),
        content: Text('Are you sure you want to delete "$itemName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isMultiSelectMode 
            ? Text('${_selectedItems.length} selected')
            : const Text('Recordings'),
        centerTitle: !_isMultiSelectMode,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: _isMultiSelectMode 
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitMultiSelectMode,
              )
            : null,
        actions: _isMultiSelectMode 
            ? [
                // Select all checkbox
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Center(
                    child: Checkbox(
                      value: _isAllSelected ? true : (_isPartiallySelected ? null : false),
                      tristate: true,
                      onChanged: (_) {
                        if (_isAllSelected || _isPartiallySelected) {
                          _deselectAllItems();
                        } else {
                          _selectAllItems();
                        }
                      },
                      activeColor: Colors.white,
                      checkColor: Colors.black,
                      side: const BorderSide(color: Colors.white, width: 2),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: _selectedItems.isNotEmpty ? _deleteSelectedItems : null,
                ),
              ]
            : null,
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
                      final itemId = session['id'] as String;
                      final isSelected = _selectedItems.contains(itemId);
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        color: isSelected ? Colors.blue.withOpacity(0.1) : null,
                        child: ListTile(
                          leading: _isMultiSelectMode 
                              ? Checkbox(
                                  value: isSelected,
                                  onChanged: (_) => _toggleItemSelection(itemId),
                                )
                              : const CircleAvatar(
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
                          trailing: _isMultiSelectMode 
                              ? null
                              : PopupMenuButton(
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
                                  onSelected: (value) async {
                                    switch (value) {
                                      case 'play':
                                        globalToast.normal('Playing recording...');
                                        break;
                                      case 'export':
                                        globalToast.warning('Export feature coming soon');
                                        break;
                                      case 'delete':
                                        await _deleteSingleItem(itemId, session['name']);
                                        break;
                                    }
                                  },
                                ),
                          onLongPress: _isMultiSelectMode 
                              ? null 
                              : () => _enterMultiSelectMode(itemId),
                          onTap: () {
                            if (_isMultiSelectMode) {
                              _toggleItemSelection(itemId);
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => RecordingDetailScreen(
                                    sessionId: session['id'],
                                    sessionName: session['name'],
                                  ),
                                ),
                              );
                            }
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