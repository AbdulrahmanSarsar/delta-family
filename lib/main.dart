// Delta Flutter App - Optimized & Fixed with Courses Tab
// File: lib/main.dart

import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:photo_view/photo_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// --- الحزم الجديدة للكورسات ---
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

// دالة لالتقاط الإشعارات في الخلفية
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Background message received: ${message.messageId}");
}

// دالة منفصلة لتهيئة الإشعارات بدون تعطيل التطبيق
Future<void> _setupPushNotifications() async {
  try {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    await messaging.subscribeToTopic("all_users");
    debugPrint("Successfully subscribed to notifications");
  } catch (e) {
    debugPrint("Failed to subscribe: $e");
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // تشغيل الفايربيس الأساسي (سريع جداً ولا يعلق)
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // نستدعي الإشعارات ونتركها تعمل في الخلفية بدون أمر await الذي يعطل الإقلاع
    _setupPushNotifications();
  } catch (e) {
    debugPrint("Firebase init failed: $e");
  }

  // تشغيل واجهة التطبيق فوراً
  runApp(const MyApp());
}

// -------------------- Helpers --------------------

const _kTimeout = Duration(seconds: 15);

Widget _netImage(String url, {BoxFit fit = BoxFit.cover, Widget? placeholder}) {
  return CachedNetworkImage(
    imageUrl: url,
    fit: fit,
    placeholder: (_, __) => placeholder ?? Container(color: const Color(0xFFEEEEEE)),
    errorWidget: (_, __, ___) => Container(
      color: const Color(0xFFEEEEEE),
      child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
    ),
  );
}

Future<String?> downloadFileInApp(String url, {String? filename, Function(double)? onProgress}) async {
  try {
    final dio = Dio();
    String fname = filename ??
        (Uri.tryParse(url)?.pathSegments.isNotEmpty == true ? Uri.parse(url).pathSegments.last : 'attachment');
    final dir = await getApplicationDocumentsDirectory();
    final savePath = '${dir.path}/$fname';

    await dio.download(
      url,
      savePath,
      onReceiveProgress: (received, total) {
        if (total != -1 && onProgress != null) {
          onProgress(received / total);
        }
      },
      options: Options(followRedirects: true, responseType: ResponseType.bytes),
    );
    return savePath;
  } catch (e) {
    debugPrint('download error: $e');
    return null;
  }
}

String? _tryReadCustomField(Map<String, dynamic> json, String slug) {
  if (json['acf'] is Map && json['acf'][slug] != null) return json['acf'][slug]?.toString();
  if (json['meta'] is Map && json['meta'][slug] != null) return json['meta'][slug]?.toString();
  if (json['custom_fields'] is Map && json['custom_fields'][slug] != null) return json['custom_fields'][slug]?.toString();
  if (json[slug] != null) return json[slug]?.toString();
  if (json['acf'] is Map && json['acf'][slug] is Map && json['acf'][slug]['url'] != null) return json['acf'][slug]['url']?.toString();
  return null;
}

// -------------------- Configuration & Theme --------------------

class ApiConfig {
  static const String EVENTS_API = 'https://dfrc.ca/wp-json/events/v1/main-events';
  static const String FORMS_LIST_API = 'https://dfrc.ca/wp-json/fluentform/v1/mobile/forms';
  static const String FORM_SCHEMA_API = 'https://dfrc.ca/wp-json/fluentform/v1/mobile/forms/{id}/schema';
  static const String FORM_SUBMIT_API = 'https://dfrc.ca/wp-json/fluentform/v1/mobile/forms/submit';
  static const String JOBS_API = 'https://dfrc.ca/wp-json/custom/v1/jobs';
  static const String FLYERS_API = 'https://dfrc.ca/wp-json/custom/v1/flyers';
  // --- الـ API الجديد الخاص بالكورسات ---
  static const String LESSONS_API = 'https://dfrc.ca/wp-json/sewing/v1/lessons';

  static const String WEBSITE_URL = 'https://dfrc.ca/';
  static const String HEADER_IMAGE_URL = 'https://dfrc.ca/wp-content/uploads/2026/01/Delta-zoom-background-3.jpg-Sep-24.jpg';

  static Map<String, String> get AUTH_HEADERS => {'Accept': 'application/json'};
}

class AppTheme {
  static const Color deltaDarkBlue = Color(0xFF003B70);
  static const Color deltaLightBlue = Color(0xFF2D7FCE);
  static const Color deltaYellow = Color(0xFFFFC72C);
  static const Color bgGrey = Color(0xFFF8F9FA);

  static final ShapeBorder cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
    side: BorderSide(color: Colors.grey.shade200),
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: bgGrey,
      primaryColor: deltaDarkBlue,
      colorScheme: ColorScheme.fromSeed(
        seedColor: deltaDarkBlue,
        primary: deltaDarkBlue,
        secondary: deltaLightBlue,
        surface: Colors.white,
        background: bgGrey,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: deltaDarkBlue),
        titleTextStyle: TextStyle(color: deltaDarkBlue, fontWeight: FontWeight.bold, fontSize: 18),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: deltaLightBlue, width: 2)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: deltaDarkBlue,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        elevation: 10,
      ),
    );
  }
}

// -------------------- Main App --------------------

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Delta App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({Key? key}) : super(key: key);

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  late PageController _pageController;

  // --- إضافة الـ CoursesTab إلى قائمة الصفحات ---
  final List<Widget> _pages = const [
    HomeTab(),
    EventsTab(),
    ProgramsTab(),
    JobsTab(),
    FlyersTab(),
    CoursesTab(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        physics: const BouncingScrollPhysics(),
        children: _pages,
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.only(left: 10, right: 10, bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: _onTabTapped,
            backgroundColor: Colors.white,
            selectedItemColor: AppTheme.deltaDarkBlue,
            unselectedItemColor: Colors.grey.shade400,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 10),
            showUnselectedLabels: true,
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home_rounded), activeIcon: Icon(Icons.home), label: 'Home'),
              BottomNavigationBarItem(icon: Icon(Icons.calendar_month_outlined), activeIcon: Icon(Icons.calendar_month), label: 'Events'),
              BottomNavigationBarItem(icon: Icon(Icons.people_alt_outlined), activeIcon: Icon(Icons.people_alt), label: 'Programs'),
              BottomNavigationBarItem(icon: Icon(Icons.work_outline_rounded), activeIcon: Icon(Icons.work_rounded), label: 'Jobs'),
              BottomNavigationBarItem(icon: Icon(Icons.campaign_outlined), activeIcon: Icon(Icons.campaign_rounded), label: 'Flyers'),
              // --- الأيقونة الجديدة للكورسات ---
              BottomNavigationBarItem(icon: Icon(Icons.play_lesson_outlined), activeIcon: Icon(Icons.play_lesson), label: 'Courses'),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------- 1. Home Tab --------------------

class HomeTab extends StatefulWidget {
  const HomeTab({Key? key}) : super(key: key);
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  bool _loading = true;
  EventItem? _nextEvent;
  List<JobItem> _jobs = [];
  List<FlyerItem> _flyers = [];

  late final PageController _pageController;
  int _currentSlide = 0;
  Timer? _autoSlideTimer;
  bool _userInteracting = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.9);
    _loadAll();
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      await Future.wait([_loadEvents(), _loadJobs(), _loadFlyers()]);
    } catch (e) {
      debugPrint("Error loading home: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadEvents() async {
    try {
      final res = await http.get(Uri.parse(ApiConfig.EVENTS_API), headers: ApiConfig.AUTH_HEADERS).timeout(_kTimeout);
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        final events = data.map((e) => EventItem.fromJson(Map<String, dynamic>.from(e))).where((ev) => ev.start != null).toList();
        events.sort((a, b) => a.start!.compareTo(b.start!));
        final now = DateTime.now();
        EventItem? next;
        for (final ev in events) {
          if ((ev.end ?? ev.start!).isAfter(now)) {
            next = ev;
            break;
          }
        }
        if (mounted) setState(() => _nextEvent = next);
      }
    } catch (_) {}
  }

  Future<void> _loadJobs() async {
    try {
      final res = await http.get(Uri.parse(ApiConfig.JOBS_API), headers: ApiConfig.AUTH_HEADERS).timeout(_kTimeout);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        List raw = (data is List) ? data : (data['jobs'] ?? []);
        final parsed = raw.map((j) => JobItem.fromJson(Map<String, dynamic>.from(j)))
            .where((j) => j.deadline == null || j.deadline!.isAfter(DateTime.now())).toList();
        if (mounted) setState(() => _jobs = parsed);
      }
    } catch (_) {}
  }

  Future<void> _loadFlyers() async {
    try {
      final res = await http.get(Uri.parse(ApiConfig.FLYERS_API), headers: ApiConfig.AUTH_HEADERS).timeout(_kTimeout);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        List raw = (data is List) ? data : (data['flyers'] ?? []);
        final parsed = raw.map((f) => FlyerItem.fromJson(Map<String, dynamic>.from(f))).toList();
        if (mounted) {
          setState(() {
            _flyers = parsed;
            _currentSlide = 0;
          });
          if (_flyers.isNotEmpty) _startAutoSlide();
        }
      }
    } catch (_) {}
  }

  void _startAutoSlide() {
    _autoSlideTimer?.cancel();
    if (_flyers.isEmpty) return;
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 5), (t) {
      if (!mounted) return;
      if (_userInteracting) return;
      if (_pageController.hasClients) {
        int next = _currentSlide + 1;
        if (next >= _flyers.length) next = 0;
        _pageController.animateToPage(next, duration: const Duration(milliseconds: 600), curve: Curves.easeInOutCubic);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        title: Image.asset('assets/images/delta-family-logo.png', height: 35, fit: BoxFit.contain, errorBuilder: (_,__,___) => const Text("DELTA FAMILY")),
        actions: [
          IconButton(onPressed: () => launchUrl(Uri.parse(ApiConfig.WEBSITE_URL), mode: LaunchMode.externalApplication), icon: const Icon(Icons.language), tooltip: 'Website')
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.deltaLightBlue))
          : RefreshIndicator(
        onRefresh: _loadAll,
        color: AppTheme.deltaLightBlue,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _buildHeaderSection(),
            if (_flyers.isNotEmpty) _buildFlyersSlider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader("Upcoming Event", Icons.calendar_today),
                  _nextEvent != null ? _buildEventCard(_nextEvent!) : _buildEmptyState("No upcoming events."),
                  const SizedBox(height: 24),
                  _buildSectionHeader("Latest Opportunities", Icons.work_outline),
                  if (_jobs.isNotEmpty) ..._jobs.take(3).map((j) => _buildJobCard(j)) else _buildEmptyState("No job openings."),
                  const SizedBox(height: 90),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      width: double.infinity,
      height: 220,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, 5))],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
            child: _netImage(ApiConfig.HEADER_IMAGE_URL, placeholder: Container(color: AppTheme.deltaLightBlue)),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.6)]),
            ),
          ),
          const Positioned(
            bottom: 25, left: 20, right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Welcome to Delta", style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black45, blurRadius: 8)])),
                Text("Family Resource Centre", style: TextStyle(color: AppTheme.deltaYellow, fontSize: 16, fontWeight: FontWeight.w600, shadows: [Shadow(color: Colors.black45, blurRadius: 8)])),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFlyersSlider() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text("Latest Updates", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
            ],
          ),
        ),
        SizedBox(
          height: 220,
          child: GestureDetector(
            onPanDown: (_) => _userInteracting = true,
            onPanCancel: () => _userInteracting = false,
            onPanEnd: (_) => _userInteracting = false,
            child: PageView.builder(
              controller: _pageController,
              itemCount: _flyers.length,
              onPageChanged: (i) => setState(() => _currentSlide = i),
              itemBuilder: (context, idx) {
                final f = _flyers[idx];
                return GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FlyerDetailPage(flyer: f))),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 6))],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (f.imageUrl != null)
                            Hero(tag: 'flyer_${f.id ?? f.title}', child: _netImage(f.imageUrl!))
                          else
                            Container(color: AppTheme.deltaDarkBlue, child: const Icon(Icons.campaign, size: 50, color: Colors.white54)),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.8)], stops: const [0.6, 1.0]),
                            ),
                          ),
                          Positioned(
                            bottom: 16, left: 16, right: 16,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (f.endDate != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(color: AppTheme.deltaYellow, borderRadius: BorderRadius.circular(8)),
                                    child: Text("Ends: ${DateFormat('MMM d').format(f.endDate!)}", style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                Text(f.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16), maxLines: 2, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (_flyers.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_flyers.length, (i) => AnimatedContainer(duration: const Duration(milliseconds: 300), margin: const EdgeInsets.symmetric(horizontal: 4), width: _currentSlide == i ? 20 : 8, height: 6, decoration: BoxDecoration(color: _currentSlide == i ? AppTheme.deltaLightBlue : Colors.grey.shade300, borderRadius: BorderRadius.circular(4)))),
            ),
          ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 8),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: AppTheme.deltaLightBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: AppTheme.deltaLightBlue, size: 20)),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildEventCard(EventItem event) {
    return Card(
      color: Colors.white, elevation: 0.5, shape: AppTheme.cardShape,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailPage(event: event))),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(color: AppTheme.deltaDarkBlue, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(event.start != null ? DateFormat.MMM().format(event.start!).toUpperCase() : "", style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                    Text(event.start != null ? DateFormat.d().format(event.start!) : "", style: const TextStyle(color: AppTheme.deltaYellow, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(event.start != null ? DateFormat.yMMMd().add_jm().format(event.start!) : "", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    if(event.location != null) Text(event.location!, style: const TextStyle(color: AppTheme.deltaDarkBlue, fontSize: 11), maxLines: 1),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJobCard(JobItem job) {
    return Card(
      color: Colors.white, elevation: 0.5, shape: AppTheme.cardShape,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 45, height: 45,
          decoration: BoxDecoration(color: AppTheme.deltaLightBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.business_center, color: AppTheme.deltaLightBlue),
        ),
        title: Text(job.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: job.deadline != null
            ? Text("Deadline: ${DateFormat.yMMMd().format(job.deadline!)}", style: const TextStyle(color: Colors.redAccent, fontSize: 12))
            : const Text("Apply now", style: TextStyle(color: Colors.green, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () {
          if (job.fileUrl != null) launchUrl(Uri.parse(job.fileUrl!), mode: LaunchMode.externalApplication);
        },
      ),
    );
  }

  Widget _buildEmptyState(String text) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Column(children: [Icon(Icons.inbox_rounded, size: 40, color: Colors.grey.shade300), const SizedBox(height: 8), Text(text, style: TextStyle(color: Colors.grey.shade500))]),
    );
  }
}

// -------------------- 2. Events Tab --------------------

class EventsTab extends StatefulWidget {
  const EventsTab({Key? key}) : super(key: key);
  @override
  State<EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<EventsTab> {
  bool _loading = true;
  String? _error;
  List<EventItem> _events = [];

  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }

  Future<void> _fetchEvents() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await http.get(Uri.parse(ApiConfig.EVENTS_API), headers: ApiConfig.AUTH_HEADERS).timeout(_kTimeout);
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        final list = data.map((e) => EventItem.fromJson(Map<String, dynamic>.from(e))).toList();
        list.sort((a, b) => (a.start ?? DateTime.now()).compareTo(b.start ?? DateTime.now()));
        if (mounted) setState(() => _events = list);
      } else { throw 'Server error'; }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load events.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upcoming Events')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.wifi_off_rounded, size: 60, color: Colors.grey[400]),
        const SizedBox(height: 16),
        Text(_error!, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 16),
        ElevatedButton.icon(onPressed: _fetchEvents, icon: const Icon(Icons.refresh), label: const Text('Retry')),
      ]))
          : _events.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.event_busy, size: 80, color: Colors.grey[400]), const SizedBox(height: 16), const Text('No upcoming events', style: TextStyle(fontSize: 18, color: Colors.grey))]))
          : RefreshIndicator(
        onRefresh: _fetchEvents,
        child: ListView.separated(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 90),
          itemCount: _events.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, idx) => _buildEventCard(_events[idx]),
        ),
      ),
    );
  }

  Widget _buildEventCard(EventItem event) {
    return Card(
      color: Colors.white, elevation: 0.5, shape: AppTheme.cardShape,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailPage(event: event))),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 60, height: 65,
                decoration: BoxDecoration(color: AppTheme.deltaDarkBlue, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(event.start != null ? DateFormat.MMM().format(event.start!).toUpperCase() : "", style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                    Text(event.start != null ? DateFormat.d().format(event.start!) : "", style: const TextStyle(color: AppTheme.deltaYellow, fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.deltaDarkBlue), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    if (event.location != null && event.location!.isNotEmpty)
                      Row(children: [const Icon(Icons.location_on, size: 14, color: Colors.grey), const SizedBox(width: 4), Expanded(child: Text(event.location!, style: const TextStyle(color: Colors.grey, fontSize: 12), maxLines: 1))]),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class EventDetailPage extends StatelessWidget {
  final EventItem event;
  const EventDetailPage({Key? key, required this.event}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250.0,
            pinned: true,
            iconTheme: const IconThemeData(color: Colors.white),
            backgroundColor: AppTheme.deltaDarkBlue,
            flexibleSpace: FlexibleSpaceBar(
              background: event.imageUrl != null
                  ? _netImage(event.imageUrl!)
                  : Container(color: AppTheme.deltaDarkBlue, child: const Center(child: Icon(Icons.event, size: 60, color: Colors.white24))),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.deltaDarkBlue)),
                    const SizedBox(height: 16),
                    _buildInfoRow(Icons.calendar_today, _formatDate(event.start, event.end)),
                    if (event.location != null && event.location!.isNotEmpty)
                      _buildInfoRow(Icons.location_on, event.location!),

                    if (event.capacityStats != null && event.capacityStats!['has_limit'] == true) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: event.capacityStats!['is_full'] == true ? Colors.red.shade50 : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: event.capacityStats!['is_full'] == true ? Colors.red.shade200 : Colors.green.shade200),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(
                                    event.capacityStats!['is_full'] == true ? Icons.block : Icons.local_activity,
                                    color: event.capacityStats!['is_full'] == true ? Colors.red : Colors.green
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    event.capacityStats!['is_full'] == true
                                        ? "Sold Out (Fully Booked)"
                                        : "Tickets Available: ${event.capacityStats!['available']}",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: event.capacityStats!['is_full'] == true ? Colors.red[800] : Colors.green[800]
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (event.capacityStats!['is_full'] == false && event.url != null) ...[
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: () {
                                    launchUrl(
                                        Uri.parse(event.url!),
                                        mode: LaunchMode.inAppBrowserView
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.deltaDarkBlue,
                                    foregroundColor: AppTheme.deltaYellow,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: const Text(
                                      "Buy Ticket / Book Now",
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                                  ),
                                ),
                              ),
                            ]
                          ],
                        ),
                      ),
                    ],

                    if (event.videoUrl != null && event.videoUrl!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () => launchUrl(Uri.parse(event.videoUrl!), mode: LaunchMode.externalApplication),
                          icon: const Icon(Icons.play_circle_fill, size: 24),
                          label: const Text("Watch Event Video", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                          ),
                        ),
                      ),
                    ],

                    const Divider(height: 30, thickness: 1),

                    if (event.overview != null && event.overview!.isNotEmpty) ...[
                      Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.blue.withOpacity(0.05), border: const Border(left: BorderSide(color: AppTheme.deltaLightBlue, width: 4))),
                          child: Text(event.overview!, style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic))
                      ),
                      const SizedBox(height: 20),
                    ],

                    if (event.description != null)
                      Html(data: event.description!),

                    if (event.gallery.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Text("Gallery", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.deltaDarkBlue)),
                      const SizedBox(height: 15),
                      SizedBox(
                        height: 120,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: event.gallery.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            return GestureDetector(
                              onTap: () => _openGalleryImage(context, event.gallery[index]),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SizedBox(width: 160, height: 120, child: _netImage(event.gallery[index])),
                              ),
                            );
                          },
                        ),
                      ),
                    ],

                    if (event.subEvents.isNotEmpty) ...[
                      const SizedBox(height: 30),
                      const Text("Schedule / Sessions", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.deltaDarkBlue)),
                      const SizedBox(height: 15),
                      ...event.subEvents.map((sub) => _buildSubEventCard(context, sub)),
                    ],

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Expanded(child: Text(text, style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.3)))
            ]
        )
    );
  }

  String _formatDate(DateTime? start, DateTime? end) {
    if (start == null) return "Date TBA";
    final f = DateFormat('EEE, MMM d, yyyy');
    if (end != null && start.day != end.day) return "${f.format(start)} - ${DateFormat('MMM d').format(end)}";
    return f.format(start);
  }

  Widget _buildSubEventCard(BuildContext context, SubEventItem sub) {
    String timeInfo = "";
    if (sub.start != null) {
      timeInfo = DateFormat('MMM d, h:mm a').format(sub.start!);
      if (sub.end != null) timeInfo += " - ${DateFormat((sub.start!.day == sub.end!.day) ? 'h:mm a' : 'MMM d, h:mm a').format(sub.end!)}";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
      child: ListTile(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SubEventDetailPage(subEvent: sub))),
        leading: Container(
          width: 50, height: 50, decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(10)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(sub.start != null ? DateFormat.d().format(sub.start!) : "--", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.deltaDarkBlue)), Text(sub.start != null ? DateFormat.MMM().format(sub.start!) : "", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))]),
        ),
        title: Text(sub.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(timeInfo, style: TextStyle(color: Colors.grey[800], fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      ),
    );
  }

  void _openGalleryImage(BuildContext context, String imageUrl) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
        body: Center(child: PhotoView(imageProvider: NetworkImage(imageUrl)))
    )));
  }
}


class SubEventDetailPage extends StatelessWidget {
  final SubEventItem subEvent;
  const SubEventDetailPage({Key? key, required this.subEvent}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Session Details"), backgroundColor: AppTheme.deltaDarkBlue, iconTheme: const IconThemeData(color: Colors.white), titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(subEvent.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.deltaDarkBlue)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
            child: Column(children: [
              if (subEvent.start != null) _row(Icons.play_circle_outline, "Start:", DateFormat('EEE, MMM d, yyyy • h:mm a').format(subEvent.start!)),
              if (subEvent.end != null) ...[const Divider(), _row(Icons.stop_circle_outlined, "End:", DateFormat('EEE, MMM d, yyyy • h:mm a').format(subEvent.end!))]
            ]),
          ),
          const SizedBox(height: 25), const Divider(), const SizedBox(height: 15),
          const Text("About this session:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 10),
          Text(subEvent.content ?? "No details available.", style: const TextStyle(fontSize: 16, height: 1.6, color: Colors.black87)),
        ]),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 22, color: AppTheme.deltaDarkBlue), const SizedBox(width: 12), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)), const SizedBox(height: 2), Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))])]);
}

// -------------------- 3. Programs Tab --------------------

IconData _formIconData(String? name) {
  switch (name) {
    case 'people':        return Icons.people_alt_rounded;
    case 'work':          return Icons.work_rounded;
    case 'school':        return Icons.school_rounded;
    case 'favorite':      return Icons.favorite_rounded;
    case 'event':         return Icons.event_rounded;
    case 'help':          return Icons.handshake_rounded;
    case 'health_safety': return Icons.health_and_safety_rounded;
    case 'home':          return Icons.home_rounded;
    case 'child_care':    return Icons.child_care_rounded;
    case 'language':      return Icons.language_rounded;
    case 'groups':        return Icons.groups_rounded;
    case 'food':          return Icons.restaurant_rounded;
    case 'info':          return Icons.info_outline_rounded;
    default:              return Icons.assignment_rounded;
  }
}

class ProgramsTab extends StatefulWidget {
  const ProgramsTab({Key? key}) : super(key: key);
  @override
  State<ProgramsTab> createState() => _ProgramsTabState();
}

class _ProgramsTabState extends State<ProgramsTab> {
  bool _loading = true;
  String? _error;
  List<FormListItem> _forms = [];

  @override
  void initState() {
    super.initState();
    _fetchFormsList();
  }

  Future<void> _fetchFormsList() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await http.get(Uri.parse(ApiConfig.FORMS_LIST_API), headers: ApiConfig.AUTH_HEADERS).timeout(_kTimeout);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        List raw = (data is List) ? data : (data['forms'] ?? []);
        if (mounted) setState(() => _forms = raw.map((e) => FormListItem.fromJson(Map<String, dynamic>.from(e))).toList());
      } else { throw 'Server error'; }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load programs.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Programs')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.deltaLightBlue))
          : _error != null
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.wifi_off_rounded, size: 60, color: Colors.grey[400]),
        const SizedBox(height: 16),
        Text(_error!, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 16),
        ElevatedButton.icon(onPressed: _fetchFormsList, icon: const Icon(Icons.refresh), label: const Text('Retry')),
      ]))
          : _forms.isEmpty
          ? const Center(child: Text('No programs available', style: TextStyle(color: Colors.grey, fontSize: 16)))
          : RefreshIndicator(
        onRefresh: _fetchFormsList,
        color: AppTheme.deltaLightBlue,
        child: ListView.separated(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 90),
          itemCount: _forms.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, idx) => _buildFormCard(_forms[idx]),
        ),
      ),
    );
  }

  Widget _buildFormCard(FormListItem form) {
    final icon = _formIconData(form.icon);
    final hasDesc = form.description != null && form.description!.isNotEmpty;
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: AppTheme.cardShape,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DynamicFormPage(formId: form.id, title: form.title))),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: AppTheme.deltaDarkBlue,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(form.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                    if (hasDesc) ...[
                      const SizedBox(height: 4),
                      Text(form.description!, style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(color: AppTheme.deltaDarkBlue.withOpacity(0.07), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.deltaDarkBlue),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------- 4. Jobs Tab --------------------

class JobsTab extends StatefulWidget {
  const JobsTab({Key? key}) : super(key: key);
  @override
  State<JobsTab> createState() => _JobsTabState();
}

class _JobsTabState extends State<JobsTab> {
  bool _loading = true;
  String? _error;
  List<JobItem> _jobs = [];

  @override
  void initState() {
    super.initState();
    _fetchJobs();
  }

  Future<void> _fetchJobs() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await http.get(Uri.parse(ApiConfig.JOBS_API), headers: ApiConfig.AUTH_HEADERS).timeout(_kTimeout);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        List raw = (data is List) ? data : (data['jobs'] ?? []);
        setState(() => _jobs = raw.map((e) => JobItem.fromJson(Map<String, dynamic>.from(e))).toList());
      } else { throw 'Server error'; }
    } catch (ex) {
      setState(() => _error = 'Could not load jobs.');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Job Opportunities')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null ? Center(child: TextButton(onPressed: _fetchJobs, child: const Text('Retry')))
          : RefreshIndicator(
        onRefresh: _fetchJobs,
        child: _jobs.isEmpty
            ? ListView(children: [SizedBox(height: MediaQuery.of(context).size.height * 0.2), Lottie.asset('assets/lottie/noResultFound.json', width: 250, height: 250, repeat: false), const Center(child: Text('No jobs available'))])
            : ListView.builder(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 90),
          itemCount: _jobs.length,
          itemBuilder: (context, index) {
            final job = _jobs[index];
            return Card(
              color: Colors.white, elevation: 0.5, shape: AppTheme.cardShape,
              child: InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => JobDetailPage(job: job))),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 60, height: 60,
                        decoration: BoxDecoration(color: AppTheme.deltaLightBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                        child: job.imageUrl != null
                            ? ClipRRect(borderRadius: BorderRadius.circular(12), child: _netImage(job.imageUrl!))
                            : const Icon(Icons.work_outline, color: AppTheme.deltaDarkBlue),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(job.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 4),
                            Text(job.deadline != null ? 'Deadline: ${DateFormat.yMMMd().format(job.deadline!)}' : 'Apply now', style: TextStyle(color: job.deadline != null ? Colors.redAccent : Colors.green, fontSize: 12)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class JobDetailPage extends StatelessWidget {
  final JobItem job;
  const JobDetailPage({Key? key, required this.job}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Details')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity, height: 200, color: AppTheme.deltaDarkBlue.withOpacity(0.05),
              child: job.imageUrl != null ? _netImage(job.imageUrl!) : const Icon(Icons.business_center, size: 80, color: AppTheme.deltaDarkBlue),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 90),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(job.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  if (job.deadline != null) Chip(label: Text('Apply by: ${DateFormat.yMMMd().format(job.deadline!)}'), backgroundColor: Colors.red.shade50, labelStyle: const TextStyle(color: Colors.red), side: BorderSide.none),
                  const SizedBox(height: 20), const Divider(), const SizedBox(height: 20),
                  const Text("Description", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 10),
                  if (job.content != null && job.content!.isNotEmpty)
                    Html(data: job.content!)
                  else
                    const Text("Please download the full details document below.", style: TextStyle(height: 1.5, color: Colors.black87)),
                  const SizedBox(height: 40),
                  if (job.fileUrl != null)
                    SizedBox(width: double.infinity, height: 55, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: AppTheme.deltaDarkBlue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: () => launchUrl(Uri.parse(job.fileUrl!), mode: LaunchMode.externalApplication), icon: const Icon(Icons.file_download), label: const Text('Download Full Job PDF', style: TextStyle(fontWeight: FontWeight.bold)))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------- 5. Flyers Tab --------------------

class FlyersTab extends StatefulWidget {
  const FlyersTab({Key? key}) : super(key: key);
  @override
  State<FlyersTab> createState() => _FlyersTabState();
}

class _FlyersTabState extends State<FlyersTab> {
  bool _loading = true;
  String? _error;
  List<FlyerItem> _items = [];

  @override
  void initState() {
    super.initState();
    _fetchFlyers();
  }

  Future<void> _fetchFlyers() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await http.get(Uri.parse(ApiConfig.FLYERS_API), headers: ApiConfig.AUTH_HEADERS).timeout(_kTimeout);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        List raw = (data is List) ? data : (data['flyers'] ?? []);
        setState(() => _items = raw.map((e) => FlyerItem.fromJson(Map<String, dynamic>.from(e))).toList());
      } else { throw 'Server error'; }
    } catch (ex) {
      setState(() => _error = 'Failed to load flyers.');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flyers & Updates')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.wifi_off_rounded, size: 60, color: Colors.grey[400]),
        const SizedBox(height: 16),
        Text(_error!, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 16),
        ElevatedButton.icon(onPressed: _fetchFlyers, icon: const Icon(Icons.refresh), label: const Text('Retry')),
      ]))
          : RefreshIndicator(
        onRefresh: _fetchFlyers,
        child: _items.isEmpty
            ? ListView(children: [SizedBox(height: MediaQuery.of(context).size.height * 0.2), Lottie.asset('assets/lottie/noResultFound.json', width: 250, height: 250, repeat: false), const Center(child: Text('No flyers available'))])
            : ListView.builder(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 90),
          itemCount: _items.length,
          itemBuilder: (context, index) {
            final flyer = _items[index];
            return Card(
              color: Colors.white, elevation: 0.5, shape: AppTheme.cardShape,
              child: InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FlyerDetailPage(flyer: flyer))),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 60, height: 60,
                        decoration: BoxDecoration(color: AppTheme.deltaLightBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                        child: flyer.imageUrl != null
                            ? Hero(tag: 'flyer_${flyer.id ?? flyer.title}', child: ClipRRect(borderRadius: BorderRadius.circular(12), child: _netImage(flyer.imageUrl!)))
                            : const Icon(Icons.campaign_rounded, color: AppTheme.deltaDarkBlue, size: 30),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(flyer.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text(flyer.endDate != null ? 'Ends: ${DateFormat.yMMMd().format(flyer.endDate!)}' : 'View details', style: TextStyle(color: flyer.endDate != null ? Colors.redAccent : Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class FlyerDetailPage extends StatelessWidget {
  final FlyerItem flyer;
  const FlyerDetailPage({Key? key, required this.flyer}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isExpired = flyer.endDate != null && flyer.endDate!.isBefore(DateTime.now());
    final int? daysLeft = flyer.endDate?.difference(DateTime.now()).inDays;
    final String heroTag = 'flyer_${flyer.id ?? flyer.title}';

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 400.0, pinned: true,
            backgroundColor: AppTheme.deltaDarkBlue,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (flyer.imageUrl != null)
                    Hero(tag: heroTag, child: _netImage(flyer.imageUrl!))
                  else
                    Container(color: AppTheme.deltaDarkBlue, child: const Center(child: Icon(Icons.campaign, size: 80, color: Colors.white24))),
                  Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(0.3), Colors.transparent, Colors.black.withOpacity(0.1)], stops: const [0.0, 0.3, 1.0]))),
                  Positioned(bottom: 16, right: 16, child: FloatingActionButton.small(heroTag: 'zoom_btn', backgroundColor: Colors.white.withOpacity(0.9), foregroundColor: AppTheme.deltaDarkBlue, elevation: 4, onPressed: () => _openFullScreen(context), child: const Icon(Icons.zoom_in))),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 90),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (flyer.endDate != null) ...[
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: isExpired ? Colors.red.withOpacity(0.1) : (daysLeft != null && daysLeft < 5 ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1)), borderRadius: BorderRadius.circular(20), border: Border.all(color: isExpired ? Colors.red : (daysLeft != null && daysLeft < 5 ? Colors.orange : Colors.green))),
                          child: Row(children: [Icon(isExpired ? Icons.event_busy : Icons.access_time, size: 16, color: isExpired ? Colors.red : (daysLeft != null && daysLeft < 5 ? Colors.orange : Colors.green)), const SizedBox(width: 6), Text(isExpired ? "Expired" : (daysLeft == 0 ? "Ends Today!" : "$daysLeft Days Left"), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isExpired ? Colors.red : (daysLeft != null && daysLeft < 5 ? Colors.orange[800] : Colors.green[800])))]),
                        ),
                        const Spacer(),
                        Text("Until: ${DateFormat.yMMMd().format(flyer.endDate!)}", style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      ]),
                      const SizedBox(height: 16),
                    ],
                    Text(flyer.title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black87, height: 1.3)),
                    const SizedBox(height: 12), const Divider(height: 30),
                    const Text("Review details above. Pinch to zoom image or download document.", style: TextStyle(fontSize: 15, color: Colors.black54, height: 1.5)),
                    const SizedBox(height: 30),
                    if (flyer.fileUrl != null)
                      SizedBox(width: double.infinity, height: 56, child: ElevatedButton.icon(onPressed: () => _download(context), style: ElevatedButton.styleFrom(backgroundColor: AppTheme.deltaDarkBlue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), icon: const Icon(Icons.file_download_outlined, size: 26), label: const Text("Download Attached PDF", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))))
                    else
                      Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)), child: const Text("No additional documents attached.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))),
                    const SizedBox(height: 16),
                    if (flyer.imageUrl != null)
                      SizedBox(width: double.infinity, height: 56, child: OutlinedButton.icon(onPressed: () => _openFullScreen(context), style: OutlinedButton.styleFrom(foregroundColor: AppTheme.deltaDarkBlue, side: const BorderSide(color: AppTheme.deltaDarkBlue), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), icon: const Icon(Icons.fullscreen), label: const Text("View Full Screen Image"))),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  void _openFullScreen(BuildContext context) {
    if (flyer.imageUrl == null) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(backgroundColor: Colors.black, appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)), body: Center(child: PhotoView(imageProvider: NetworkImage(flyer.imageUrl!), heroAttributes: PhotoViewHeroAttributes(tag: 'flyer_${flyer.id ?? flyer.title}'))))));
  }

  Future<void> _download(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Downloading...'), duration: Duration(seconds: 1)));
    final path = await downloadFileInApp(flyer.fileUrl!, filename: Uri.parse(flyer.fileUrl!).pathSegments.last);
    if (path != null) OpenFile.open(path);
  }
}

// -------------------- 6. Courses Tab & Player --------------------

class CoursesTab extends StatefulWidget {
  const CoursesTab({Key? key}) : super(key: key);
  @override
  State<CoursesTab> createState() => _CoursesTabState();
}

class _CoursesTabState extends State<CoursesTab> {
  bool _loading = true;
  bool _hasAccess = false;
  String? _error;
  List<LessonItem> _lessons = [];

  @override
  void initState() {
    super.initState();
    _checkAccessAndLoad();
  }

  Future<void> _checkAccessAndLoad() async {
    setState(() { _loading = true; _error = null; });
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      _hasAccess = prefs.getBool('sewing_course_access') ?? false;

      // Only fetch lessons when user has registered — saves bandwidth for
      // visitors who still see the lock screen regardless of network state.
      if (_hasAccess) {
        final res = await http.get(Uri.parse(ApiConfig.LESSONS_API)).timeout(const Duration(seconds: 15));
        if (res.statusCode == 200) {
          final List data = jsonDecode(res.body);
          _lessons = data.map((e) => LessonItem.fromJson(e)).toList();
        } else {
          throw 'Server Error ${res.statusCode}';
        }
      }
    } catch (e) {
      // Only show the error overlay when the user already has access and the
      // lesson fetch fails. Unregistered users should just see the lock screen.
      if (_hasAccess) _error = "Could not load course content. Please try again.";
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openRegistrationForm() {
    Navigator.push(context, MaterialPageRoute(
        builder: (_) => const DynamicFormPage(
          formId: 38,
          title: "Register for Free Course",
          successButtonLabel: "Start Learning Now! 🎉",
        )
    )).then((_) {
      _checkAccessAndLoad(); // تحديث الصفحة بعد العودة من الفورم
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Free Sewing Course')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.deltaLightBlue))
          : _error != null
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.wifi_off_rounded, size: 60, color: Colors.grey[400]),
        const SizedBox(height: 16),
        Text(_error!, style: const TextStyle(color: Colors.grey)),
        TextButton(onPressed: _checkAccessAndLoad, child: const Text("Retry"))
      ]))
          : !_hasAccess
          ? _buildLockScreen()
          : _buildCourseDashboard(),
    );
  }

  Widget _buildLockScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
              child: const Icon(Icons.lock_outline_rounded, size: 80, color: AppTheme.deltaLightBlue),
            ),
            const SizedBox(height: 24),
            const Text("Unlock This Free Course", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.deltaDarkBlue)),
            const SizedBox(height: 12),
            const Text(
              "Join our community today! Please register to get instant access to the complete video lessons and curriculum.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black54, height: 1.5),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _openRegistrationForm,
                icon: const Icon(Icons.how_to_reg),
                label: const Text("Register Now for Free", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.deltaDarkBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 5,
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCourseDashboard() {
    return ListView.separated(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 90),
      itemCount: _lessons.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final lesson = _lessons[index];
        return Card(
          elevation: 0,
          shape: AppTheme.cardShape,
          color: Colors.white,
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: Container(
              width: 50, height: 50,
              decoration: BoxDecoration(color: AppTheme.deltaLightBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Center(child: Text("${lesson.index}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.deltaDarkBlue))),
            ),
            title: Text(lesson.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Text("⏱ ${lesson.duration}", style: TextStyle(color: Colors.grey.shade600)),
            trailing: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppTheme.deltaDarkBlue, borderRadius: BorderRadius.circular(50)),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
            ),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => LessonPlayerPage(lessons: _lessons, initialIndex: index)
              ));
            },
          ),
        );
      },
    );
  }
}

class LessonPlayerPage extends StatefulWidget {
  final List<LessonItem> lessons;
  final int initialIndex;

  const LessonPlayerPage({Key? key, required this.lessons, required this.initialIndex}) : super(key: key);

  @override
  State<LessonPlayerPage> createState() => _LessonPlayerPageState();
}

class _LessonPlayerPageState extends State<LessonPlayerPage> {
  late int _currentIndex;
  YoutubePlayerController? _youtubeController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _initPlayer();
  }

  void _initPlayer() {
    final videoId = widget.lessons[_currentIndex].youtubeId;
    if (videoId != null) {
      _youtubeController = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(autoPlay: true, mute: false),
      );
    }
  }

  void _changeLesson(int index) {
    setState(() {
      _currentIndex = index;
      final newVideoId = widget.lessons[_currentIndex].youtubeId;
      if (newVideoId != null && _youtubeController != null) {
        _youtubeController!.load(newVideoId);
      }
    });
  }

  @override
  void dispose() {
    _youtubeController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentLesson = widget.lessons[_currentIndex];

    return Scaffold(
      backgroundColor: AppTheme.bgGrey,
      appBar: AppBar(
        title: Text("Lesson ${currentLesson.index}"),
        backgroundColor: AppTheme.deltaDarkBlue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          if (_youtubeController != null)
            YoutubePlayer(
              controller: _youtubeController!,
              showVideoProgressIndicator: true,
              progressColors: const ProgressBarColors(
                playedColor: AppTheme.deltaYellow,
                handleColor: AppTheme.deltaYellow,
              ),
            )
          else
            Container(
              height: 220, width: double.infinity, color: Colors.black,
              child: const Center(child: Text("Video not available", style: TextStyle(color: Colors.white))),
            ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(currentLesson.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.deltaDarkBlue)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(currentLesson.duration, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 24),

                  if (currentLesson.outcomes.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: const Border(left: BorderSide(color: AppTheme.deltaLightBlue, width: 4)),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("In this lesson you will learn:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.deltaDarkBlue)),
                          const SizedBox(height: 12),
                          ...currentLesson.outcomes.map((o) => Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("• ", style: TextStyle(fontSize: 18, color: AppTheme.deltaLightBlue, fontWeight: FontWeight.bold)),
                                Expanded(child: Text(o, style: const TextStyle(fontSize: 15, height: 1.4))),
                              ],
                            ),
                          )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],

                  const Text("Course Playlist", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ...widget.lessons.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final lesson = entry.value;
                    final isActive = idx == _currentIndex;

                    return Card(
                      color: isActive ? AppTheme.deltaLightBlue.withOpacity(0.1) : Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: isActive ? AppTheme.deltaLightBlue : Colors.grey.shade200),
                      ),
                      child: ListTile(
                        leading: Icon(isActive ? Icons.play_circle_filled : Icons.play_circle_outline, color: isActive ? AppTheme.deltaDarkBlue : Colors.grey),
                        title: Text("${lesson.index}. ${lesson.title}", style: TextStyle(fontWeight: isActive ? FontWeight.bold : FontWeight.normal, color: isActive ? AppTheme.deltaDarkBlue : Colors.black87)),
                        trailing: Text(lesson.duration, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        onTap: () => _changeLesson(idx),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------- Dynamic Form Page (Stepper) --------------------

class DynamicFormPage extends StatefulWidget {
  final int formId;
  final String title;
  /// Label of the button shown on the success screen.
  /// Defaults to "Back to Programs". Override when opening from CoursesTab
  /// so the button reads "Start Learning Now! 🎉" instead.
  final String successButtonLabel;
  const DynamicFormPage({
    Key? key,
    required this.formId,
    required this.title,
    this.successButtonLabel = 'Back to Programs',
  }) : super(key: key);
  @override
  State<DynamicFormPage> createState() => _DynamicFormPageState();
}

class _DynamicFormPageState extends State<DynamicFormPage> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  bool _submitted = false;
  String _successMessage = 'Your form was submitted successfully!';
  FormSchema? _schema;
  final Map<String, dynamic> _formData = {};
  final Map<String, TextEditingController> _dateControllers = {};

  List<List<FormFieldSchema>> _steps = [];
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _fetchSchema();
  }

  @override
  void dispose() {
    for (final c in _dateControllers.values) c.dispose();
    super.dispose();
  }

  List<List<FormFieldSchema>> _buildSteps(List<FormFieldSchema> fields) {
    final steps = <List<FormFieldSchema>>[];
    var current = <FormFieldSchema>[];
    for (final f in fields) {
      if (f.type == 'section_break' || f.type == 'section') {
        if (current.isNotEmpty) steps.add(current);
        current = [f];
      } else {
        current.add(f);
      }
    }
    if (current.isNotEmpty) steps.add(current);
    return steps.isEmpty ? [fields] : steps;
  }

  bool get _isMultiStep => _steps.length > 1;

  Future<void> _fetchSchema() async {
    try {
      final res = await http.get(
        Uri.parse(ApiConfig.FORM_SCHEMA_API.replaceAll('{id}', widget.formId.toString())),
        headers: ApiConfig.AUTH_HEADERS,
      ).timeout(_kTimeout);
      if (res.statusCode == 200) {
        final schema = FormSchema.fromMobileJson(jsonDecode(res.body));
        if (mounted) setState(() {
          _schema = schema;
          _steps = _buildSteps(schema.fields);
          _loading = false;
        });
      } else { throw 'error'; }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _shouldShowField(FormFieldSchema field) {
    if (field.conditionalLogic == null) return true;
    try {
      final conditions = field.conditionalLogic!['conditions'] as List? ?? [];
      if (conditions.isEmpty) return true;
      final type = field.conditionalLogic!['type'] ?? 'all';
      bool result = type == 'all';
      for (final c in conditions) {
        final actual   = _getValue(c['field']?.toString() ?? '')?.toString() ?? '';
        final expected = c['value']?.toString() ?? '';
        final match = actual == expected;
        if (type == 'all') result = result && match;
        else result = result || match;
      }
      return result;
    } catch (_) { return true; }
  }

  dynamic _getValue(String key) {
    key = key.replaceAll('[]', '');
    if (key.contains('[') && key.endsWith(']')) {
      final parent = key.substring(0, key.indexOf('['));
      final child  = key.substring(key.indexOf('[') + 1, key.length - 1);
      if (_formData[parent] is Map) return _formData[parent][child];
      return null;
    }
    return _formData[key];
  }

  void _updateValue(String key, dynamic value) {
    if (key.isEmpty) return;
    key = key.replaceAll('[]', '');
    setState(() {
      if (key.contains('[') && key.endsWith(']')) {
        final parent = key.substring(0, key.indexOf('['));
        final child  = key.substring(key.indexOf('[') + 1, key.length - 1);
        if (_formData[parent] is! Map) _formData[parent] = <String, dynamic>{};
        _formData[parent][child] = value;
      } else {
        _formData[key] = value;
      }
    });
  }

  void _goNext() {
    if (_formKey.currentState?.validate() != true) return;
    setState(() => _currentStep++);
  }

  void _goPrev() => setState(() => _currentStep--);

  Future<void> _submitForm() async {
    if (_formKey.currentState?.validate() != true) return;
    _formKey.currentState!.save();
    setState(() => _loading = true);
    try {
      final headers = Map<String, String>.from(ApiConfig.AUTH_HEADERS);
      headers['Content-Type'] = 'application/json';
      final res = await http.post(
        Uri.parse(ApiConfig.FORM_SUBMIT_API),
        headers: headers,
        body: jsonEncode({'form_id': widget.formId, 'data': _formData}),
      ).timeout(_kTimeout);
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        if (d['status'] == false) throw d['message'] ?? 'Submission failed';

        // --- إضافة الصلاحية لقسم الكورسات إذا كان الفورم رقم 38 ---
        if (widget.formId == 38) {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setBool('sewing_course_access', true);
        }

        if (mounted) setState(() {
          _submitted = true;
          _successMessage = d['message'] ?? 'Your form was submitted successfully!';
        });
      } else { throw 'Server error. Please try again.'; }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red.shade700),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _schema == null) {
      return Scaffold(appBar: AppBar(title: Text(widget.title)), body: const Center(child: CircularProgressIndicator(color: AppTheme.deltaLightBlue)));
    }
    if (_schema == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.error_outline, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text('Could not load this form.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          ElevatedButton.icon(onPressed: _fetchSchema, icon: const Icon(Icons.refresh), label: const Text('Retry')),
        ])),
      );
    }
    if (_submitted) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Lottie.asset('assets/lottie/announcement.json', width: 200, height: 200, repeat: false),
              const SizedBox(height: 24),
              const Text('Submitted!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.deltaDarkBlue)),
              const SizedBox(height: 12),
              Text(_successMessage, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: Colors.black54, height: 1.5)),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.deltaDarkBlue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: Text(widget.successButtonLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          ),
        ),
      );
    }

    final currentFields = _steps[_currentStep];
    final isLastStep    = _currentStep == _steps.length - 1;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          if (_isMultiStep) _buildStepIndicator(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: currentFields.map((f) => _buildField(f)).toList(),
                ),
              ),
            ),
          ),
          _buildNavBar(isLastStep),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Column(children: [
        Row(
          children: List.generate(_steps.length * 2 - 1, (i) {
            if (i.isOdd) {
              return Expanded(child: Container(height: 2, color: i ~/ 2 < _currentStep ? AppTheme.deltaDarkBlue : Colors.grey.shade200));
            }
            final idx = i ~/ 2;
            final done = idx < _currentStep;
            final cur  = idx == _currentStep;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 32, height: 32,
              decoration: BoxDecoration(shape: BoxShape.circle, color: done || cur ? AppTheme.deltaDarkBlue : Colors.grey.shade200),
              child: Center(child: done
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : Text('${idx + 1}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: cur ? Colors.white : Colors.grey))),
            );
          }),
        ),
        const SizedBox(height: 6),
        Text('Step ${_currentStep + 1} of ${_steps.length}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ]),
    );
  }

  Widget _buildNavBar(bool isLastStep) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, -4))]),
      child: Row(children: [
        if (_currentStep > 0) ...[
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _goPrev,
              icon: const Icon(Icons.arrow_back_ios_rounded, size: 14),
              label: const Text('Back'),
              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.deltaDarkBlue, side: const BorderSide(color: AppTheme.deltaDarkBlue), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _loading ? null : (isLastStep ? _submitForm : _goNext),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.deltaDarkBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: _loading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(isLastStep ? 'Submit' : 'Next', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              if (!isLastStep) ...[const SizedBox(width: 6), const Icon(Icons.arrow_forward_ios_rounded, size: 14)],
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildField(FormFieldSchema field) {
    if (!_shouldShowField(field)) return const SizedBox.shrink();

    if (field.type == 'section_break' || field.type == 'section') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (field.label.isNotEmpty) Text(field.label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.deltaDarkBlue)),
          if (field.placeholder != null && field.placeholder!.isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 6), child: Text(field.placeholder!, style: const TextStyle(fontSize: 14, color: Colors.grey))),
          const SizedBox(height: 10), const Divider(thickness: 1.5),
        ]),
      );
    }

    if (field.type == 'container') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: field.subFields.map((col) => Expanded(
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: col.subFields.map((f) => _buildField(f)).toList())),
          )).toList(),
        ),
      );
    }

    if (field.subFields.isNotEmpty && field.type != 'column') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (field.label.isNotEmpty)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: RichText(text: TextSpan(text: field.label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87), children: [if (field.required) const TextSpan(text: ' *', style: TextStyle(color: Colors.red))]))),
          ...field.subFields.map((f) => _buildField(f)),
        ]),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (field.label.isNotEmpty)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: RichText(text: TextSpan(text: field.label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87), children: [if (field.required) const TextSpan(text: ' *', style: TextStyle(color: Colors.red))]))),
        _buildInput(field),
      ]),
    );
  }

  Widget _buildInput(FormFieldSchema field) {
    final val   = _getValue(field.key);
    final decor = InputDecoration(hintText: field.placeholder ?? 'Select an option');

    if (field.type == 'select' || field.type == 'select_country') {
      return DropdownButtonFormField<String>(
        decoration: decor, value: val?.toString(), isExpanded: true,
        items: field.options.map((o) => DropdownMenuItem(value: o['value'], child: Text(o['label']!))).toList(),
        onChanged: (v) => _updateValue(field.key, v),
        validator: (v) => field.required && (v == null || v.isEmpty) ? 'This field is required' : null,
      );
    }

    if (field.type == 'input_radio') {
      return Column(children: field.options.map((o) => RadioListTile<String>(
        title: Text(o['label']!), value: o['value']!, groupValue: val?.toString(),
        contentPadding: EdgeInsets.zero, dense: true, activeColor: AppTheme.deltaDarkBlue,
        onChanged: (v) => _updateValue(field.key, v),
      )).toList());
    }

    if (field.type == 'input_checkbox' || field.type == 'terms_and_condition') {
      List<String> current = (val as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
      if (field.options.isEmpty && field.type == 'terms_and_condition') {
        return CheckboxListTile(
          title: const Text('I agree to the terms and conditions'),
          value: current.isNotEmpty, contentPadding: EdgeInsets.zero, dense: true,
          activeColor: AppTheme.deltaDarkBlue, controlAffinity: ListTileControlAffinity.leading,
          onChanged: (v) => _updateValue(field.key, v == true ? ['on'] : []),
        );
      }
      return Column(children: field.options.map((o) {
        final checked = current.contains(o['value']);
        return CheckboxListTile(
          title: Text(o['label']!), value: checked, contentPadding: EdgeInsets.zero,
          dense: true, activeColor: AppTheme.deltaDarkBlue, controlAffinity: ListTileControlAffinity.leading,
          onChanged: (v) {
            final updated = List<String>.from(current);
            if (v == true) updated.add(o['value']!); else updated.remove(o['value']!);
            _updateValue(field.key, updated);
          },
        );
      }).toList());
    }

    if (field.type == 'input_date' || field.type == 'date') {
      final ctrl = _dateControllers.putIfAbsent(field.key, () => TextEditingController());
      if (ctrl.text.isEmpty && val != null) ctrl.text = val.toString();
      return TextFormField(
        controller: ctrl, readOnly: true,
        decoration: InputDecoration(hintText: field.placeholder ?? 'YYYY-MM-DD', suffixIcon: const Icon(Icons.calendar_today_rounded)),
        validator: (v) => field.required && (v == null || v.isEmpty) ? 'This field is required' : null,
        onTap: () async {
          final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(1900), lastDate: DateTime(2100));
          if (d != null) {
            final s = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
            _updateValue(field.key, s);
            ctrl.text = s;
          }
        },
      );
    }

    return TextFormField(
      initialValue: val?.toString(),
      decoration: InputDecoration(hintText: field.placeholder),
      maxLines: field.type == 'textarea' ? 4 : 1,
      keyboardType: field.type == 'input_email' ? TextInputType.emailAddress : (field.type == 'phone' ? TextInputType.phone : TextInputType.text),
      onChanged: (v) => _updateValue(field.key, v),
      validator: (v) => field.required && (v == null || v.isEmpty) ? 'This field is required' : null,
    );
  }
}

// -------------------- Models --------------------

class FormListItem {
  final int id;
  final String title;
  final String? description;
  final String? icon;
  FormListItem({required this.id, required this.title, this.description, this.icon});
  factory FormListItem.fromJson(Map<String, dynamic> json) => FormListItem(
    id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
    title: json['title'] ?? 'Untitled',
    description: json['description']?.toString(),
    icon: json['icon']?.toString(),
  );
}

class FormSchema {
  final int formId;
  final String title;
  final List<FormFieldSchema> fields;

  FormSchema({required this.formId, required this.title, required this.fields});

  factory FormSchema.fromMobileJson(Map<String, dynamic> json) {
    List<FormFieldSchema> parsedFields = [];

    dynamic schemaData = json['schema'];

    if (schemaData != null) {
      if (schemaData is List) {
        for (var item in schemaData) {
          if (item is Map<String, dynamic>) {
            parsedFields.add(FormFieldSchema.fromJson(item));
          }
        }
      } else if (schemaData is Map) {
        List fieldsList = schemaData['fields'] ?? schemaData.values.toList();
        for (var item in fieldsList) {
          if (item is Map<String, dynamic>) {
            parsedFields.add(FormFieldSchema.fromJson(item));
          }
        }
      }
    }

    return FormSchema(
        formId: json['form_id'] != null ? int.tryParse(json['form_id'].toString()) ?? 0 : 0,
        title: json['title']?.toString() ?? '',
        fields: parsedFields.where((f) {
          final t = f.type.toLowerCase();
          return t != 'button' && t != 'submit' && t != 'custom_submit_button';
        }).toList()
    );
  }
}

class FormFieldSchema {
  final String key;
  final String label;
  final String type;
  final bool required;
  final String? placeholder;
  final List<Map<String, String>> options;
  final List<FormFieldSchema> subFields;
  final Map<String, dynamic>? conditionalLogic;

  FormFieldSchema({
    required this.key, required this.label, required this.type, required this.required,
    this.placeholder, this.options = const [], this.subFields = const [], this.conditionalLogic
  });

  factory FormFieldSchema.fromJson(Map<String, dynamic> json) {
    final attrs = (json['attributes'] is Map) ? Map<String, dynamic>.from(json['attributes']) : <String, dynamic>{};
    final settings = (json['settings'] is Map) ? Map<String, dynamic>.from(json['settings']) : <String, dynamic>{};
    String type = json['element']?.toString() ?? 'text';

    List<FormFieldSchema> parsedSubFields = [];

    if (type == 'container' && json['columns'] is List) {
      for (var col in json['columns']) {
        List<FormFieldSchema> colFields = [];
        if (col is Map && col['fields'] is List) {
          for (var f in col['fields']) {
            if (f is Map<String, dynamic>) colFields.add(FormFieldSchema.fromJson(f));
          }
        }
        parsedSubFields.add(FormFieldSchema(key: '', label: '', type: 'column', required: false, subFields: colFields));
      }
    } else if ((type == 'input_name' || type == 'address') && json['fields'] is Map) {
      // Compound field (Name / Address): Fluent Forms keeps the parts in a keyed
      // `fields` map. Expand each visible part into its own flat input so the
      // form shows separate boxes and submits as names[first_name], address[city]…
      parsedSubFields = _expandCompound(type, attrs, Map<String, dynamic>.from(json['fields'] as Map));
    } else if (json['fields'] is List) {
      for (var f in json['fields']) {
        if (f is Map<String, dynamic>) parsedSubFields.add(FormFieldSchema.fromJson(f));
      }
    }

    List<Map<String, String>> parsedOptions = [];
    if (settings['advanced_options'] is List) {
      for (var opt in settings['advanced_options']) {
        if (opt is Map) parsedOptions.add({'label': opt['label']?.toString() ?? '', 'value': opt['value']?.toString() ?? ''});
      }
    }

    Map<String, dynamic>? logic;
    if (settings['conditional_logics'] is Map) logic = Map<String, dynamic>.from(settings['conditional_logics']);

    bool isRequired = false;
    if (settings['validation_rules'] is Map && settings['validation_rules']['required'] is Map) {
      isRequired = settings['validation_rules']['required']['value'] == true;
    } else if (settings['required'] == true) {
      // Expanded compound sub-fields store required as a direct boolean
      isRequired = true;
    }

    return FormFieldSchema(
      key: attrs['name']?.toString() ?? json['uniqElKey']?.toString() ?? '',
      label: settings['label']?.toString() ?? settings['admin_field_label']?.toString() ?? '',
      type: type,
      required: isRequired,
      placeholder: attrs['placeholder']?.toString() ?? settings['placeholder']?.toString() ?? settings['help_message']?.toString(),
      options: parsedOptions,
      subFields: parsedSubFields,
      conditionalLogic: logic,
    );
  }

  /// Expands a Fluent Forms compound element (Name / Address) into flat sub-fields.
  /// Sub-fields live in a keyed map (first_name, last_name, city, state…); each
  /// visible part becomes its own input named with bracket notation so it both
  /// renders separately and submits as e.g. names[first_name] / address[city].
  static List<FormFieldSchema> _expandCompound(
      String type, Map<String, dynamic> attrs, Map<String, dynamic> fieldsMap) {
    final parentName = (attrs['name']?.toString().isNotEmpty == true)
        ? attrs['name'].toString()
        : (type == 'address' ? 'address' : 'names');

    const nameOrder = ['prefix', 'first_name', 'middle_name', 'last_name', 'suffix'];
    const addrOrder = ['address_line_1', 'address_line_2', 'city', 'state', 'zip', 'country'];
    final order = type == 'input_name' ? nameOrder : addrOrder;

    final orderedKeys = <String>[
      ...order.where(fieldsMap.containsKey),
      ...fieldsMap.keys.where((k) => !order.contains(k)),
    ];

    final result = <FormFieldSchema>[];
    for (final k in orderedKeys) {
      final sub = fieldsMap[k];
      if (sub is! Map) continue;
      final ss = (sub['settings'] is Map) ? Map<String, dynamic>.from(sub['settings']) : <String, dynamic>{};
      final sa = (sub['attributes'] is Map) ? Map<String, dynamic>.from(sub['attributes']) : <String, dynamic>{};

      // Skip parts the admin disabled (visible:false / 0 / "0").
      final vis = ss['visible'];
      if (ss.containsKey('visible') && (vis == false || vis == 0 || vis == '0')) continue;

      bool req = ss['required'] == true;
      if (ss['validation_rules'] is Map && ss['validation_rules']['required'] is Map) {
        req = req || ss['validation_rules']['required']['value'] == true;
      }

      final rawLabel = ss['label']?.toString() ?? '';
      final label = rawLabel.isNotEmpty
          ? rawLabel
          : k.split('_').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');

      result.add(FormFieldSchema(
        key: '$parentName[$k]',
        label: label,
        type: 'input_text',
        required: req,
        placeholder: sa['placeholder']?.toString() ?? ss['placeholder']?.toString(),
      ));
    }
    return result;
  }
}

class JobItem {
  final int? id; final String title; final DateTime? deadline; final String? fileUrl, imageUrl, content;
  JobItem({this.id, required this.title, this.deadline, this.fileUrl, this.imageUrl, this.content});
  factory JobItem.fromJson(Map<String, dynamic> json) {
    String t = json['title'] is Map ? json['title']['rendered'] : json['title'].toString();
    String? img = json['featured_image'] ?? json['better_featured_image']?['source_url'] ?? json['image_url'];
    DateTime? d; try { d = DateTime.parse(json['job_deadline'] ?? json['deadline'] ?? ''); } catch (_) {}
    return JobItem(
      id: json['id'],
      title: t,
      deadline: d,
      fileUrl: json['job_file_link'] ?? json['file_url'],
      imageUrl: img,
      content: json['content']?.toString(),
    );
  }
}

class FlyerItem {
  final int? id; final String title; final DateTime? endDate; final String? fileUrl, imageUrl;
  FlyerItem({this.id, required this.title, this.endDate, this.fileUrl, this.imageUrl});
  factory FlyerItem.fromJson(Map<String, dynamic> json) {
    String t = json['title'] is Map ? json['title']['rendered'] : json['title'].toString();
    String? img = json['featured_image'] ?? json['thumbnail_url'] ?? json['better_featured_image']?['media_details']?['sizes']?['medium']?['source_url'];
    DateTime? e; try { e = DateTime.parse(_tryReadCustomField(json, 'end_date')!); } catch (_) {}
    return FlyerItem(id: json['id'], title: t, endDate: e, fileUrl: _tryReadCustomField(json, 'event_link') ?? _tryReadCustomField(json, 'event_file_link'), imageUrl: img);
  }
}

class EventItem {
  final int id;
  final String title;
  final String? overview, description, imageUrl, location, videoUrl, url;
  final DateTime? start, end;
  final List<SubEventItem> subEvents;
  final List<String> gallery;
  final Map<String, dynamic>? capacityStats;

  EventItem({
    required this.id, required this.title, this.overview, this.description,
    this.imageUrl, this.location, this.start, this.end, this.subEvents = const [],
    this.videoUrl, this.gallery = const [], this.capacityStats, this.url
  });

  factory EventItem.fromJson(Map<String, dynamic> json) {
    DateTime? d(String? s) => s == null || s.isEmpty ? null : DateTime.tryParse(s);
    List<SubEventItem> s = (json['sub_events'] as List?)?.map((e) => SubEventItem.fromJson(Map<String, dynamic>.from(e))).toList() ?? [];
    List<String> g = (json['gallery'] as List?)?.map((e) => e.toString()).toList() ?? [];

    return EventItem(
        id: json['id'] ?? 0,
        title: json['title'] ?? '',
        url: json['url'],
        overview: json['overview'],
        description: json['content_html'],
        imageUrl: json['thumbnail'],
        location: json['location'],
        start: d(json['start_date']),
        end: d(json['end_date']),
        subEvents: s,
        videoUrl: json['video_url'],
        gallery: g,
        capacityStats: json['capacity_stats']
    );
  }
}

class SubEventItem {
  final int id; final String title; final String? content; final DateTime? start, end;
  SubEventItem({required this.id, required this.title, this.content, this.start, this.end});
  factory SubEventItem.fromJson(Map<String, dynamic> json) => SubEventItem(id: json['id'], title: json['title'], content: json['content'], start: DateTime.tryParse(json['start_date']??''), end: DateTime.tryParse(json['end_date']??''));
}

// --- الموديل الجديد لبيانات الكورس ---
class LessonItem {
  final int index;
  final int id;
  final String title;
  final String duration;
  final String videoUrl;
  final List<String> outcomes;

  LessonItem({
    required this.index, required this.id, required this.title,
    required this.duration, required this.videoUrl, required this.outcomes
  });

  factory LessonItem.fromJson(Map<String, dynamic> json) {
    return LessonItem(
      index: json['lesson_index'] ?? 0,
      id: json['lesson_id'] ?? 0,
      title: json['title'] ?? 'Untitled Lesson',
      duration: json['duration'] ?? '0 mins',
      videoUrl: json['video_embed_url'] ?? '',
      outcomes: (json['learning_goals'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  String? get youtubeId {
    try {
      if (videoUrl.contains('embed/')) {
        return videoUrl.split('embed/')[1].split('?')[0];
      }
      return YoutubePlayer.convertUrlToId(videoUrl);
    } catch (e) {
      return null;
    }
  }
}