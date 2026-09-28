import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

const supabaseUrl = 'https://illhoplnypumnvnkvavo.supabase.co';
const supabaseKey = 'sb_publishable_8rADrLEI5zrW2amgUZXhpg_R2EhOrQH';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  runApp(const App());
}

final db = Supabase.instance.client;

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Freelance Project Finder',
        theme: ThemeData(useMaterial3: true),
        home: StreamBuilder<AuthState>(
          stream: db.auth.onAuthStateChange,
          builder: (_, __) => db.auth.currentSession == null
              ? const LoginPage()
              : const HomePage(),
        ),
      );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final pass = TextEditingController();
  bool busy = false;
  String? error;

  Future<void> login() async {
    setState(() { busy = true; error = null; });
    try {
      await db.auth.signInWithPassword(email: email.text.trim(), password: pass.text);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> signup() async {
    setState(() { busy = true; error = null; });
    try {
      await db.auth.signUp(email: email.text.trim(), password: pass.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ایمیل تأیید را بررسی کنید.')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(children: [
                  const Icon(Icons.work_outline, size: 72),
                  const SizedBox(height: 16),
                  const Text('Freelance Project Finder', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 28),
                  TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'ایمیل', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: pass, obscureText: true, decoration: const InputDecoration(labelText: 'رمز عبور', border: OutlineInputBorder())),
                  if (error != null) Padding(padding: const EdgeInsets.all(8), child: Text(error!, style: const TextStyle(color: Colors.red))),
                  const SizedBox(height: 16),
                  SizedBox(width: double.infinity, child: FilledButton(onPressed: busy ? null : login, child: Text(busy ? '...' : 'ورود'))),
                  TextButton(onPressed: busy ? null : signup, child: const Text('ساخت حساب')),
                ]),
              ),
            ),
          ),
        ),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int tab = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Freelance Project Finder'), actions: [IconButton(onPressed: () => db.auth.signOut(), icon: const Icon(Icons.logout))]),
        body: [const ProjectsPage(), const FiltersPage(), const SettingsPage()][tab],
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (v) => setState(() => tab = v),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.work_outline), label: 'پروژه‌ها'),
            NavigationDestination(icon: Icon(Icons.tune), label: 'فیلترها'),
            NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'تنظیمات'),
          ],
        ),
      );
}

class ProjectsPage extends StatefulWidget {
  const ProjectsPage({super.key});
  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  Future<List<dynamic>> load() async => await db.from('projects').select('*,platforms(name)').order('first_seen_at', ascending: false).limit(100);

  Future<void> status(dynamic id, String value) async {
    await db.from('projects').update({'status': value}).eq('id', id);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(
        future: load(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('خطا در دریافت پروژه‌ها:\n${snapshot.error}', textAlign: TextAlign.center)));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.isEmpty) return const Center(child: Text('هنوز پروژه‌ای ثبت نشده است.'));
          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, i) {
                final p = snapshot.data![i] as Map<String, dynamic>;
                final platform = (p['platforms'] as Map?)?['name'] ?? '';
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    title: Text(p['title']?.toString() ?? ''),
                    subtitle: Text('$platform • ${p['budget_text'] ?? 'بودجه نامشخص'}\nامتیاز: ${p['match_score'] ?? '-'}'),
                    isThreeLine: true,
                    onTap: () async {
                      final url = p['project_url']?.toString();
                      if (url != null && url.isNotEmpty) await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                    },
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) => status(p['id'], v),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'reviewed', child: Text('بررسی شد')),
                        PopupMenuItem(value: 'proposal_sent', child: Text('پیشنهاد ارسال شد')),
                        PopupMenuItem(value: 'rejected', child: Text('رد شد')),
                        PopupMenuItem(value: 'cancelled', child: Text('کنسل شد')),
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

class FiltersPage extends StatefulWidget {
  const FiltersPage({super.key});
  @override
  State<FiltersPage> createState() => _FiltersPageState();
}

class _FiltersPageState extends State<FiltersPage> {
  Future<List<dynamic>> load() async => await db.from('filter_terms').select('id,term,term_type,weight').order('weight', ascending: false);

  Future<void> add() async {
    var profiles = await db.from('filter_profiles').select('id').limit(1);
    if (profiles.isEmpty) {
      await db.from('filter_profiles').insert({'name': 'Excel & Data', 'min_match_score': 60});
      profiles = await db.from('filter_profiles').select('id').limit(1);
    }
    if (profiles.isEmpty) return;
    final term = TextEditingController();
    String type = 'preferred';
    double weight = 15;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialog) => AlertDialog(
          title: const Text('فیلتر جدید'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: term, decoration: const InputDecoration(labelText: 'کلمه/عبارت')),
            DropdownButton<String>(
              value: type,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'required', child: Text('ضروری')),
                DropdownMenuItem(value: 'preferred', child: Text('ترجیحی')),
                DropdownMenuItem(value: 'excluded', child: Text('حذف‌کننده')),
              ],
              onChanged: (v) { if (v != null) setDialog(() => type = v); },
            ),
            Slider(value: weight, min: 1, max: 30, divisions: 29, label: weight.round().toString(), onChanged: (v) => setDialog(() => weight = v)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('لغو')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('ذخیره')),
          ],
        ),
      ),
    );
    if (ok == true && term.text.trim().isNotEmpty) {
      await db.from('filter_terms').insert({'profile_id': profiles.first['id'], 'term': term.text.trim(), 'term_type': type, 'weight': weight.round()});
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        floatingActionButton: FloatingActionButton(onPressed: add, child: const Icon(Icons.add)),
        body: FutureBuilder<List<dynamic>>(
          future: load(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Center(child: Text('خطا در دریافت فیلترها:\n${snapshot.error}', textAlign: TextAlign.center));
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            if (snapshot.data!.isEmpty) return const Center(child: Text('هنوز فیلتری تعریف نشده است.'));
            return ListView(
              children: snapshot.data!.map((x) => ListTile(
                title: Text(x['term']?.toString() ?? ''),
                subtitle: Text('${x['term_type']} • وزن ${x['weight']}'),
                trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () async { await db.from('filter_terms').delete().eq('id', x['id']); if (mounted) setState(() {}); }),
              )).toList(),
            );
          },
        ),
      );
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(leading: const Icon(Icons.person_outline), title: const Text('حساب'), subtitle: Text(db.auth.currentUser?.email ?? '')),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('بررسی پلتفرم‌ها'),
            subtitle: const Text('اجرای بررسی پروژه‌های جدید'),
            trailing: FilledButton(
              onPressed: () async {
                try {
                  final result = await db.functions.invoke('scan-projects');
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('بررسی انجام شد: ${result.data}')));
                } catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطا: $e')));
                }
              },
              child: const Text('بررسی'),
            ),
          ),
          const ListTile(leading: Icon(Icons.notifications_outlined), title: Text('اعلان‌ها'), subtitle: Text('Push notification در مرحله بعد فعال می‌شود.')),
          const ListTile(leading: Icon(Icons.security_outlined), title: Text('امنیت'), subtitle: Text('دسترسی داده‌ها باید با RLS در Supabase محدود شود.')),
        ],
      );
}
