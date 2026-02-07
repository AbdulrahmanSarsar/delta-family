// Delta Flutter App - Optimized & Fixed
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
import 'package:lottie/lottie.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

// -------------------- Helpers --------------------

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
  static const String WEBSITE_URL = 'https://dfrc.ca/';
  static const String HEADER_IMAGE_URL = 'https://dfrc.ca/wp-content/uploads/2026/01/Delta-zoom-background-3.jpg-Sep-24.jpg';

  static Map<String, String> get AUTH_HEADERS => {'Accept': 'application/json'};
}

class AppTheme {
  static const Color deltaDarkBlue = Color(0xFF003B70);
  static const Color deltaLightBlue = Color(0xFF2D7FCE);
  static const Color deltaYellow = Color(0xFFFFC72C);
  static const Color bgGrey = Color(0xFFF8F9FA);

  // ستايل موحد للكروت لاستخدامه يدوياً بدلاً من Theme لتجنب الأخطاء
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
  final List<Widget> _pages = const [HomeTab(), EventsTab(), ProgramsTab(), JobsTab(), FlyersTab()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.calendar_month_rounded), label: 'Events'),
            BottomNavigationBarItem(icon: Icon(Icons.people_alt_rounded), label: 'Programs'),
            BottomNavigationBarItem(icon: Icon(Icons.work_rounded), label: 'Jobs'),
            BottomNavigationBarItem(icon: Icon(Icons.campaign_rounded), label: 'Flyers'),
          ],
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
      final res = await http.get(Uri.parse(ApiConfig.EVENTS_API), headers: ApiConfig.AUTH_HEADERS);
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
      final res = await http.get(Uri.parse(ApiConfig.JOBS_API), headers: ApiConfig.AUTH_HEADERS);
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
      final res = await http.get(Uri.parse(ApiConfig.FLYERS_API), headers: ApiConfig.AUTH_HEADERS);
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
                  const SizedBox(height: 30),
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
            child: Image.network(ApiConfig.HEADER_IMAGE_URL, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(color: AppTheme.deltaLightBlue)),
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
                            Hero(tag: 'flyer_home_${f.id ?? f.title}', child: Image.network(f.imageUrl!, fit: BoxFit.cover))
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
  List<EventItem> _events = [];

  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }

  Future<void> _fetchEvents() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(Uri.parse(ApiConfig.EVENTS_API), headers: ApiConfig.AUTH_HEADERS);
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        final list = data.map((e) => EventItem.fromJson(Map<String, dynamic>.from(e))).toList();
        list.sort((a, b) => (a.start ?? DateTime.now()).compareTo(b.start ?? DateTime.now()));
        if (mounted) setState(() => _events = list);
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upcoming Events')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _events.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.event_busy, size: 80, color: Colors.grey[400]), const SizedBox(height: 16), const Text('No upcoming events', style: TextStyle(fontSize: 18, color: Colors.grey))]))
          : RefreshIndicator(
        onRefresh: _fetchEvents,
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
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
              background: event.imageUrl != null ? Image.network(event.imageUrl!, fit: BoxFit.cover) : Container(color: AppTheme.deltaDarkBlue, child: const Center(child: Icon(Icons.event, size: 60, color: Colors.white24))),
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
                    if (event.location != null) _buildInfoRow(Icons.location_on, event.location!),
                    const Divider(height: 30),
                    if (event.overview != null) ...[
                      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.05), border: const Border(left: BorderSide(color: AppTheme.deltaDarkBlue, width: 4))), child: Text(event.overview!, style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic))),
                      const SizedBox(height: 20),
                    ],
                    if (event.description != null) Html(data: event.description!),
                    if (event.subEvents.isNotEmpty) ...[
                      const SizedBox(height: 20),
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

  Widget _buildInfoRow(IconData icon, String text) => Padding(padding: const EdgeInsets.only(bottom: 8.0), child: Row(children: [Icon(icon, size: 18, color: Colors.grey[600]), const SizedBox(width: 8), Expanded(child: Text(text, style: const TextStyle(fontSize: 15, color: Colors.black87)))]));

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

class ProgramsTab extends StatefulWidget {
  const ProgramsTab({Key? key}) : super(key: key);
  @override
  State<ProgramsTab> createState() => _ProgramsTabState();
}

class _ProgramsTabState extends State<ProgramsTab> {
  bool _loading = true;
  List<FormListItem> _forms = [];

  @override
  void initState() {
    super.initState();
    _fetchFormsList();
  }

  Future<void> _fetchFormsList() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(Uri.parse(ApiConfig.FORMS_LIST_API), headers: ApiConfig.AUTH_HEADERS);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        List raw = (data is List) ? data : (data['forms'] ?? []);
        // FIX: Ensure casting
        if (mounted) setState(() => _forms = raw.map((e) => FormListItem.fromJson(Map<String, dynamic>.from(e))).toList());
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Programs')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _forms.isEmpty
          ? const Center(child: Text('No forms found'))
          : RefreshIndicator(
        onRefresh: _fetchFormsList,
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: _forms.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, idx) {
            final f = _forms[idx];
            return Card(
              color: Colors.white, elevation: 0.5, shape: AppTheme.cardShape,
              child: ListTile(
                title: Text(f.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DynamicFormPage(formId: f.id, title: f.title))),
              ),
            );
          },
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
      final res = await http.get(Uri.parse(ApiConfig.JOBS_API), headers: ApiConfig.AUTH_HEADERS);
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
          padding: const EdgeInsets.all(16),
          itemCount: _jobs.length,
          itemBuilder: (context, index) {
            final job = _jobs[index];
            return Card(
              color: Colors.white, elevation: 0.5, shape: AppTheme.cardShape,
              child: InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => JobDetailPage(job: job))),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 60, height: 60,
                        decoration: BoxDecoration(color: AppTheme.deltaLightBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                        child: job.imageUrl != null
                            ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(job.imageUrl!, fit: BoxFit.cover))
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
              child: job.imageUrl != null ? Image.network(job.imageUrl!, fit: BoxFit.cover) : const Icon(Icons.business_center, size: 80, color: AppTheme.deltaDarkBlue),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(job.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  if (job.deadline != null) Chip(label: Text('Apply by: ${DateFormat.yMMMd().format(job.deadline!)}'), backgroundColor: Colors.red.shade50, labelStyle: const TextStyle(color: Colors.red), side: BorderSide.none),
                  const SizedBox(height: 20), const Divider(), const SizedBox(height: 20),
                  const Text("Description", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 10),
                  const Text("We are looking for passionate individuals to join Delta Family Resource Centre. Please download the document below for full details.", style: TextStyle(height: 1.5, color: Colors.black87)),
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
      final res = await http.get(Uri.parse(ApiConfig.FLYERS_API), headers: ApiConfig.AUTH_HEADERS);
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
          : _error != null ? Center(child: Text(_error!))
          : RefreshIndicator(
        onRefresh: _fetchFlyers,
        child: _items.isEmpty
            ? ListView(children: [SizedBox(height: MediaQuery.of(context).size.height * 0.2), Lottie.asset('assets/lottie/noResultFound.json', width: 250, height: 250, repeat: false), const Center(child: Text('No flyers available'))])
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _items.length,
          itemBuilder: (context, index) {
            final flyer = _items[index];
            return Card(
              color: Colors.white, elevation: 0.5, shape: AppTheme.cardShape,
              child: InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FlyerDetailPage(flyer: flyer))),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 60, height: 60,
                        decoration: BoxDecoration(color: AppTheme.deltaLightBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                        child: flyer.imageUrl != null
                            ? Hero(tag: 'flyer_list_${flyer.id ?? flyer.title}', child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(flyer.imageUrl!, fit: BoxFit.cover)))
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
    final String heroTag = 'flyer_list_${flyer.id ?? flyer.title}';

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
                    Hero(tag: heroTag, child: Image.network(flyer.imageUrl!, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.grey.shade200)))
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
                padding: const EdgeInsets.all(24.0),
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
    Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(backgroundColor: Colors.black, appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)), body: Center(child: PhotoView(imageProvider: NetworkImage(flyer.imageUrl!), heroAttributes: PhotoViewHeroAttributes(tag: 'flyer_list_${flyer.id ?? flyer.title}'))))));
  }

  Future<void> _download(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Downloading...'), duration: Duration(seconds: 1)));
    final path = await downloadFileInApp(flyer.fileUrl!, filename: Uri.parse(flyer.fileUrl!).pathSegments.last);
    if (path != null) OpenFile.open(path);
  }
}

// -------------------- Dynamic Form Page --------------------

class DynamicFormPage extends StatefulWidget {
  final int formId;
  final String title;
  const DynamicFormPage({Key? key, required this.formId, required this.title}) : super(key: key);
  @override
  State<DynamicFormPage> createState() => _DynamicFormPageState();
}

class _DynamicFormPageState extends State<DynamicFormPage> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  FormSchema? _schema;
  final Map<String, dynamic> _formData = {};

  @override
  void initState() {
    super.initState();
    _fetchSchema();
  }

  Future<void> _fetchSchema() async {
    try {
      final res = await http.get(Uri.parse(ApiConfig.FORM_SCHEMA_API.replaceAll('{id}', widget.formId.toString())), headers: ApiConfig.AUTH_HEADERS);
      if (res.statusCode == 200) {
        setState(() { _schema = FormSchema.fromMobileJson(jsonDecode(res.body)); _loading = false; });
      } else { throw 'Error'; }
    } catch (e) { setState(() => _loading = false); }
  }

  bool _shouldShowField(FormFieldSchema field) {
    if (field.conditionalLogic == null || field.conditionalLogic!['status'] != true) return true;
    for (var group in field.conditionalLogic!['condition_groups'] ?? []) {
      for (var rule in group['rules'] ?? []) {
        if (_formData[rule['field']]?.toString() == rule['value']) return true;
      }
    }
    return false;
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => _loading = true);
    try {
      final headers = Map<String, String>.from(ApiConfig.AUTH_HEADERS)..remove('Content-Type');
      final res = await http.post(Uri.parse(ApiConfig.FORM_SUBMIT_API), headers: headers, body: {'form_id': widget.formId.toString(), 'data': jsonEncode(_formData)});
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        if (d['status'] == false) throw d['message'];
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(d['message'] ?? 'Success')));
        Navigator.pop(context);
      } else { throw 'Failed'; }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally { setState(() => _loading = false); }
  }

  void _updateValue(String key, dynamic value, {String? parentKey}) {
    if (parentKey != null) {
      if (_formData[parentKey] is! Map) _formData[parentKey] = {};
      _formData[parentKey][key] = value;
    } else { _formData[key] = value; }
    setState(() {});
  }

  dynamic _getValue(String key, {String? parentKey}) => parentKey != null ? (_formData[parentKey] is Map ? _formData[parentKey][key] : null) : _formData[key];

  @override
  Widget build(BuildContext context) {
    if (_loading && _schema == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              ..._schema!.fields.map((f) => _buildField(f)).toList(),
              const SizedBox(height: 30),
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _loading ? null : _submitForm, style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: AppTheme.deltaDarkBlue, foregroundColor: Colors.white), child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('Submit', style: TextStyle(fontSize: 18)))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(FormFieldSchema field) {
    if (!_shouldShowField(field)) return const SizedBox.shrink();
    if (field.type == 'section') return Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(field.label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.deltaDarkBlue)), const Divider()]));
    if (field.subFields.isNotEmpty) return Container(margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [if(field.label.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(field.label, style: const TextStyle(fontWeight: FontWeight.bold))), ...field.subFields.map((s) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _buildInput(s, parentKey: field.key)))]));
    return Padding(padding: const EdgeInsets.only(bottom: 16), child: _buildInput(field));
  }

  Widget _buildInput(FormFieldSchema field, {String? parentKey}) {
    final val = _getValue(field.key, parentKey: parentKey);
    final decor = InputDecoration(labelText: field.label + (field.required ? ' *' : ''), hintText: field.placeholder);
    if (field.type == 'select') return DropdownButtonFormField<String>(decoration: decor, value: val?.toString(), items: field.options.map((o) => DropdownMenuItem(value: o['value'], child: Text(o['label']!))).toList(), onChanged: (v) => _updateValue(field.key, v, parentKey: parentKey));
    if (field.type == 'date') return TextFormField(controller: TextEditingController(text: val?.toString()), readOnly: true, decoration: decor.copyWith(suffixIcon: const Icon(Icons.calendar_today)), onTap: () async { final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(1900), lastDate: DateTime(2100)); if(d!=null) _updateValue(field.key, "${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}", parentKey: parentKey); });
    return TextFormField(initialValue: val?.toString(), decoration: decor, maxLines: field.type == 'textarea' ? 4 : 1, onChanged: (v) => _updateValue(field.key, v, parentKey: parentKey), validator: (v) => field.required && (v==null||v.isEmpty) ? 'Required' : null);
  }
}

// -------------------- Models --------------------

class FormListItem {
  final int id; final String title;
  FormListItem({required this.id, required this.title});
  factory FormListItem.fromJson(Map<String, dynamic> json) => FormListItem(id: json['id'] ?? json['form_id'] ?? 0, title: json['title'] ?? 'Untitled');
}

class FormSchema {
  final int formId; final String title; final List<FormFieldSchema> fields;
  FormSchema({required this.formId, required this.title, required this.fields});
  factory FormSchema.fromMobileJson(Map<String, dynamic> json) { // <-- تم تحديد النوع كـ Map
    List<FormFieldSchema> parse(dynamic j) {
      if(j is! Map) return [];
      if(j['element']=='container' && j['columns'] is List) return (j['columns'] as List).expand((c) => (c['fields'] as List).expand((f) => parse(f))).toList();
      return [FormFieldSchema.fromJson(Map<String, dynamic>.from(j))]; // <-- تحويل صريح هنا
    }
    List<FormFieldSchema> fields = [];
    if (json['schema'] is List) {
      for (var i in json['schema']) if(i['raw'] != null) fields.addAll(i['raw'] is List ? (i['raw'] as List).expand((x) => parse(x)) : parse(i['raw']));
    }
    return FormSchema(formId: json['form_id'] ?? 0, title: json['title'] ?? '', fields: fields.where((f) => f.type != 'submit').toList());
  }
}

class FormFieldSchema {
  final String key, label, type; final bool required; final String? placeholder, htmlContent;
  final List<Map<String, String>> options; final List<FormFieldSchema> subFields; final Map<String, dynamic>? conditionalLogic;
  FormFieldSchema({required this.key, required this.label, required this.type, required this.required, this.placeholder, this.options=const[], this.subFields=const[], this.conditionalLogic, this.htmlContent});
  factory FormFieldSchema.fromJson(Map<String, dynamic> json) {
    var s = Map<String, dynamic>.from(json['settings'] ?? {}); // <-- تحويل صريح
    var a = Map<String, dynamic>.from(json['attributes'] ?? {}); // <-- تحويل صريح
    String type = (json['element'] ?? 'text').toString();
    if (['input_text','input_email','phone'].contains(type)) type = 'text';
    if (['select','select_country'].contains(type)) type = 'select';
    if (['section_break','custom_html'].contains(type)) type = 'section';
    List<Map<String, String>> opts = [];
    if(s['advanced_options'] is List) for(var o in s['advanced_options']) opts.add({'label': o['label'].toString(), 'value': o['value'].toString()});
    List<FormFieldSchema> subs = [];
    if(json['fields'] is List) for(var f in json['fields']) subs.add(FormFieldSchema.fromJson(Map<String, dynamic>.from(f))); // <-- تحويل صريح

    Map<String, dynamic>? logic;
    if(s['conditional_logics'] != null && s['conditional_logics'] is Map) {
      logic = Map<String, dynamic>.from(s['conditional_logics']); // <-- تحويل صريح للـ logic
    }

    return FormFieldSchema(key: a['name'] ?? json['uniqElKey'] ?? '', label: s['label'] ?? '', type: type, required: s['validation_rules']?['required']?['value'] == true, placeholder: a['placeholder'], options: opts, subFields: subs, conditionalLogic: logic, htmlContent: s['html_codes']);
  }
}

class JobItem {
  final int? id; final String title; final DateTime? deadline; final String? fileUrl, imageUrl;
  JobItem({this.id, required this.title, this.deadline, this.fileUrl, this.imageUrl});
  factory JobItem.fromJson(Map<String, dynamic> json) {
    String t = json['title'] is Map ? json['title']['rendered'] : json['title'].toString();
    String? img = json['better_featured_image']?['source_url'] ?? json['image_url'];
    DateTime? d; try { d = DateTime.parse(json['job_deadline'] ?? json['deadline']); } catch (_) {}
    return JobItem(id: json['id'], title: t, deadline: d, fileUrl: json['job_file_link'] ?? json['file_url'], imageUrl: img);
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
  final int id; final String title; final String? overview, description, imageUrl, location; final DateTime? start, end; final List<SubEventItem> subEvents;
  EventItem({required this.id, required this.title, this.overview, this.description, this.imageUrl, this.location, this.start, this.end, this.subEvents = const []});
  factory EventItem.fromJson(Map<String, dynamic> json) {
    DateTime? d(String? s) => s == null ? null : DateTime.tryParse(s);
    List<SubEventItem> s = (json['sub_events'] as List?)?.map((e) => SubEventItem.fromJson(Map<String, dynamic>.from(e))).toList() ?? [];
    return EventItem(id: json['id'], title: json['title'], overview: json['overview'], description: json['content_html'], imageUrl: json['thumbnail'], location: json['location'], start: d(json['start_date']), end: d(json['end_date']), subEvents: s);
  }
}

class SubEventItem {
  final int id; final String title; final String? content; final DateTime? start, end;
  SubEventItem({required this.id, required this.title, this.content, this.start, this.end});
  factory SubEventItem.fromJson(Map<String, dynamic> json) => SubEventItem(id: json['id'], title: json['title'], content: json['content'], start: DateTime.tryParse(json['start_date']??''), end: DateTime.tryParse(json['end_date']??''));
}
