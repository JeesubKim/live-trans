// Centralized dummy data for recordings
class DummyData {
  static final Map<String, Map<String, dynamic>> recordings = {
    '1': {
      'id': '1',
      'name': 'Meeting Recording 2024-01-15',
      'duration': '15:30',
      'date': '2024-01-15 14:30',
      'textCount': 5,
      'totalSeconds': 930, // 15:30 in seconds
      'transcripts': [
        {'timestamp': '00:00:15', 'seconds': 15, 'text': 'Hello everyone. Let\'s start today\'s team meeting.'},
        {'timestamp': '00:00:32', 'seconds': 32, 'text': 'The first agenda item is the project progress status update.'},
        {'timestamp': '00:01:05', 'seconds': 65, 'text': 'We are currently about 70% complete with the development phase.'},
        {'timestamp': '00:01:28', 'seconds': 88, 'text': 'We plan to complete all testing by next week as scheduled.'},
        {'timestamp': '00:02:10', 'seconds': 130, 'text': 'If you have any questions or comments, please let us know now.'},
      ],
    },
    '2': {
      'id': '2', 
      'name': 'Lecture Recording 2024-01-14',
      'duration': '42:15',
      'date': '2024-01-14 10:00',
      'textCount': 8,
      'totalSeconds': 2535, // 42:15 in seconds
      'transcripts': [
        {'timestamp': '00:00:05', 'seconds': 5, 'text': 'Welcome to today\'s computer science lecture on algorithms.'},
        {'timestamp': '00:00:45', 'seconds': 45, 'text': 'Today we will be discussing sorting algorithms and their complexity.'},
        {'timestamp': '00:02:15', 'seconds': 135, 'text': 'Let\'s start with bubble sort, which is the simplest but inefficient.'},
        {'timestamp': '00:05:30', 'seconds': 330, 'text': 'The time complexity of bubble sort is O(n squared) in the worst case.'},
        {'timestamp': '00:08:45', 'seconds': 525, 'text': 'Now let\'s move on to more efficient algorithms like quicksort.'},
        {'timestamp': '00:12:20', 'seconds': 740, 'text': 'Quicksort has an average time complexity of O(n log n).'},
        {'timestamp': '00:15:55', 'seconds': 955, 'text': 'Are there any questions about these sorting algorithms so far?'},
        {'timestamp': '00:18:30', 'seconds': 1110, 'text': 'Let\'s look at some practical examples of these algorithms in action.'},
      ],
    },
    '3': {
      'id': '3',
      'name': 'Interview Recording 2024-01-13', 
      'duration': '28:45',
      'date': '2024-01-13 16:20',
      'textCount': 6,
      'totalSeconds': 1725, // 28:45 in seconds
      'transcripts': [
        {'timestamp': '00:00:10', 'seconds': 10, 'text': 'Thank you for coming in today. Please tell us about yourself.'},
        {'timestamp': '00:01:30', 'seconds': 90, 'text': 'I have five years of experience in software development and testing.'},
        {'timestamp': '00:03:45', 'seconds': 225, 'text': 'My expertise includes React, Node.js, and cloud technologies like AWS.'},
        {'timestamp': '00:06:20', 'seconds': 380, 'text': 'I\'ve led several projects from conception to deployment successfully.'},
        {'timestamp': '00:09:15', 'seconds': 555, 'text': 'What interests me most about this role is the opportunity to innovate.'},
        {'timestamp': '00:12:40', 'seconds': 760, 'text': 'Do you have any questions about my background or experience?'},
      ],
    },
  };

  static List<Map<String, dynamic>> getRecordingsList() {
    return recordings.values.map((recording) {
      return {
        'id': recording['id'],
        'name': recording['name'],
        'duration': recording['duration'],
        'date': recording['date'],
        'textCount': recording['textCount'],
      };
    }).toList();
  }

  static Map<String, dynamic>? getRecordingDetail(String sessionId) {
    return recordings[sessionId];
  }
}