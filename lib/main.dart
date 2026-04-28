import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const String _appDisplayName = 'Happy Talk';
const String _agoraAppId = '717d9262657d4caab56f3d8a9a7b2089';
const String _defaultBackend = 'http://localhost:5000';
const List<String> _tokenPaths = <String>[
  '/api/rooms/token',
  '/rooms/token',
  '/api/token',
];
const List<String> _profileColors = <String>[
  '#10b981',
  '#3b82f6',
  '#8b5cf6',
  '#ef4444',
  '#f59e0b',
  '#ec4899',
  '#0ea5e9',
  '#22c55e',
  '#6366f1',
  '#14b8a6',
  '#f97316',
  '#e11d48',
];
const List<String> _profileEmojis = <String>[
  '\u{1F642}',
  '\u{1F60A}',
  '\u{1F91D}',
  '\u{1F499}',
  '\u{1F3A7}',
  '\u2728',
  '\u{1F98A}',
  '\u{1F43C}',
  '\u{1F680}',
  '\u{1F3A4}',
  '\u{1F3B5}',
  '\u26A1',
];

enum AppLang { en, fa }

enum AppTheme { dark, light }

enum StabilityMode { balanced, higher, high, ultra }

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HappyTalkApp());
}

class HappyTalkApp extends StatefulWidget {
  const HappyTalkApp({super.key});

  @override
  State<HappyTalkApp> createState() => _HappyTalkAppState();
}

class _HappyTalkAppState extends State<HappyTalkApp> {
  AppTheme _theme = AppTheme.dark;
  String _fontChoice = 'vazirmatn';

  TextTheme _pickFont(TextTheme source) {
    switch (_fontChoice) {
      case 'vazirmatn':
        return GoogleFonts.vazirmatnTextTheme(source);
      case 'manrope':
        return GoogleFonts.manropeTextTheme(source);
      case 'lora':
        return GoogleFonts.loraTextTheme(source);
      default:
        return source;
    }
  }

  void _onThemeChanged(AppTheme theme) {
    setState(() {
      _theme = theme;
    });
  }

  void _onFontChanged(String font) {
    setState(() {
      _fontChoice = font;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool dark = _theme == AppTheme.dark;
    final ThemeData base = dark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: _appDisplayName,
      theme: base.copyWith(
        textTheme: _pickFont(base.textTheme),
        scaffoldBackgroundColor: dark
            ? const Color(0xFF07131E)
            : const Color(0xFFEAF7FF),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          foregroundColor: dark ? Colors.white : const Color(0xFF103246),
        ),
        cardTheme: CardThemeData(
          color: dark ? const Color(0xCC0B2334) : const Color(0xD9F8FDFF),
          shadowColor: Colors.black45,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      home: HappyTalkHome(
        themeMode: _theme,
        onThemeChanged: _onThemeChanged,
        fontChoice: _fontChoice,
        onFontChanged: _onFontChanged,
      ),
    );
  }
}

class ContactItem {
  ContactItem({
    required this.uid,
    required this.name,
    required this.emoji,
    required this.color,
    required this.lastSeen,
    this.blocked = false,
  });

  final String uid;
  final String name;
  final String emoji;
  final String color;
  final int lastSeen;
  bool blocked;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'uid': uid,
    'name': name,
    'emoji': emoji,
    'color': color,
    'lastSeen': lastSeen,
    'blocked': blocked,
  };

  factory ContactItem.fromJson(Map<String, dynamic> map) => ContactItem(
    uid: map['uid'] as String? ?? '',
    name: map['name'] as String? ?? 'User',
    emoji: map['emoji'] as String? ?? '\u{1F642}',
    color: map['color'] as String? ?? '#10b981',
    lastSeen: map['lastSeen'] as int? ?? 0,
    blocked: map['blocked'] as bool? ?? false,
  );
}

class CallHistoryItem {
  CallHistoryItem({
    required this.room,
    required this.date,
    required this.duration,
    required this.quality,
    required this.type,
  });

  final String room;
  final String date;
  final int duration;
  final String quality;
  final String type;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'room': room,
    'date': date,
    'duration': duration,
    'quality': quality,
    'type': type,
  };

  factory CallHistoryItem.fromJson(Map<String, dynamic> map) => CallHistoryItem(
    room: map['room'] as String? ?? '',
    date: map['date'] as String? ?? '',
    duration: map['duration'] as int? ?? 0,
    quality: map['quality'] as String? ?? '-',
    type: map['type'] as String? ?? 'outgoing',
  );
}

class CallUser {
  CallUser({
    required this.agoraUid,
    required this.uid,
    required this.name,
    required this.emoji,
    required this.color,
    required this.network,
    required this.lastSeen,
  });

  final int agoraUid;
  final String uid;
  final String name;
  final String emoji;
  final String color;
  final String network;
  final int lastSeen;
}

class HappyTalkHome extends StatefulWidget {
  const HappyTalkHome({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
    required this.fontChoice,
    required this.onFontChanged,
  });

  final AppTheme themeMode;
  final ValueChanged<AppTheme> onThemeChanged;
  final String fontChoice;
  final ValueChanged<String> onFontChanged;

  @override
  State<HappyTalkHome> createState() => _HappyTalkHomeState();
}

class _HappyTalkHomeState extends State<HappyTalkHome> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _roomController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  final AudioRecorder _recorder = AudioRecorder();
  final Uuid _uuid = const Uuid();

  SharedPreferences? _prefs;
  RtcEngine? _engine;
  Timer? _timer;

  AppLang _lang = AppLang.fa;
  StabilityMode _stability = StabilityMode.balanced;

  bool _profileLoaded = false;
  bool _joinAsCreate = true;
  bool _showPassword = false;
  bool _joining = false;
  bool _inCall = false;
  bool _muted = false;
  bool _micLowered = false;
  bool _recording = false;
  bool _anonymous = false;
  bool _showHistory = false;

  String _backendUrl = _defaultBackend;
  String _selectedRingtone = 'ringtone_1';
  String _connectionQuality = '-';
  String _activeRoom = '';
  String _activeRoomKey = '';
  String _activeRoomPassword = '';
  String _profileUid = '';
  String _profileName = '';
  String _profileEmoji = '\u{1F642}';
  String _profileAvatarBase64 = '';
  Uint8List? _profileAvatarBytes;
  String _profileColor = '#10b981';
  String _profileGender = 'not_set';
  String _profileBirthDate = '';

  int _seconds = 0;
  int _profileCallSeconds = 0;
  int _profileSpeakingSeconds = 0;
  bool _mustConfigureBackend = false;
  int? _localAgoraUid;
  bool _localSpeaking = false;

  final Map<int, CallUser> _remoteUsers = <int, CallUser>{};
  final Map<int, bool> _speakingUsers = <int, bool>{};
  final Map<String, ContactItem> _contacts = <String, ContactItem>{};
  final List<CallHistoryItem> _history = <CallHistoryItem>[];

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _safeStopRecording();
    _nameController.dispose();
    _roomController.dispose();
    _passwordController.dispose();
    _searchController.dispose();
    _engine?.release();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _prefs = prefs;

    final String generatedUid = _buildPublicUid();
    _profileUid = prefs.getString('profile_uid') ?? generatedUid;
    _profileName = prefs.getString('profile_name') ?? '';
    _profileEmoji = prefs.getString('profile_emoji') ?? '\u{1F642}';
    _profileColor = prefs.getString('profile_color') ?? _profileColors.first;
    _profileGender = prefs.getString('profile_gender') ?? 'not_set';
    _profileBirthDate = prefs.getString('profile_birth_date') ?? '';
    _profileCallSeconds = prefs.getInt('profile_call_seconds') ?? 0;
    _profileSpeakingSeconds = prefs.getInt('profile_speaking_seconds') ?? 0;

    _backendUrl = prefs.getString('backend_url') ?? _defaultBackend;
    final bool backendOnboardingDone =
        prefs.getBool('backend_onboarding_done') ?? false;
    _selectedRingtone = prefs.getString('ringtone') ?? 'ringtone_1';
    _anonymous = prefs.getBool('anonymous') ?? false;
    _lang = (prefs.getString('lang') ?? 'fa') == 'en' ? AppLang.en : AppLang.fa;
    final String theme = prefs.getString('theme') ?? 'dark';
    widget.onThemeChanged(theme == 'light' ? AppTheme.light : AppTheme.dark);
    widget.onFontChanged(prefs.getString('font') ?? 'vazirmatn');
    _stability = _parseStability(prefs.getString('stability') ?? 'balanced');

    _nameController.text = _profileName;
    _profileAvatarBase64 = prefs.getString('profile_avatar_b64') ?? '';
    if (_profileAvatarBase64.isNotEmpty) {
      try {
        _profileAvatarBytes = base64Decode(_profileAvatarBase64);
      } catch (_) {
        _profileAvatarBase64 = '';
        _profileAvatarBytes = null;
      }
    }

    final String? rawContacts = prefs.getString('contacts');
    if (rawContacts != null && rawContacts.isNotEmpty) {
      final List<dynamic> decoded = jsonDecode(rawContacts) as List<dynamic>;
      for (final dynamic item in decoded) {
        final ContactItem contact = ContactItem.fromJson(
          item as Map<String, dynamic>,
        );
        _contacts[contact.uid] = contact;
      }
    }

    final String? rawHistory = prefs.getString('history');
    if (rawHistory != null && rawHistory.isNotEmpty) {
      final List<dynamic> decoded = jsonDecode(rawHistory) as List<dynamic>;
      for (final dynamic item in decoded) {
        _history.add(CallHistoryItem.fromJson(item as Map<String, dynamic>));
      }
    }

    if (mounted) {
      setState(() {
        _mustConfigureBackend =
            !backendOnboardingDone || _backendUrl.trim().isEmpty;
        _profileLoaded = true;
      });
    }

    await _saveState();
  }

  StabilityMode _parseStability(String value) {
    switch (value) {
      case 'higher':
        return StabilityMode.higher;
      case 'high':
        return StabilityMode.high;
      case 'ultra':
        return StabilityMode.ultra;
      default:
        return StabilityMode.balanced;
    }
  }

  Future<void> _saveState() async {
    final SharedPreferences? prefs = _prefs;
    if (prefs == null) return;

    await prefs.setString('profile_uid', _profileUid);
    await prefs.setString('profile_name', _profileName);
    await prefs.setString('profile_emoji', _profileEmoji);
    await prefs.setString('profile_color', _profileColor);
    await prefs.setString('profile_gender', _profileGender);
    await prefs.setString('profile_birth_date', _profileBirthDate);
    await prefs.setInt('profile_call_seconds', _profileCallSeconds);
    await prefs.setInt('profile_speaking_seconds', _profileSpeakingSeconds);
    await prefs.setString('backend_url', _backendUrl.trim());
    await prefs.setBool(
      'backend_onboarding_done',
      _backendUrl.trim().isNotEmpty,
    );
    await prefs.setString('ringtone', _selectedRingtone);
    await prefs.setBool('anonymous', _anonymous);
    await prefs.setString('profile_avatar_b64', _profileAvatarBase64);
    await prefs.setString('lang', _lang == AppLang.en ? 'en' : 'fa');
    await prefs.setString(
      'theme',
      widget.themeMode == AppTheme.light ? 'light' : 'dark',
    );
    await prefs.setString('font', widget.fontChoice);
    await prefs.setString('stability', _stability.name);

    final List<Map<String, dynamic>> contactsEncoded = _contacts.values
        .map((ContactItem e) => e.toJson())
        .toList();
    await prefs.setString('contacts', jsonEncode(contactsEncoded));

    final List<Map<String, dynamic>> historyEncoded = _history
        .map((CallHistoryItem e) => e.toJson())
        .toList();
    await prefs.setString('history', jsonEncode(historyEncoded));
  }

  String _buildPublicUid() {
    final String short = _uuid
        .v4()
        .replaceAll('-', '')
        .substring(0, 8)
        .toUpperCase();
    return 'VC-$short';
  }

  String _tr(String key) {
    final Map<String, String> en = <String, String>{
      'title': _appDisplayName,
      'subtitle': 'Private high quality voice communication',
      'name': 'Username',
      'room': 'Room Name',
      'password': 'Room Password',
      'create': 'Create Room',
      'join': 'Join Room',
      'start': 'Start Call',
      'joining': 'Connecting...',
      'settings': 'Settings',
      'contacts': 'Contacts',
      'history': 'History',
      'copyUid': 'Copy UID',
      'inviteCode': 'Room Invite Code',
      'copyInvite': 'Copy Code',
      'users': 'Users in Call',
      'mute': 'Mute',
      'unmute': 'Unmute',
      'lowerMic': 'Lower Mic',
      'normalMic': 'Normal Mic',
      'record': 'Record',
      'stopRecord': 'Stop',
      'leave': 'Leave',
      'quality': 'Connection',
      'backend': 'Backend URL',
      'theme': 'Theme',
      'font': 'Font',
      'stability': 'Stability',
      'save': 'Save',
      'search': 'Search UID',
      'blocked': 'Blocked',
      'all': 'All Contacts',
      'noContacts': 'No contacts yet',
      'noHistory': 'No call history',
      'profile': 'Profile',
      'anonymous': 'Anonymous mode',
      'gender': 'Gender',
      'birthDate': 'Birth date',
      'ringtone': 'Ringtone',
      'backendRequired': 'Set backend URL to continue',
      'saveAndContinue': 'Save & Continue',
      'deleteProfile': 'Delete Profile',
      'deleteProfileWarn': 'Delete profile permanently',
      'roomWithPass': 'Room & Password',
    };
    final Map<String, String> fa = <String, String>{
      'title': _appDisplayName,
      'subtitle': 'تماس صوتی خصوصی با کیفیت بالا',
      'name': 'نام کاربر',
      'room': 'نام روم',
      'password': 'پسورد روم',
      'create': 'ساخت روم',
      'join': 'ورود به روم',
      'start': 'شروع تماس',
      'joining': 'در حال اتصال...',
      'settings': 'تنظیمات',
      'contacts': 'مخاطبین',
      'history': 'تاریخچه',
      'copyUid': 'کپی UID',
      'inviteCode': 'کد دعوت روم',
      'copyInvite': 'کپی کد',
      'users': 'کاربران حاضر',
      'mute': 'قطع میکروفون',
      'unmute': 'وصل میکروفون',
      'lowerMic': 'کاهش میکروفون',
      'normalMic': 'میکروفون عادی',
      'record': 'ضبط',
      'stopRecord': 'توقف',
      'leave': 'خروج',
      'quality': 'کیفیت اتصال',
      'backend': 'آدرس بک‌اند',
      'theme': 'تم',
      'font': 'فونت',
      'stability': 'پایداری',
      'save': 'ذخیره',
      'search': 'جستجوی UID',
      'blocked': 'بلاک شده',
      'all': 'همه مخاطبین',
      'noContacts': 'مخاطبی وجود ندارد',
      'noHistory': 'تاریخچه‌ای نیست',
      'profile': 'پروفایل',
      'anonymous': 'حالت ناشناس',
      'gender': 'جنسیت',
      'birthDate': 'تاریخ تولد',
      'ringtone': 'رینگتون',
      'backendRequired': 'برای ادامه آدرس بک‌اند را تنظیم کنید',
      'saveAndContinue': 'ذخیره و ادامه',
      'deleteProfile': 'حذف پروفایل',
      'deleteProfileWarn': 'حذف دائمی پروفایل',
      'roomWithPass': 'نام و رمز روم',
    };

    return _lang == AppLang.en ? (en[key] ?? key) : (fa[key] ?? key);
  }

  Color _fromHex(String hex) {
    final String clean = hex.replaceAll('#', '');
    final String normalized = clean.length == 6 ? 'FF$clean' : clean;
    return Color(int.parse(normalized, radix: 16));
  }

  String _roomKey(String room) {
    return room.trim().toLowerCase().replaceAll(RegExp(r'[.#$/\[\]]'), '_');
  }

  bool _isPublicHttpUrl(String value) {
    final String v = value.trim().toLowerCase();
    if (!(v.startsWith('http://') || v.startsWith('https://'))) return false;
    if (v.contains('localhost') || v.contains('127.0.0.1')) return false;
    return true;
  }

  bool _isNgrokUrl(String value) {
    final String v = value.trim().toLowerCase();
    return v.contains('.ngrok-free.app') || v.contains('.ngrok.io');
  }

  bool _ensureMobileBackendIsReachable() {
    final String backend = _backendUrl.trim();
    if (backend.isEmpty) {
      _toast('Backend URL is empty.');
      return false;
    }

    // For real phone builds, localhost cannot reach your PC backend.
    if (!kIsWeb && !_isPublicHttpUrl(backend)) {
      _toast(
        'For phone build, use public backend URL (ngrok HTTPS). localhost/127.0.0.1 is invalid on device.',
      );
      return false;
    }

    // User explicitly asked to ensure ngrok connectivity in mobile build.
    if (!kIsWeb && !_isNgrokUrl(backend)) {
      _toast('Use your ngrok HTTPS URL in Backend settings for mobile build.');
      return false;
    }

    return true;
  }

  Future<Uint8List?> _pickImageBytes() async {
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (picked == null) return null;
      return await picked.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  Widget _profileAvatarWidget({
    required double radius,
    String? emoji,
    Uint8List? bytes,
    Color? background,
  }) {
    if (bytes != null && bytes.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: background ?? Colors.transparent,
        backgroundImage: MemoryImage(bytes),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: background ?? Colors.black26,
      child: Text(emoji ?? _profileEmoji, style: TextStyle(fontSize: radius)),
    );
  }

  String? _extractToken(dynamic payload) {
    if (payload == null) return null;

    if (payload is String) {
      final String value = payload.trim();
      if (value.isEmpty) return null;
      if (!value.startsWith('{') && value.length > 20) return value;
      try {
        final dynamic decoded = jsonDecode(value);
        return _extractToken(decoded);
      } catch (_) {
        return null;
      }
    }

    if (payload is Map<String, dynamic>) {
      const List<String> directKeys = <String>[
        'token',
        'rtcToken',
        'key',
        'accessToken',
        'agoraToken',
      ];
      for (final String key in directKeys) {
        final dynamic value = payload[key];
        if (value is String && value.trim().length > 20) {
          return value.trim();
        }
      }

      const List<String> nestedKeys = <String>['data', 'result', 'payload'];
      for (final String key in nestedKeys) {
        final String? token = _extractToken(payload[key]);
        if (token != null) return token;
      }
    }

    if (payload is List) {
      for (final dynamic item in payload) {
        final String? token = _extractToken(item);
        if (token != null) return token;
      }
    }

    return null;
  }

  Future<void> _initAgora() async {
    if (_engine != null) return;

    final RtcEngine engine = createAgoraRtcEngine();
    await engine.initialize(const RtcEngineContext(appId: _agoraAppId));

    engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          if (!mounted) return;
          setState(() {
            _localAgoraUid = connection.localUid;
            _inCall = true;
            _joining = false;
            _seconds = 0;
            _connectionQuality = 'good';
          });

          _timer?.cancel();
          _timer = Timer.periodic(const Duration(seconds: 1), (_) {
            if (!mounted || !_inCall) return;
            setState(() {
              _seconds += 1;
              _profileCallSeconds += 1;
            });
          });
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          if (!mounted) return;
          setState(() {
            _remoteUsers[remoteUid] = CallUser(
              agoraUid: remoteUid,
              uid: 'AG-$remoteUid',
              name: 'User $remoteUid',
              emoji: _profileEmojis[remoteUid % _profileEmojis.length],
              color: _profileColors[remoteUid % _profileColors.length],
              network: 'good',
              lastSeen: DateTime.now().millisecondsSinceEpoch,
            );
          });
        },
        onUserOffline:
            (
              RtcConnection connection,
              int remoteUid,
              UserOfflineReasonType reason,
            ) {
              if (!mounted) return;
              setState(() {
                _remoteUsers.remove(remoteUid);
                _speakingUsers.remove(remoteUid);
              });
            },
        onConnectionStateChanged:
            (
              RtcConnection connection,
              ConnectionStateType state,
              ConnectionChangedReasonType reason,
            ) {
              if (!mounted) return;
              if (state == ConnectionStateType.connectionStateReconnecting) {
                setState(() {
                  _connectionQuality = 'weak';
                });
              }
              if (state == ConnectionStateType.connectionStateDisconnected &&
                  _inCall) {
                _leaveCall(addHistory: true, type: 'dropped');
              }
            },
        onNetworkQuality:
            (
              RtcConnection connection,
              int remoteUid,
              QualityType txQuality,
              QualityType rxQuality,
            ) {
              if (!mounted) return;
              final int q = txQuality.index > rxQuality.index
                  ? txQuality.index
                  : rxQuality.index;
              setState(() {
                if (q <= QualityType.qualityGood.index) {
                  _connectionQuality = 'perfect';
                } else if (q <= QualityType.qualityPoor.index) {
                  _connectionQuality = 'good';
                } else if (q <= QualityType.qualityVbad.index) {
                  _connectionQuality = 'medium';
                } else {
                  _connectionQuality = 'weak';
                }
              });
            },
        onAudioVolumeIndication:
            (
              RtcConnection connection,
              List<AudioVolumeInfo> speakers,
              int speakerNumber,
              int totalVolume,
            ) {
              if (!mounted) return;

              final Map<int, bool> next = <int, bool>{};
              bool localSpeaking = false;

              for (final AudioVolumeInfo speaker in speakers) {
                final int uid = speaker.uid ?? 0;
                final int volume = speaker.volume ?? 0;
                final bool speaking = volume > 17;
                next[uid] = speaking;
                if (uid == 0 && speaking) {
                  localSpeaking = true;
                }
              }

              setState(() {
                _speakingUsers
                  ..clear()
                  ..addAll(next);
                _localSpeaking = localSpeaking && !_muted;
                if (_localSpeaking) {
                  _profileSpeakingSeconds += 1;
                }
              });
            },
      ),
    );

    await engine.enableAudio();
    await engine.setChannelProfile(
      ChannelProfileType.channelProfileCommunication,
    );
    await engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await engine.enableAudioVolumeIndication(
      interval: 300,
      smooth: 3,
      reportVad: true,
    );

    _engine = engine;
  }

  Map<String, String> _buildBackendHeaders(
    String baseUrl, {
    bool includeJson = false,
  }) {
    final Map<String, String> headers = <String, String>{};
    if (includeJson) {
      headers['Content-Type'] = 'application/json';
      headers['Accept'] = 'application/json';
    }
    if (baseUrl.toLowerCase().contains('ngrok')) {
      headers['ngrok-skip-browser-warning'] = 'true';
    }
    return headers;
  }

  Future<({String? token, int? uid, String? roomName, String debug})>
  _fetchToken({
    required String mode,
    required String roomName,
    required String roomPassword,
  }) async {
    final String base = _backendUrl.trim();
    if (base.isEmpty) {
      return (
        token: null,
        uid: null,
        roomName: null,
        debug: 'Backend URL is empty.',
      );
    }

    final String normalized = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
    final List<String> attemptLogs = <String>[];

    bool looksLikeTokenPath(String value) {
      final String v = value.toLowerCase();
      return v.endsWith('/rooms/token') ||
          v.endsWith('/api/rooms/token') ||
          v.endsWith('/api/token') ||
          v.endsWith('/token');
    }

    final List<Uri> candidateUris = <Uri>[];
    final Uri baseUri = Uri.parse(normalized);
    if (looksLikeTokenPath(normalized)) {
      candidateUris.add(baseUri);
    } else {
      for (final String path in _tokenPaths) {
        candidateUris.add(baseUri.resolve(path));
      }
      candidateUris.add(baseUri.resolve('/token'));
    }

    String? lastError;
    bool sawOnlyEndpointNotFound = true;

    for (final Uri uri in candidateUris) {
      if (uri.scheme != 'http' && uri.scheme != 'https') continue;

      try {
        for (int attempt = 1; attempt <= 3; attempt += 1) {
          final http.Response response = await http
              .post(
                uri,
                headers: _buildBackendHeaders(normalized, includeJson: true),
                body: jsonEncode(<String, dynamic>{
                  'mode': mode,
                  'roomName': roomName,
                  'roomPassword': roomPassword,
                }),
              )
              .timeout(const Duration(seconds: 6));

          attemptLogs.add(
            'POST ${uri.toString()} -> ${response.statusCode} (try $attempt)',
          );

          final String rawBody = utf8.decode(response.bodyBytes).trim();
          Map<String, dynamic> decoded = <String, dynamic>{};
          if (rawBody.isNotEmpty) {
            try {
              final dynamic parsed = jsonDecode(rawBody);
              if (parsed is Map<String, dynamic>) {
                decoded = parsed;
              }
            } catch (_) {}
          }

          if (response.statusCode >= 200 && response.statusCode < 300) {
            final String? token = _extractToken(decoded);
            if (token != null && token.isNotEmpty) {
              final dynamic rawUid =
                  decoded['uid'] ??
                  decoded['agoraUid'] ??
                  (decoded['data'] is Map<String, dynamic>
                      ? (decoded['data'] as Map<String, dynamic>)['uid']
                      : null);
              final int? uid = rawUid is int
                  ? rawUid
                  : int.tryParse((rawUid ?? '').toString());
              final String? finalRoom =
                  (decoded['roomName'] ??
                          decoded['channelName'] ??
                          (decoded['data'] is Map<String, dynamic>
                              ? (decoded['data']
                                    as Map<String, dynamic>)['roomName']
                              : null) ??
                          (decoded['data'] is Map<String, dynamic>
                              ? (decoded['data']
                                    as Map<String, dynamic>)['channelName']
                              : null))
                      ?.toString();

              return (
                token: token,
                uid: uid,
                roomName: finalRoom,
                debug: attemptLogs.join(' | '),
              );
            }
          }

          final String backendError =
              (decoded['error'] ?? decoded['message'] ?? 'Token endpoint error')
                  .toString();
          final bool maybeEndpointNotFound =
              response.statusCode == 404 ||
              response.statusCode == 405 ||
              response.statusCode == 501;
          if (!maybeEndpointNotFound) {
            sawOnlyEndpointNotFound = false;
          }

          if ((response.statusCode >= 500 ||
                  response.statusCode == 502 ||
                  response.statusCode == 504) &&
              attempt < 3) {
            await Future<void>.delayed(Duration(milliseconds: 450 * attempt));
            continue;
          }

          if (maybeEndpointNotFound && attempt < 3) {
            await Future<void>.delayed(Duration(milliseconds: 350 * attempt));
            continue;
          }

          lastError =
              '$backendError (status ${response.statusCode} @ ${uri.toString()})';
          break;
        }
      } catch (error) {
        attemptLogs.add('ERROR ${uri.toString()} -> $error');
        sawOnlyEndpointNotFound = false;
        lastError = error.toString();
      }
    }

    if (sawOnlyEndpointNotFound) {
      lastError =
          'Backend endpoint is invalid (404/405/501). Use your Node/ngrok backend URL, not frontend URL.';
    }

    final String debug = [
      if (lastError != null && lastError.isNotEmpty) lastError,
      attemptLogs.join(' | '),
    ].where((String e) => e.trim().isNotEmpty).join(' | ');

    return (token: null, uid: null, roomName: null, debug: debug);
  }

  Future<void> _startCall() async {
    if (_joining || _inCall) return;

    final String inputName = _nameController.text.trim();
    final String room = _roomController.text.trim();
    final String password = _passwordController.text.trim();

    if (room.isEmpty) {
      _toast(_tr('room'));
      return;
    }

    if (inputName.isEmpty && !_anonymous) {
      _toast(_tr('name'));
      return;
    }

    if (!_ensureMobileBackendIsReachable()) {
      return;
    }

    setState(() {
      _joining = true;
    });

    final PermissionStatus mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      if (mounted) {
        setState(() {
          _joining = false;
        });
      }
      _toast('Microphone permission denied');
      return;
    }

    _profileName = inputName;
    await _saveState();

    final String key = _roomKey(room);
    final String? existingPass = _prefs?.getString('room_pass_$key');

    if (_joinAsCreate) {
      await _prefs?.setString('room_pass_$key', password);
    } else {
      if ((existingPass ?? '').isNotEmpty && existingPass != password) {
        if (mounted) {
          setState(() {
            _joining = false;
          });
        }
        _toast('Wrong room password');
        return;
      }
    }

    try {
      await _initAgora();
      final ({String? token, int? uid, String? roomName, String debug})
      tokenResult = await _fetchToken(
        mode: _joinAsCreate ? 'create' : 'join',
        roomName: room,
        roomPassword: password,
      );
      final String token = tokenResult.token ?? '';
      final int joinUid = tokenResult.uid ?? 0;
      final String joinChannel = (tokenResult.roomName ?? key).trim().isEmpty
          ? key
          : (tokenResult.roomName ?? key).trim();
      final RtcEngine? engine = _engine;
      if (engine == null) throw Exception('Agora engine not initialized');

      if (kIsWeb && token.isEmpty) {
        final List<String> parts = tokenResult.debug
            .split(' | ')
            .where((String e) => e.trim().isNotEmpty)
            .toList();
        final String compactDebug = parts.length > 4
            ? parts.sublist(parts.length - 4).join(' | ')
            : tokenResult.debug;
        if (mounted) {
          setState(() {
            _joining = false;
          });
        }
        _toast(
          'Token API error. Backend did not return RTC token. $compactDebug',
        );
        return;
      }

      setState(() {
        _activeRoom = joinChannel;
        _activeRoomKey = _roomKey(joinChannel);
        _activeRoomPassword = password;
        _remoteUsers.clear();
        _speakingUsers.clear();
        _localSpeaking = false;
      });

      await engine.joinChannel(
        token: token,
        channelId: joinChannel,
        uid: joinUid,
        options: const ChannelMediaOptions(
          autoSubscribeAudio: true,
          publishMicrophoneTrack: true,
          channelProfile: ChannelProfileType.channelProfileCommunication,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _joining = false;
        });
      }
      if (kIsWeb &&
          e.toString().toLowerCase().contains('createirisapiengine')) {
        _toast(
          'Join failed: Agora Web engine script is missing. Reload page after checking iris-web script.',
        );
        return;
      }
      if (e.toString().toLowerCase().contains('dynamic use static key')) {
        _toast(
          'Join failed: backend token is missing/invalid for certificate mode.',
        );
        return;
      }
      _toast('Join failed: $e');
    }
  }

  Future<void> _cleanupRoomViaBackend(String roomName, String roomKey) async {
    final String base = _backendUrl.trim();
    if (base.isEmpty) return;
    final String normalized = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
    final Uri baseUri = Uri.parse(normalized);
    final List<String> paths = <String>[
      '/api/rooms/cleanup',
      '/rooms/cleanup',
      '/api/rooms/leave',
      '/rooms/leave',
      '/api/rooms/end',
      '/rooms/end',
    ];

    for (final String path in paths) {
      final Uri uri = baseUri.resolve(path);
      try {
        final http.Response response = await http
            .post(
              uri,
              headers: _buildBackendHeaders(normalized, includeJson: true),
              body: jsonEncode(<String, dynamic>{
                'roomName': roomName,
                'roomKey': roomKey,
                'uid': _profileUid,
                'username': _profileName,
                'roomPassword': _activeRoomPassword,
              }),
            )
            .timeout(const Duration(seconds: 5));
        if (response.statusCode >= 200 && response.statusCode < 300) return;
      } catch (_) {
        continue;
      }
    }
  }

  Future<void> _leaveCall({
    required bool addHistory,
    String type = 'outgoing',
  }) async {
    _timer?.cancel();
    _timer = null;

    await _safeStopRecording();

    final String roomToCleanupName = _activeRoom;
    final String roomToCleanupKey = _activeRoomKey;

    try {
      await _engine?.leaveChannel();
    } catch (_) {}

    if (roomToCleanupName.isNotEmpty || roomToCleanupKey.isNotEmpty) {
      await _cleanupRoomViaBackend(roomToCleanupName, roomToCleanupKey);
    }

    if (addHistory && _activeRoom.isNotEmpty) {
      _history.insert(
        0,
        CallHistoryItem(
          room: _activeRoom,
          date: DateTime.now().toIso8601String(),
          duration: _seconds,
          quality: _connectionQuality,
          type: type,
        ),
      );
    }

    if (mounted) {
      setState(() {
        _inCall = false;
        _joining = false;
        _muted = false;
        _micLowered = false;
        _recording = false;
        _seconds = 0;
        _localSpeaking = false;
        _activeRoom = '';
        _activeRoomKey = '';
        _activeRoomPassword = '';
        _remoteUsers.clear();
        _speakingUsers.clear();
      });
    }

    await _saveState();
  }

  Future<void> _toggleMute() async {
    final bool next = !_muted;
    await _engine?.muteLocalAudioStream(next);
    if (mounted) {
      setState(() {
        _muted = next;
      });
    }
  }

  Future<void> _toggleMicGain() async {
    final bool next = !_micLowered;
    await _engine?.adjustRecordingSignalVolume(next ? 35 : 100);
    if (mounted) {
      setState(() {
        _micLowered = next;
      });
    }
  }

  Future<void> _toggleRecording() async {
    if (_recording) {
      final String? path = await _safeStopRecording();
      if (mounted) {
        setState(() {
          _recording = false;
        });
      }
      if (path != null && path.isNotEmpty) {
        _toast('Recorded: $path');
      }
      return;
    }

    final bool hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      _toast('Recording permission denied');
      return;
    }

    final dir = await getTemporaryDirectory();
    final String filePath =
        '${dir.path}/happy_talk_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: filePath,
    );

    if (mounted) {
      setState(() {
        _recording = true;
      });
    }
  }

  Future<String?> _safeStopRecording() async {
    if (!_recording) return null;
    try {
      return await _recorder.stop();
    } catch (_) {
      return null;
    }
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _formatTimer(int totalSeconds) {
    final int m = totalSeconds ~/ 60;
    final int s = totalSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _formatDate(String iso) {
    final DateTime? dt = DateTime.tryParse(iso);
    if (dt == null) return '-';
    return DateFormat('yyyy-MM-dd HH:mm').format(dt);
  }

  CallUser _localUser() => CallUser(
    agoraUid: _localAgoraUid ?? 0,
    uid: _profileUid,
    name: _anonymous
        ? 'Anonymous'
        : (_profileName.isNotEmpty ? _profileName : 'User'),
    emoji: _profileEmoji,
    color: _profileColor,
    network: _connectionQuality,
    lastSeen: DateTime.now().millisecondsSinceEpoch,
  );

  List<CallUser> _allUsers() {
    final List<CallUser> users = <CallUser>[_localUser()];
    users.addAll(_remoteUsers.values);
    return users;
  }

  void _addContact(CallUser user) {
    if (user.uid.isEmpty || user.uid == _profileUid) return;
    if (_contacts[user.uid]?.blocked ?? false) return;

    _contacts[user.uid] = ContactItem(
      uid: user.uid,
      name: user.name,
      emoji: user.emoji,
      color: user.color,
      lastSeen: DateTime.now().millisecondsSinceEpoch,
    );

    _saveState();
    _toast('Added ${user.name}');
    setState(() {});
  }

  void _openProfileEditor() {
    final TextEditingController name = TextEditingController(
      text: _profileName,
    );
    final TextEditingController birth = TextEditingController(
      text: _profileBirthDate,
    );
    String gender = _profileGender;
    String emoji = _profileEmoji;
    String color = _profileColor;
    String avatarBase64 = _profileAvatarBase64;
    Uint8List? avatarBytes = _profileAvatarBytes;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder:
              (BuildContext context, void Function(void Function()) setModal) {
                return SafeArea(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 16,
                      bottom: MediaQuery.of(context).viewInsets.bottom + 18,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            _tr('profile'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Center(
                            child: Column(
                              children: <Widget>[
                                _profileAvatarWidget(
                                  radius: 34,
                                  emoji: emoji,
                                  bytes: avatarBytes,
                                  background: _fromHex(color),
                                ),
                                TextButton.icon(
                                  onPressed: () async {
                                    final Uint8List? picked =
                                        await _pickImageBytes();
                                    if (picked == null) return;
                                    setModal(() {
                                      avatarBytes = picked;
                                      avatarBase64 = base64Encode(picked);
                                    });
                                  },
                                  icon: const Icon(Icons.image_outlined),
                                  label: const Text('Upload Profile Photo'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: name,
                            decoration: InputDecoration(labelText: _tr('name')),
                          ),
                          TextField(
                            controller: birth,
                            decoration: InputDecoration(
                              labelText: _tr('birthDate'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: _profileEmojis
                                .map(
                                  (String value) => ChoiceChip(
                                    label: Text(
                                      value,
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                    selected: emoji == value,
                                    onSelected: (_) =>
                                        setModal(() => emoji = value),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: _profileColors
                                .map(
                                  (String value) => GestureDetector(
                                    onTap: () => setModal(() => color = value),
                                    child: Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        color: _fromHex(value),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: color == value
                                              ? Colors.white
                                              : Colors.transparent,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: gender,
                            decoration: InputDecoration(
                              labelText: _tr('gender'),
                            ),
                            items: const <DropdownMenuItem<String>>[
                              DropdownMenuItem<String>(
                                value: 'not_set',
                                child: Text('Not set'),
                              ),
                              DropdownMenuItem<String>(
                                value: 'male',
                                child: Text('Male'),
                              ),
                              DropdownMenuItem<String>(
                                value: 'female',
                                child: Text('Female'),
                              ),
                            ],
                            onChanged: (String? value) {
                              if (value == null) return;
                              setModal(() => gender = value);
                            },
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                Navigator.of(this.context).pop();
                                await _deleteProfileCompletely();
                              },
                              icon: const Icon(
                                Icons.delete_forever,
                                color: Colors.redAccent,
                              ),
                              label: Text(
                                _tr('deleteProfileWarn'),
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: () async {
                                _profileName = name.text.trim();
                                _profileBirthDate = birth.text.trim();
                                _profileGender = gender;
                                _profileEmoji = emoji;
                                _profileColor = color;
                                _profileAvatarBase64 = avatarBase64;
                                _profileAvatarBytes = avatarBytes;
                                _nameController.text = _profileName;
                                await _saveState();
                                if (!mounted) return;
                                setState(() {});
                                Navigator.of(this.context).pop();
                              },
                              child: Text(_tr('save')),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
        );
      },
    );
  }

  void _openSettings() {
    final TextEditingController backend = TextEditingController(
      text: _backendUrl,
    );
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: StatefulBuilder(
            builder:
                (
                  BuildContext context,
                  void Function(void Function()) setModal,
                ) {
                  return Padding(
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 16,
                      bottom: MediaQuery.of(context).viewInsets.bottom + 18,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            _tr('settings'),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile(
                            value: _anonymous,
                            onChanged: (bool value) =>
                                setModal(() => _anonymous = value),
                            title: Text(_tr('anonymous')),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: backend,
                            decoration: InputDecoration(
                              labelText: _tr('backend'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<AppTheme>(
                            initialValue: widget.themeMode,
                            decoration: InputDecoration(
                              labelText: _tr('theme'),
                            ),
                            items: const <DropdownMenuItem<AppTheme>>[
                              DropdownMenuItem<AppTheme>(
                                value: AppTheme.dark,
                                child: Text('Dark'),
                              ),
                              DropdownMenuItem<AppTheme>(
                                value: AppTheme.light,
                                child: Text('Light'),
                              ),
                            ],
                            onChanged: (AppTheme? value) {
                              if (value == null) return;
                              widget.onThemeChanged(value);
                              setModal(() {});
                            },
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: widget.fontChoice,
                            decoration: InputDecoration(labelText: _tr('font')),
                            items: const <DropdownMenuItem<String>>[
                              DropdownMenuItem<String>(
                                value: 'vazirmatn',
                                child: Text('Vazirmatn'),
                              ),
                              DropdownMenuItem<String>(
                                value: 'manrope',
                                child: Text('Manrope'),
                              ),
                              DropdownMenuItem<String>(
                                value: 'lora',
                                child: Text('Lora'),
                              ),
                              DropdownMenuItem<String>(
                                value: 'system',
                                child: Text('System'),
                              ),
                            ],
                            onChanged: (String? value) {
                              if (value == null) return;
                              widget.onFontChanged(value);
                              setModal(() {});
                            },
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<StabilityMode>(
                            initialValue: _stability,
                            decoration: InputDecoration(
                              labelText: _tr('stability'),
                            ),
                            items: const <DropdownMenuItem<StabilityMode>>[
                              DropdownMenuItem<StabilityMode>(
                                value: StabilityMode.balanced,
                                child: Text('Balanced'),
                              ),
                              DropdownMenuItem<StabilityMode>(
                                value: StabilityMode.higher,
                                child: Text('Higher'),
                              ),
                              DropdownMenuItem<StabilityMode>(
                                value: StabilityMode.high,
                                child: Text('High'),
                              ),
                              DropdownMenuItem<StabilityMode>(
                                value: StabilityMode.ultra,
                                child: Text('Ultra'),
                              ),
                            ],
                            onChanged: (StabilityMode? value) {
                              if (value == null) return;
                              setModal(() => _stability = value);
                            },
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedRingtone,
                            decoration: InputDecoration(
                              labelText: _tr('ringtone'),
                            ),
                            items: const <DropdownMenuItem<String>>[
                              DropdownMenuItem<String>(
                                value: 'ringtone_1',
                                child: Text('Ringtone 1'),
                              ),
                              DropdownMenuItem<String>(
                                value: 'ringtone_2',
                                child: Text('Ringtone 2'),
                              ),
                              DropdownMenuItem<String>(
                                value: 'ringtone_3',
                                child: Text('Ringtone 3'),
                              ),
                              DropdownMenuItem<String>(
                                value: 'ringtone_4',
                                child: Text('Ringtone 4'),
                              ),
                              DropdownMenuItem<String>(
                                value: 'ringtone_5',
                                child: Text('Ringtone 5'),
                              ),
                              DropdownMenuItem<String>(
                                value: 'ringtone_6',
                                child: Text('Ringtone 6'),
                              ),
                            ],
                            onChanged: (String? value) {
                              if (value == null) return;
                              setModal(() => _selectedRingtone = value);
                              SystemSound.play(SystemSoundType.click);
                            },
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: () async {
                                _backendUrl = backend.text.trim();
                                await _saveState();
                                if (!mounted) return;
                                setState(() {});
                                Navigator.of(this.context).pop();
                              },
                              child: Text(_tr('save')),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
          ),
        );
      },
    );
  }

  Future<void> _deleteProfileViaBackend() async {
    final String base = _backendUrl.trim();
    if (base.isEmpty) return;
    final String normalized = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
    final Uri baseUri = Uri.parse(normalized);
    final List<String> paths = <String>[
      '/api/profile/delete',
      '/profile/delete',
      '/api/users/delete',
      '/users/delete',
      '/api/profile/remove',
      '/profile/remove',
    ];

    for (final String path in paths) {
      final Uri uri = baseUri.resolve(path);
      try {
        final http.Response response = await http
            .post(
              uri,
              headers: _buildBackendHeaders(normalized, includeJson: true),
              body: jsonEncode(<String, dynamic>{
                'uid': _profileUid,
                'roomName': _activeRoom,
                'roomKey': _activeRoomKey,
              }),
            )
            .timeout(const Duration(seconds: 6));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return;
        }
      } catch (_) {
        continue;
      }
    }
  }

  Future<void> _deleteProfileCompletely() async {
    if (_inCall) {
      await _leaveCall(addHistory: true, type: 'outgoing');
    }

    await _deleteProfileViaBackend();

    final SharedPreferences? prefs = _prefs;
    await prefs?.remove('profile_uid');
    await prefs?.remove('profile_name');
    await prefs?.remove('profile_emoji');
    await prefs?.remove('profile_color');
    await prefs?.remove('profile_gender');
    await prefs?.remove('profile_birth_date');
    await prefs?.remove('profile_call_seconds');
    await prefs?.remove('profile_speaking_seconds');
    await prefs?.remove('profile_avatar_b64');
    await prefs?.remove('contacts');
    await prefs?.remove('history');

    final String newUid = _buildPublicUid();
    if (!mounted) return;
    setState(() {
      _profileUid = newUid;
      _profileName = '';
      _profileEmoji = '\u{1F642}';
      _profileAvatarBase64 = '';
      _profileAvatarBytes = null;
      _profileColor = _profileColors.first;
      _profileGender = 'not_set';
      _profileBirthDate = '';
      _profileCallSeconds = 0;
      _profileSpeakingSeconds = 0;
      _nameController.text = '';
      _contacts.clear();
      _history.clear();
    });
    await _saveState();
    _toast('Profile deleted');
  }

  void _openContacts() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder:
              (BuildContext context, void Function(void Function()) setModal) {
                final List<ContactItem> visible =
                    _contacts.values.where((ContactItem c) {
                      final String q = _searchController.text
                          .trim()
                          .toLowerCase();
                      if (q.isEmpty) return true;
                      return c.uid.toLowerCase().contains(q) ||
                          c.name.toLowerCase().contains(q);
                    }).toList()..sort(
                      (ContactItem a, ContactItem b) =>
                          b.lastSeen.compareTo(a.lastSeen),
                    );

                return SafeArea(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 16,
                      bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                    ),
                    child: Column(
                      children: <Widget>[
                        TextField(
                          controller: _searchController,
                          onChanged: (_) => setModal(() {}),
                          decoration: InputDecoration(
                            labelText: _tr('search'),
                            suffixIcon: const Icon(Icons.search),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: visible.isEmpty
                              ? Center(child: Text(_tr('noContacts')))
                              : ListView.separated(
                                  itemBuilder:
                                      (BuildContext context, int index) {
                                        final ContactItem item = visible[index];
                                        return ListTile(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          tileColor: Theme.of(
                                            context,
                                          ).cardColor.withValues(alpha: 0.45),
                                          leading: CircleAvatar(
                                            backgroundColor: _fromHex(
                                              item.color,
                                            ),
                                            child: Text(item.emoji),
                                          ),
                                          title: Text(item.name),
                                          subtitle: Text(item.uid),
                                          trailing: Wrap(
                                            spacing: 8,
                                            children: <Widget>[
                                              IconButton(
                                                icon: const Icon(Icons.copy),
                                                onPressed: () {
                                                  Clipboard.setData(
                                                    ClipboardData(
                                                      text: item.uid,
                                                    ),
                                                  );
                                                  _toast('UID copied');
                                                },
                                              ),
                                              IconButton(
                                                icon: Icon(
                                                  item.blocked
                                                      ? Icons.check
                                                      : Icons.block,
                                                ),
                                                onPressed: () async {
                                                  item.blocked = !item.blocked;
                                                  await _saveState();
                                                  setModal(() {});
                                                },
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                  separatorBuilder:
                                      (BuildContext context, int index) =>
                                          const SizedBox(height: 8),
                                  itemCount: visible.length,
                                ),
                        ),
                      ],
                    ),
                  ),
                );
              },
        );
      },
    );
  }

  Widget _glassPanel({required Widget child, double radius = 26}) {
    final bool dark = widget.themeMode == AppTheme.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? <Color>[const Color(0xB50B2233), const Color(0x8A0A1A28)]
                  : <Color>[const Color(0xD9FFFFFF), const Color(0xBFEAFAFF)],
            ),
            border: Border.all(
              color: dark ? const Color(0x59B8D6EA) : const Color(0x66A8CEE3),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: dark ? const Color(0x8A020A12) : const Color(0x4D6C8EA5),
                blurRadius: 26,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _entryView() {
    final Color accent = _fromHex(_profileColor);

    return Padding(
      padding: const EdgeInsets.all(8),
      child: _glassPanel(
        child: SizedBox.expand(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: accent.withValues(alpha: 0.5)),
                    gradient: LinearGradient(
                      colors: <Color>[
                        accent.withValues(alpha: 0.22),
                        accent.withValues(alpha: 0.08),
                      ],
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.record_voice_over, color: accent),
                      const SizedBox(width: 8),
                      Text(
                        'Happy Talk',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          color: widget.themeMode == AppTheme.dark
                              ? Colors.white
                              : const Color(0xFF103246),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    _profileAvatarWidget(
                      radius: 20,
                      bytes: _profileAvatarBytes,
                      emoji: _profileEmoji,
                      background: accent,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            _tr('title'),
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              color: widget.themeMode == AppTheme.dark
                                  ? Colors.white
                                  : const Color(0xFF0E3147),
                            ),
                          ),
                          Text(
                            _tr('subtitle'),
                            style: TextStyle(
                              color: Theme.of(context).hintColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    DropdownButton<AppLang>(
                      value: _lang,
                      onChanged: (AppLang? value) async {
                        if (value == null) return;
                        setState(() {
                          _lang = value;
                        });
                        await _saveState();
                      },
                      items: const <DropdownMenuItem<AppLang>>[
                        DropdownMenuItem<AppLang>(
                          value: AppLang.en,
                          child: Text('EN'),
                        ),
                        DropdownMenuItem<AppLang>(
                          value: AppLang.fa,
                          child: Text('FA'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: accent.withValues(alpha: 0.18),
                    border: Border.all(color: accent.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'UID: $_profileUid',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _profileUid));
                          _toast('UID copied');
                        },
                        icon: const Icon(Icons.copy, size: 18),
                        tooltip: _tr('copyUid'),
                      ),
                      IconButton(
                        onPressed: _openProfileEditor,
                        icon: const Icon(Icons.edit, size: 18),
                        tooltip: _tr('profile'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(labelText: _tr('name')),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _roomController,
                  decoration: InputDecoration(labelText: _tr('room')),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordController,
                  obscureText: !_showPassword,
                  decoration: InputDecoration(
                    labelText: _tr('password'),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                      icon: Icon(
                        _showPassword ? Icons.visibility_off : Icons.visibility,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: () => setState(() => _joinAsCreate = true),
                        style: FilledButton.styleFrom(
                          backgroundColor: _joinAsCreate
                              ? accent.withValues(alpha: 0.35)
                              : null,
                        ),
                        child: Text(_tr('create')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: () => setState(() => _joinAsCreate = false),
                        style: FilledButton.styleFrom(
                          backgroundColor: !_joinAsCreate
                              ? accent.withValues(alpha: 0.35)
                              : null,
                        ),
                        child: Text(_tr('join')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: _joining ? null : _startCall,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(_joining ? _tr('joining') : _tr('start')),
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: _openSettings,
                      icon: const Icon(Icons.settings),
                      label: Text(_tr('settings')),
                    ),
                    OutlinedButton.icon(
                      onPressed: _openContacts,
                      icon: const Icon(Icons.group),
                      label: Text(_tr('contacts')),
                    ),
                    OutlinedButton.icon(
                      onPressed: () =>
                          setState(() => _showHistory = !_showHistory),
                      icon: const Icon(Icons.history),
                      label: Text(_tr('history')),
                    ),
                  ],
                ),
                if (_showHistory) ...<Widget>[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 180,
                    child: _history.isEmpty
                        ? Center(child: Text(_tr('noHistory')))
                        : ListView.separated(
                            itemBuilder: (BuildContext context, int index) {
                              final CallHistoryItem item = _history[index];
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(item.room),
                                subtitle: Text(
                                  '${_formatDate(item.date)} • ${_formatTimer(item.duration)} • ${item.quality}',
                                ),
                                trailing: Text(item.type),
                              );
                            },
                            separatorBuilder:
                                (BuildContext context, int index) =>
                                    const Divider(height: 8),
                            itemCount: _history.length,
                          ),
                  ),
                ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _backendOnboardingView() {
    final TextEditingController backendController = TextEditingController(
      text: _backendUrl,
    );
    return Padding(
      padding: const EdgeInsets.all(12),
      child: _glassPanel(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Happy Talk',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 28,
                  color: _fromHex(_profileColor),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _tr('backendRequired'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: backendController,
                decoration: InputDecoration(labelText: _tr('backend')),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () async {
                  final String next = backendController.text.trim();
                  if (next.isEmpty) {
                    _toast(_tr('backendRequired'));
                    return;
                  }
                  _backendUrl = next;
                  await _saveState();
                  if (!mounted) return;
                  setState(() {
                    _mustConfigureBackend = false;
                  });
                },
                child: Text(_tr('saveAndContinue')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _userChip(CallUser user, {required bool isSelf}) {
    final bool speaking = isSelf
        ? _localSpeaking
        : (_speakingUsers[user.agoraUid] ?? false);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: speaking ? Colors.greenAccent : Colors.white24,
          width: 1.2,
        ),
        gradient: LinearGradient(
          colors: <Color>[
            _fromHex(user.color).withValues(alpha: speaking ? 0.75 : 0.35),
            _fromHex(user.color).withValues(alpha: speaking ? 0.55 : 0.22),
          ],
        ),
      ),
      child: Row(
        children: <Widget>[
          isSelf
              ? _profileAvatarWidget(
                  radius: 14,
                  bytes: _profileAvatarBytes,
                  emoji: user.emoji,
                  background: Colors.black26,
                )
              : CircleAvatar(
                  backgroundColor: Colors.black26,
                  child: Text(user.emoji),
                ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  user.uid,
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                  maxLines: 1,
                ),
              ],
            ),
          ),
          if (!isSelf)
            IconButton(
              onPressed: () => _addContact(user),
              icon: const Icon(Icons.person_add_alt_1, size: 18),
              tooltip: 'Add contact',
            ),
          Icon(
            speaking
                ? Icons.graphic_eq
                : (isSelf && _muted ? Icons.mic_off : Icons.circle),
            size: 16,
            color: speaking ? Colors.greenAccent : Colors.white70,
          ),
        ],
      ),
    );
  }

  Widget _callView() {
    final List<CallUser> users = _allUsers();

    return Padding(
      padding: const EdgeInsets.all(8),
      child: _glassPanel(
        child: SizedBox.expand(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Happy Talk',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: _fromHex(_profileColor),
                            ),
                          ),
                          Text(
                            _activeRoom,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text('${_tr('quality')}: $_connectionQuality'),
                        ],
                      ),
                    ),
                    Chip(label: Text(_stability.name.toUpperCase())),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.black26,
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.graphic_eq),
                      const SizedBox(width: 8),
                      Text(
                        _formatTimer(_seconds),
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _localSpeaking
                              ? Colors.greenAccent
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                    color: Colors.black26,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(_tr('inviteCode')),
                            Text(
                              '${_tr('room')}: $_activeRoom  |  ${_tr('password')}: ${_activeRoomPassword.isEmpty ? "-" : _activeRoomPassword}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(
                              text:
                                  'room=$_activeRoom, password=${_activeRoomPassword.isEmpty ? "-" : _activeRoomPassword}, key=$_activeRoomKey',
                            ),
                          );
                          _toast('Invite copied');
                        },
                        icon: const Icon(Icons.copy),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text('${_tr('users')} (${users.length})'),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemBuilder: (BuildContext context, int index) {
                      final CallUser user = users[index];
                      final bool isSelf = user.uid == _profileUid;
                      return _userChip(user, isSelf: isSelf);
                    },
                    separatorBuilder: (BuildContext context, int index) =>
                        const SizedBox(height: 8),
                    itemCount: users.length,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _toggleMute,
                        icon: Icon(_muted ? Icons.mic_off : Icons.mic),
                        label: Text(_muted ? _tr('unmute') : _tr('mute')),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _toggleMicGain,
                        icon: Icon(
                          _micLowered ? Icons.volume_up : Icons.volume_down,
                        ),
                        label: Text(
                          _micLowered ? _tr('normalMic') : _tr('lowerMic'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _toggleRecording,
                        icon: Icon(
                          _recording ? Icons.stop : Icons.fiber_manual_record,
                        ),
                        style: FilledButton.styleFrom(
                          foregroundColor: _recording ? Colors.redAccent : null,
                        ),
                        label: Text(
                          _recording ? _tr('stopRecord') : _tr('record'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () =>
                            _leaveCall(addHistory: true, type: 'outgoing'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                        ),
                        icon: const Icon(Icons.call_end),
                        label: Text(_tr('leave')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _ambientCircle({required Color color, required double size}) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_profileLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final bool dark = widget.themeMode == AppTheme.dark;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: dark
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[Color(0xFF0B2A3F), Color(0xFF061723)],
                )
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[Color(0xFFD4EEFF), Color(0xFFEFFBFF)],
                ),
        ),
        child: Stack(
          children: <Widget>[
            Positioned(
              top: -120,
              right: -80,
              child: _ambientCircle(
                color: dark ? const Color(0x3322C55E) : const Color(0x5538BDF8),
                size: 300,
              ),
            ),
            Positioned(
              bottom: -140,
              left: -100,
              child: _ambientCircle(
                color: dark ? const Color(0x4414B8A6) : const Color(0x554ADE80),
                size: 340,
              ),
            ),
            SafeArea(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                child: _mustConfigureBackend
                    ? _backendOnboardingView()
                    : (_inCall ? _callView() : _entryView()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
