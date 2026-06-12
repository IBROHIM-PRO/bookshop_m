import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../services/websocket_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/app_snackbar.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ChatDetailScreen extends StatefulWidget {
  final dynamic contactId;
  final String contactName;
  final String studentName;
  final String contactRole;
  final String? contactImageUrl;

  static dynamic activeContactId;

  const ChatDetailScreen({
    super.key,
    required this.contactId,
    required this.contactName,
    required this.studentName,
    required this.contactRole,
    this.contactImageUrl,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final List<dynamic> _messages = [];
  bool _isLoading = true;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription? _wsSubscription;
  int? _currentUserId;

  // Reply feature state
  Map<String, dynamic>? _replyToMessage;

  // Voice recording state
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _recordingPath;
  DateTime? _recordingStartTime;
  Timer? _recordingTimer;
  Duration _recordingDuration = Duration.zero;

  // Shared AudioPlayer state for message playback
  final AudioPlayer _sharedAudioPlayer = AudioPlayer();
  int? _playingMessageId;
  PlayerState _playerState = PlayerState.stopped;
  Duration _playerPosition = Duration.zero;
  Duration _playerDuration = Duration.zero;
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _playerPositionSubscription;
  StreamSubscription? _playerDurationSubscription;

  String _formatTimeStr(DateTime? dt) {
    if (dt == null) return '';
    final hour = dt.hour;
    final minute = dt.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    return '${hour12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  Widget _buildDateSeparator(DateTime date, bool isDarkMode) {
    final today = DateTime.now();
    String text = '';
    if (date.year == today.year && date.month == today.month && date.day == today.day) {
      text = 'Today';
    } else {
      text = '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    }
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.white.withOpacity(0.08) : const Color(0xFFF3F3F3),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isDarkMode ? Colors.white70 : Colors.black54,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    ChatDetailScreen.activeContactId = widget.contactId;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _currentUserId = authProvider.currentUser?.id;

    _fetchMessageHistory();
    _setupWebSocketListener();
    _setupAudioPlayerListeners();
  }

  @override
  void dispose() {
    if (ChatDetailScreen.activeContactId == widget.contactId) {
      ChatDetailScreen.activeContactId = null;
    }
    _wsSubscription?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    _recordingTimer?.cancel();

    _playerStateSubscription?.cancel();
    _playerPositionSubscription?.cancel();
    _playerDurationSubscription?.cancel();
    _sharedAudioPlayer.dispose();
    super.dispose();
  }

  void _setupAudioPlayerListeners() {
    _playerStateSubscription = _sharedAudioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _playerState = state;
          if (state == PlayerState.completed || state == PlayerState.stopped) {
            _playingMessageId = null;
            _playerPosition = Duration.zero;
            _playerDuration = Duration.zero;
          }
        });
      }
    });

    _playerPositionSubscription = _sharedAudioPlayer.onPositionChanged.listen((pos) {
      if (mounted) {
        setState(() {
          _playerPosition = pos;
        });
      }
    });

    _playerDurationSubscription = _sharedAudioPlayer.onDurationChanged.listen((dur) {
      if (mounted) {
        setState(() {
          _playerDuration = dur;
        });
      }
    });
  }

  void _setupWebSocketListener() {
    _wsSubscription = WebSocketService().messageStream.listen((data) {
      if (!mounted) return;
      if (data['type'] == 'chat_message') {
        final senderId = data['senderId'];
        final receiverId = data['receiverId'];

        // Message belongs to this chat
        if ((senderId == widget.contactId && receiverId == _currentUserId) ||
            (senderId == _currentUserId && receiverId == widget.contactId)) {
          // If we are currently viewing the chat, and it's sent by the other person, mark it as read on the backend
          if (senderId == widget.contactId) {
            _markMessageAsRead(data['id']);
          }

          setState(() {
            // Check if it already exists (e.g. sent optimistically)
            final index = _messages.indexWhere((m) => m['id'] == data['id']);
            if (index == -1) {
              _messages.add(data);
            } else {
              _messages[index] = data;
            }
          });
          _scrollToBottom();
        }
      } else if (data['type'] == 'chat_message_edit') {
        final senderId = data['senderId'];
        final receiverId = data['receiverId'];
        if ((senderId == widget.contactId && receiverId == _currentUserId) ||
            (senderId == _currentUserId && receiverId == widget.contactId)) {
          setState(() {
            final index = _messages.indexWhere((m) => m['id'] == data['id']);
            if (index != -1) {
              _messages[index]['content'] = data['content'];
            }
          });
        }
      } else if (data['type'] == 'chat_message_delete') {
        final senderId = data['senderId'];
        final receiverId = data['receiverId'];
        if ((senderId == widget.contactId && receiverId == _currentUserId) ||
            (senderId == _currentUserId && receiverId == widget.contactId)) {
          setState(() {
            _messages.removeWhere((m) => m['id'] == data['id']);
          });
        }
      }
    });
  }

  Future<void> _markMessageAsRead(int messageId) async {
    try {
      // Just a fire-and-forget or minor update request if backend has read endpoint.
      // In our GET /messages/{contactId} history, it already automatically marks all as read,
      // but we can make a lightweight request here or let the history fetch handle it.
    } catch (_) {}
  }

  Future<void> _fetchMessageHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiService.get('/api/chat/messages/${widget.contactId}');
      if (response.statusCode == 200) {
        final List<dynamic> history = jsonDecode(response.body);
        setState(() {
          _messages.clear();
          _messages.addAll(history);
          _isLoading = false;
        });
        _scrollToBottom();
      } else {
        setState(() {
          _isLoading = false;
        });
        if (!mounted) return;
        AppSnackBar.show(context, message: 'Хатогӣ дар боргирии таърихи паёмҳо', type: SnackBarType.error);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (!mounted) return;
      AppSnackBar.show(context, message: 'Мушкилии пайвастшавӣ ба сервер', type: SnackBarType.error);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showEditDialog(Map<String, dynamic> msg) {
    final editController = TextEditingController(text: msg['content']);
    showDialog(
      context: context,
      builder: (context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        final textColor = isDarkMode ? Colors.white : Colors.black87;
        return AlertDialog(
          title: const Text('Таҳрири паём'),
          content: TextField(
            controller: editController,
            autofocus: true,
            style: TextStyle(color: textColor),
            decoration: const InputDecoration(
              hintText: 'Паёми нав...',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Бекор кардан'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newText = editController.text.trim();
                if (newText.isNotEmpty) {
                  Navigator.pop(context);
                  await _submitMessageEdit(msg['id'], newText);
                }
              },
              child: const Text('Захира кардан'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitMessageEdit(dynamic messageId, String newContent) async {
    try {
      final response = await ApiService.put(
        '/api/chat/edit/$messageId',
        {'content': newContent},
      );
      if (response.statusCode == 200) {
        setState(() {
          final index = _messages.indexWhere((m) => m['id'] == messageId);
          if (index != -1) {
            _messages[index]['content'] = newContent;
          }
        });
      } else {
        if (!mounted) return;
        AppSnackBar.show(context, message: 'Хатогӣ дар таҳрири паём', type: SnackBarType.error);
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(context, message: 'Мушкилии пайвастшавӣ ба сервер', type: SnackBarType.error);
    }
  }

  Future<void> _deleteMsg(dynamic messageId, int index) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Нест кардани паём'),
          content: const Text('Оё шумо мехоҳед ин паёмро нест кунед?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Бекор кардан'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Нест кардан', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        final response = await ApiService.delete('/api/chat/delete/$messageId');
        if (response.statusCode == 200) {
          setState(() {
            _messages.removeWhere((m) => m['id'] == messageId);
          });
        } else {
          if (!mounted) return;
          AppSnackBar.show(context, message: 'Хатогӣ дар нест кардани паём', type: SnackBarType.error);
        }
      } catch (e) {
        if (!mounted) return;
        AppSnackBar.show(context, message: 'Мушкилии пайвастшавӣ ба сервер', type: SnackBarType.error);
      }
    }
  }

  void _showMsgOptions(dynamic msg, bool isMe, int index) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final voiceUrl = msg['voiceUrl'] as String?;
    final content = msg['content'] as String? ?? '';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.reply, color: textColor),
                title: Text('Ҷавоб додан', style: TextStyle(color: textColor)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _replyToMessage = {
                      'id': msg['id'],
                      'content': voiceUrl != null ? 'Паёми овозӣ' : content,
                      'senderName': isMe ? 'Шумо' : widget.contactName,
                    };
                  });
                },
              ),
              if (isMe && voiceUrl == null)
                ListTile(
                  leading: Icon(Icons.edit, color: textColor),
                  title: Text('Таҳрир кардан', style: TextStyle(color: textColor)),
                  onTap: () {
                    Navigator.pop(context);
                    _showEditDialog(msg);
                  },
                ),
              if (isMe)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Нест кардан', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteMsg(msg['id'], index);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  // Voice recording handlers
  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

        const config = RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        );

        await _audioRecorder.start(config, path: path);

        setState(() {
          _isRecording = true;
          _recordingPath = path;
          _recordingStartTime = DateTime.now();
          _recordingDuration = Duration.zero;
        });

        _recordingTimer?.cancel();
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted && _recordingStartTime != null) {
            setState(() {
              _recordingDuration = DateTime.now().difference(_recordingStartTime!);
            });
          }
        });
      } else {
        if (!mounted) return;
        AppSnackBar.show(context, message: 'Дастрасӣ ба микрофон дода нашуд', type: SnackBarType.warning);
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(context, message: 'Хатогӣ дар оғози сабти овоз', type: SnackBarType.error);
    }
  }

  Future<void> _cancelRecording() async {
    try {
      await _audioRecorder.stop();
      _recordingTimer?.cancel();

      if (_recordingPath != null) {
        final file = File(_recordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }

      setState(() {
        _isRecording = false;
        _recordingPath = null;
        _recordingDuration = Duration.zero;
      });
    } catch (_) {}
  }

  Future<void> _stopAndSendVoiceRecording() async {
    try {
      final path = await _audioRecorder.stop();
      _recordingTimer?.cancel();

      setState(() {
        _isRecording = false;
      });

      if (path != null) {
        final durationSec = _recordingDuration.inSeconds;
        if (durationSec < 1) {
          AppSnackBar.show(context, message: 'Сабти овоз хеле кӯтоҳ аст', type: SnackBarType.warning);
          return;
        }
        await _sendMessage(voicePath: path);
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(context, message: 'Хатогӣ дар захираи сабти овоз', type: SnackBarType.error);
    }
  }

  // Playback handlers
  Future<void> _toggleAudioPlay(int messageId, String voiceUrl) async {
    try {
      Source source;
      if (voiceUrl.startsWith('http') || voiceUrl.startsWith('https')) {
        source = UrlSource(ApiService.getFullImageUrl(voiceUrl));
      } else {
        source = DeviceFileSource(voiceUrl);
      }

      if (_playingMessageId == messageId) {
        if (_playerState == PlayerState.playing) {
          await _sharedAudioPlayer.pause();
        } else if (_playerState == PlayerState.paused) {
          await _sharedAudioPlayer.resume();
        } else {
          await _sharedAudioPlayer.play(source);
        }
      } else {
        await _sharedAudioPlayer.stop();
        setState(() {
          _playingMessageId = messageId;
          _playerPosition = Duration.zero;
          _playerDuration = Duration.zero;
        });
        await _sharedAudioPlayer.play(source);
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(context, message: 'Хатогӣ дар навозиши овоз', type: SnackBarType.error);
    }
  }

  // Send message API request
  Future<void> _sendMessage({String? content, String? voicePath}) async {
    if ((content == null || content.trim().isEmpty) && voicePath == null) return;

    final requestContent = content ?? '';
    final replyId = _replyToMessage?['id'];
    final tempId = -DateTime.now().millisecondsSinceEpoch;

    final optimisticMessage = {
      'id': tempId,
      'senderId': _currentUserId,
      'receiverId': widget.contactId,
      'content': requestContent,
      'isRead': false,
      'voiceUrl': voicePath,
      'replyToMessageId': replyId,
      'replyToMessageContent': _replyToMessage?['content'],
      'dateCreated': DateTime.now().toUtc().toIso8601String(),
      'status': 'pending',
    };

    setState(() {
      _messages.add(optimisticMessage);
      _replyToMessage = null;
    });
    _scrollToBottom();

    try {
      final Map<String, String> fields = {
        'receiverId': widget.contactId.toString(),
        'content': requestContent,
      };
      if (replyId != null) {
        fields['replyToMessageId'] = replyId.toString();
      }

      final response = await ApiService.sendMultipart(
        endpoint: '/api/chat/send',
        fields: fields,
        fileField: voicePath != null ? 'voice' : null,
        filePath: voicePath,
        fileName: voicePath != null ? 'voice_message.m4a' : null,
      );

      if (response.statusCode == 200) {
        final savedMsg = jsonDecode(response.body);
        setState(() {
          final index = _messages.indexWhere((m) => m['id'] == tempId);
          if (index != -1) {
            _messages[index] = savedMsg;
          }
        });
        _scrollToBottom();
      } else {
        setState(() {
          final index = _messages.indexWhere((m) => m['id'] == tempId);
          if (index != -1) {
            _messages[index]['status'] = 'error';
          }
        });
        if (!mounted) return;
        AppSnackBar.show(context, message: 'Паём фиристода нашуд', type: SnackBarType.error);
      }
    } catch (e) {
      setState(() {
        final index = _messages.indexWhere((m) => m['id'] == tempId);
        if (index != -1) {
          _messages[index]['status'] = 'error';
        }
      });
      if (!mounted) return;
      AppSnackBar.show(context, message: 'Хатогӣ дар пайвастшавӣ', type: SnackBarType.error);
    }
  }

  void _scrollToMessageById(int replyId) {
    final index = _messages.indexWhere((m) => m['id'] == replyId);
    if (index != -1) {
      // Very simple estimate scroll or index scroll:
      // Since ListView builder is dynamic, we can jump to a position based on average item height,
      // or simply animate to the estimated position.
      // Average height is ~80.
      final targetOffset = index * 85.0;
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  Widget _buildAudioPlayer(int messageId, String voiceUrl, bool isMe, Color themeColor) {
    final isPlaying = _playingMessageId == messageId;
    final playState = isPlaying ? _playerState : PlayerState.stopped;

    double progress = 0.0;
    if (isPlaying && _playerDuration.inMilliseconds > 0) {
      progress = _playerPosition.inMilliseconds / _playerDuration.inMilliseconds;
    }

    String timeText = '00:16';
    if (isPlaying) {
      final posSec = _playerPosition.inSeconds;
      final min = (posSec ~/ 60).toString().padLeft(2, '0');
      final sec = (posSec % 60).toString().padLeft(2, '0');
      timeText = '$min:$sec';
    }

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final activeWaveColor = isMe
        ? (isDarkMode ? Colors.white : const Color(0xFF1B6A2F))
        : Colors.white;
    final inactiveWaveColor = isMe
        ? (isDarkMode ? Colors.white.withOpacity(0.3) : const Color(0xFF9EBEA5))
        : Colors.white.withOpacity(0.4);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => _toggleAudioPlay(messageId, voiceUrl),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isMe 
                    ? (isDarkMode ? Colors.white.withOpacity(0.2) : Colors.black)
                    : Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                playState == PlayerState.playing ? Icons.pause : Icons.play_arrow,
                color: isMe 
                    ? (isDarkMode ? Colors.white : Colors.white)
                    : themeColor,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          WaveformPainter(
            progress: progress,
            activeColor: activeWaveColor,
            inactiveColor: inactiveWaveColor,
          ),
          const SizedBox(width: 12),
          Text(
            timeText,
            style: TextStyle(
              color: isMe
                  ? (isDarkMode ? Colors.white : const Color(0xFF111A13))
                  : Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageStatus(Map<String, dynamic> msg, Color msgTextColor) {
    final status = msg['status'] as String?;
    final isRead = msg['isRead'] as bool? ?? false;

    if (status == 'pending') {
      return Icon(
        Icons.access_time,
        size: 14,
        color: msgTextColor.withOpacity(0.5),
      );
    }

    if (status == 'error') {
      return const Icon(
        Icons.error_outline,
        size: 14,
        color: Colors.red,
      );
    }

    if (isRead) {
      return const Icon(
        Icons.done_all,
        size: 14,
        color: Colors.green,
      );
    } else {
      return Icon(
        Icons.done,
        size: 14,
        color: msgTextColor.withOpacity(0.4),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final theme = Theme.of(context);
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final themeColor = isDarkMode ? const Color(0xFFA3E635) : const Color(0xFF1E7431);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: isDarkMode ? Colors.black : theme.scaffoldBackgroundColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: themeColor.withOpacity(0.1),
                  backgroundImage: widget.contactImageUrl != null && widget.contactImageUrl!.isNotEmpty
                      ? CachedNetworkImageProvider(ApiService.getFullImageUrl(widget.contactImageUrl!))
                      : null,
                  child: widget.contactImageUrl != null && widget.contactImageUrl!.isNotEmpty
                      ? null
                      : Text(
                          widget.contactName.isNotEmpty ? widget.contactName[0].toUpperCase() : 'U',
                          style: TextStyle(color: themeColor, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDarkMode ? Colors.black : Colors.white,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.contactName,
                    style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Active now',
                    style: TextStyle(color: textColor.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.w400),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: textColor))
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.forum_outlined, size: 64, color: textColor.withOpacity(0.2)),
                            const SizedBox(height: 12),
                            Text(
                              'Сӯҳбатро оғоз кунед',
                              style: TextStyle(color: textColor.withOpacity(0.4), fontSize: 15),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isMe = msg['senderId'] == _currentUserId;
                          final content = msg['content'] as String? ?? '';
                          final voiceUrl = msg['voiceUrl'] as String?;
                          final replyToId = msg['replyToMessageId'] as int?;
                          final replyContent = msg['replyToMessageContent'] as String?;

                          final bubbleBg = isMe
                              ? (isDarkMode ? const Color(0xFF2E7D32) : const Color(0xFFD4FCD5))
                              : (isDarkMode ? const Color(0xFF1E4620) : const Color(0xFF1B6A2F));

                          final msgTextColor = isMe
                              ? (isDarkMode ? Colors.white : const Color(0xFF111A13))
                              : Colors.white;

                          DateTime? date;
                          if (msg['dateCreated'] != null) {
                            date = DateTime.parse(msg['dateCreated']).toLocal();
                          }
                          final timeStr = date != null ? _formatTimeStr(date) : '';

                          bool showDateSeparator = false;
                          if (index == 0) {
                            showDateSeparator = true;
                          } else {
                            final prevMsg = _messages[index - 1];
                            if (msg['dateCreated'] != null && prevMsg['dateCreated'] != null) {
                              final dateCurr = DateTime.parse(msg['dateCreated']).toLocal();
                              final datePrev = DateTime.parse(prevMsg['dateCreated']).toLocal();
                              if (dateCurr.year != datePrev.year || dateCurr.month != datePrev.month || dateCurr.day != datePrev.day) {
                                showDateSeparator = true;
                              }
                            }
                          }

                          final messageWidget = GestureDetector(
                            onTap: () {
                              if (msg['status'] == 'error') {
                                setState(() {
                                  _messages.removeAt(index);
                                });
                                _sendMessage(
                                  content: content.isEmpty ? null : content,
                                  voicePath: voiceUrl,
                                );
                              }
                            },
                            onLongPress: () {
                              if (msg['status'] == 'error' || msg['status'] == 'pending') return;
                              _showMsgOptions(msg, isMe, index);
                            },
                            child: Align(
                              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                              child: Column(
                                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 4),
                                    constraints: BoxConstraints(
                                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                                      minWidth: 80,
                                    ),
                                    decoration: BoxDecoration(
                                      color: bubbleBg,
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(16),
                                        topRight: const Radius.circular(16),
                                        bottomLeft: Radius.circular(isMe ? 16 : 4),
                                        bottomRight: Radius.circular(isMe ? 4 : 16),
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Reply context
                                          if (replyToId != null && replyContent != null) ...[
                                            GestureDetector(
                                              onTap: () => _scrollToMessageById(replyToId),
                                              child: Container(
                                                margin: const EdgeInsets.only(bottom: 6),
                                                padding: const EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withOpacity(0.05),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border(
                                                    left: BorderSide(
                                                      color: isMe ? Colors.white : themeColor,
                                                      width: 3,
                                                    ),
                                                  ),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      isMe ? 'Шумо' : widget.contactName,
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 11,
                                                        color: isMe ? Colors.white.withOpacity(0.9) : themeColor,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      replyContent,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: msgTextColor.withOpacity(0.7),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                          // Voice note vs Text content
                                          if (voiceUrl != null)
                                            SizedBox(
                                              width: 250,
                                              child: _buildAudioPlayer(msg['id'], voiceUrl, isMe, themeColor),
                                            )
                                          else
                                            Text(
                                              content,
                                              style: TextStyle(color: msgTextColor, fontSize: 14.5),
                                            ),
                                          if (msg['status'] == 'error') ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              'Хатогӣ. Бори дигар кӯшиш кунед',
                                              style: TextStyle(
                                                color: Colors.red[300],
                                                fontSize: 9.5,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Time and checkmark outside
                                  Padding(
                                    padding: EdgeInsets.only(
                                      left: isMe ? 0 : 8,
                                      right: isMe ? 8 : 0,
                                      bottom: 12,
                                    ),
                                    child: Row(
                                      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          timeStr,
                                          style: TextStyle(
                                            color: isDarkMode ? Colors.white38 : Colors.black45,
                                            fontSize: 10,
                                          ),
                                        ),
                                        if (isMe) ...[
                                          const SizedBox(width: 4),
                                          _buildMessageStatus(msg, isDarkMode ? Colors.white38 : Colors.black45),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );

                          if (showDateSeparator && date != null) {
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildDateSeparator(date, isDarkMode),
                                messageWidget,
                              ],
                            );
                          }
                          return messageWidget;
                        },
                      ),
          ),
          // Reply preview panel
          if (_replyToMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: isDarkMode ? Colors.grey[900] : Colors.grey[100],
              child: Row(
                children: [
                  const Icon(Icons.reply, color: Colors.grey, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _replyToMessage!['senderName'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: themeColor,
                          ),
                        ),
                        Text(
                          _replyToMessage!['content'],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.7)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      setState(() {
                        _replyToMessage = null;
                      });
                    },
                  ),
                ],
              ),
            ),
          // Input box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF161E18) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDarkMode ? Colors.white.withOpacity(0.08) : const Color(0xFFEFEFEF),
                  width: 1.0,
                ),
              ),
            ),
            child: SafeArea(
              child: _isRecording
                  ? Row(
                      children: [
                        const SizedBox(width: 8),
                        // Pulsing red indicator
                        const _PulsingRecordIcon(),
                        const SizedBox(width: 8),
                        Text(
                          'Сабт: ${_recordingDuration.inMinutes.toString().padLeft(2, '0')}:${(_recordingDuration.inSeconds % 60).toString().padLeft(2, '0')}',
                          style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: _cancelRecording,
                          child: const Text('Бекор кардан', style: TextStyle(color: Colors.red)),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          backgroundColor: Colors.green,
                          child: IconButton(
                            icon: const Icon(Icons.send, color: Colors.white),
                            onPressed: _stopAndSendVoiceRecording,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDarkMode ? Colors.white.withOpacity(0.05) : const Color(0xFFF6F6F6),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDarkMode ? Colors.white.withOpacity(0.15) : const Color(0xFF1E7431),
                                width: 1.5,
                              ),
                            ),
                            child: TextField(
                              controller: _textController,
                              textCapitalization: TextCapitalization.sentences,
                              minLines: 1,
                              maxLines: 5,
                              style: TextStyle(color: textColor, fontSize: 15),
                              decoration: InputDecoration(
                                hintText: 'Write your message',
                                hintStyle: TextStyle(
                                  color: isDarkMode ? Colors.white38 : const Color(0xFF9E9E9E),
                                  fontSize: 15,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.mic_none_outlined, color: Color(0xFF1E7431), size: 28),
                          onPressed: _startRecording,
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            color: Color(0xFF1E7431),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.send, color: Colors.white, size: 20),
                            onPressed: () {
                              final text = _textController.text.trim();
                              if (text.isNotEmpty) {
                                _textController.clear();
                                _sendMessage(content: text);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingRecordIcon extends StatefulWidget {
  const _PulsingRecordIcon();

  @override
  State<_PulsingRecordIcon> createState() => _PulsingRecordIconState();
}

class _PulsingRecordIconState extends State<_PulsingRecordIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.3, end: 1.0).animate(_controller),
      child: const Icon(Icons.fiber_manual_record, color: Colors.red),
    );
  }
}

class WaveformPainter extends StatelessWidget {
  final double progress;
  final Color activeColor;
  final Color inactiveColor;

  const WaveformPainter({
    super.key,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final heights = [10.0, 16.0, 8.0, 14.0, 20.0, 12.0, 18.0, 8.0, 15.0, 22.0, 10.0, 16.0, 12.0, 18.0, 8.0, 14.0, 10.0, 6.0];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(heights.length, (index) {
        final barProgress = index / heights.length;
        final color = barProgress <= progress ? activeColor : inactiveColor;
        return Container(
          width: 3,
          height: heights[index],
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1.5),
          ),
        );
      }),
    );
  }
}
