import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Brand color
const BRAND = Color(0xFF9B5DE0);
const BRAND_DARK = Color(0xFF7E3CCB);
const BRAND_LIGHT = Color(0xFFD1B6F3);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MuudApp());
}

class MuudApp extends StatelessWidget {
  const MuudApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: BRAND, brightness: Brightness.light);
    return MaterialApp(
      title: 'MUUD Health',
      themeMode: ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: scheme.surface,
        appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
        // FIX: use CardThemeData (not CardTheme)
        cardTheme: CardThemeData(
          color: scheme.surface,
          elevation: 1,
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: scheme.surfaceContainerHighest.withOpacity(0.4),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: scheme.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: scheme.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: scheme.primary, width: 2),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          elevation: 1,
          indicatorColor: scheme.primaryContainer,
          backgroundColor: scheme.surface,
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurface),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      home: const _Root(),
    );
  }
}

/// Root decides whether to show Auth or Home based on stored session.
class _Root extends StatefulWidget {
  const _Root({super.key});
  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  String? _token, _userId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sp = await SharedPreferences.getInstance();
    setState(() {
      _token = sp.getString('token');
      _userId = sp.getString('userId');
    });
  }

  Future<void> _save(String token, String userId) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('token', token);
    await sp.setString('userId', userId);
    setState(() {
      _token = token;
      _userId = userId;
    });
  }

  Future<void> _logout() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove('token');
    await sp.remove('userId');
    setState(() {
      _token = null;
      _userId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return (_token == null || _userId == null)
        ? AuthScreen(onLogin: _save)
        : HomeScreen(token: _token!, userId: _userId!, onLogout: _logout);
  }
}

/// ---------------- API CLIENT (Web -> localhost:4000) ----------------
class Api {
  static const String base = 'http://localhost:4000';

  static Map<String, String> headers([String? token]) => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  static Future<(String token, String userId)> register(
      String email, String password, String name) async {
    final res = await http.post(Uri.parse('$base/auth/register'),
        headers: headers(),
        body: jsonEncode({'email': email, 'password': password, 'name': name}));
    final body = jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return (body['token'] as String, body['user']['id'] as String);
    }
    throw body['error'] ?? 'Registration failed';
  }

  static Future<(String token, String userId)> login(
      String email, String password) async {
    final res = await http.post(Uri.parse('$base/auth/login'),
        headers: headers(),
        body: jsonEncode({'email': email, 'password': password}));
    final body = jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return (body['token'] as String, body['user']['id'] as String);
    }
    throw body['error'] ?? 'Login failed';
  }

  static Future<List<Map<String, dynamic>>> getJournal(
      String token, String userId) async {
    final res = await http.get(Uri.parse('$base/journal/user/$userId'),
        headers: headers(token));
    final body = jsonDecode(res.body);
    if (res.statusCode == 200 && body['success'] == true) {
      return List<Map<String, dynamic>>.from(body['entries']);
    }
    throw body['error'] ?? 'Fetch journal failed';
  }

  static Future<int> createJournal(
      String token, String userId, String text, int mood) async {
    final res = await http.post(Uri.parse('$base/journal/entry'),
        headers: headers(token),
        body: jsonEncode(
            {'user_id': userId, 'entry_text': text, 'mood_rating': mood}));
    final body = jsonDecode(res.body);
    if (res.statusCode == 201 && body['success'] == true) {
      return int.parse(body['id'].toString());
    }
    throw body['error'] ?? 'Create journal failed';
  }

  static Future<List<Map<String, dynamic>>> getContacts(
      String token, String userId) async {
    final res = await http.get(Uri.parse('$base/contacts/user/$userId'),
        headers: headers(token));
    final body = jsonDecode(res.body);
    if (res.statusCode == 200 && body['success'] == true) {
      return List<Map<String, dynamic>>.from(body['contacts']);
    }
    throw body['error'] ?? 'Fetch contacts failed';
  }

  static Future<int> addContact(
      String token, String userId, String name, String email) async {
    final res = await http.post(Uri.parse('$base/contacts/add'),
        headers: headers(token),
        body: jsonEncode({
          'user_id': userId,
          'contact_name': name,
          'contact_email': email,
        }));
    final body = jsonDecode(res.body);
    if (res.statusCode == 201 && body['success'] == true) {
      return int.parse(body['id'].toString());
    }
    throw body['error'] ?? 'Add contact failed';
  }
}

/// ---------------- AUTH ----------------
class AuthScreen extends StatefulWidget {
  final Future<void> Function(String token, String userId) onLogin;
  const AuthScreen({super.key, required this.onLogin});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final email = TextEditingController(text: 'kushal@example.com');
  final password = TextEditingController(text: 'secret123');
  final name = TextEditingController(text: 'Kushal');
  bool showRegister = false;
  bool busy = false;
  String? error;

  Future<void> _submit() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      late String token;
      late String userId;
      if (showRegister) {
        (token, userId) = await Api.register(
          email.text.trim(),
          password.text,
          name.text.trim(),
        );
      } else {
        (token, userId) = await Api.login(
          email.text.trim(),
          password.text.trim(),
        );
      }
      await widget.onLogin(token, userId);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Welcome!')));
      }
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Card(
              elevation: 2,
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _GradientHeader(
                      title: showRegister ? 'Create your account' : 'Welcome back',
                      subtitle: 'MUUD Health',
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.alternate_email),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (showRegister) ...[
                      TextField(
                        controller: name,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: password,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(error!,
                            style:
                                TextStyle(color: scheme.error, fontWeight: FontWeight.w600)),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: busy ? null : _submit,
                            child: Text(busy
                                ? 'Please wait...'
                                : (showRegister ? 'Create account' : 'Login')),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => setState(() => showRegister = !showRegister),
                      child: Text(showRegister
                          ? 'Have an account? Sign in'
                          : 'No account? Register'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pretty gradient header used on multiple screens.
class _GradientHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _GradientHeader({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [BRAND, BRAND_DARK],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (subtitle != null)
            Text(subtitle!,
                style: TextStyle(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5)),
          Text(title,
              style: TextStyle(
                color: scheme.onPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              )),
        ],
      ),
    );
  }
}

/// ---------------- HOME (tabs) ----------------
class HomeScreen extends StatefulWidget {
  final String token;
  final String userId;
  final VoidCallback onLogout;
  const HomeScreen({super.key, required this.token, required this.userId, required this.onLogout});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      JournalScreen(token: widget.token, userId: widget.userId),
      ContactsScreen(token: widget.token, userId: widget.userId),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('MUUD Health'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [BRAND, BRAND_DARK]),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: pages[index],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.edit_note_rounded), label: 'Journal'),
          NavigationDestination(icon: Icon(Icons.groups_rounded), label: 'Contacts'),
        ],
      ),
    );
  }
}

/// ---------------- JOURNAL ----------------
class JournalScreen extends StatefulWidget {
  final String token;
  final String userId;
  const JournalScreen({super.key, required this.token, required this.userId});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final text = TextEditingController();
  int mood = 3;
  bool busy = false;
  List<Map<String, dynamic>> entries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => busy = true);
    try {
      entries = await Api.getJournal(widget.token, widget.userId);
      setState(() {});
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _submit() async {
    if (text.text.trim().isEmpty) return;
    setState(() => busy = true);
    try {
      await Api.createJournal(widget.token, widget.userId, text.text.trim(), mood);
      text.clear();
      await _load();
      _snack('Entry saved');
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        _GradientHeader(title: 'Journal', subtitle: 'How are you feeling today?'),
        const SizedBox(height: 14),

        // Entry composer
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(
                controller: text,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Today I feel...',
                  hintText: 'Write a short reflection',
                ),
              ),
              const SizedBox(height: 12),
              Text('Mood', style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface)),
              const SizedBox(height: 8),
              _MoodChips(
                value: mood,
                onChanged: (v) => setState(() => mood = v),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: busy ? null : _submit,
                      icon: const Icon(Icons.save_rounded),
                      label: Text(busy ? 'Saving...' : 'Save entry'),
                    ),
                  ),
                ],
              ),
            ]),
          ),
        ),

        const SizedBox(height: 10),

        // History
        Align(
          alignment: Alignment.centerLeft,
          child: Text('History',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 8),
        for (final e in entries)
          _JournalCard(
            text: e['entry_text'] ?? '',
            mood: (e['mood_rating'] ?? 0) as int,
            ts: _parseLocal(e['timestamp']),
          ),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Text('No entries yet — write your first one!',
                style: TextStyle(color: scheme.outline)),
          ),
      ]),
    );
  }
}

class _MoodChips extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _MoodChips({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final moods = <int, String>{1: '😞', 2: '🙁', 3: '😐', 4: '🙂', 5: '😄'};
    return Wrap(
      spacing: 8,
      children: moods.entries.map((e) {
        final selected = value == e.key;
        return ChoiceChip(
          label: Text('${e.value}  ${e.key}'),
          selected: selected,
          onSelected: (_) => onChanged(e.key),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          selectedColor: BRAND_LIGHT,
        );
      }).toList(),
    );
  }
}

class _JournalCard extends StatelessWidget {
  final String text;
  final int mood;
  final DateTime? ts;
  const _JournalCard({required this.text, required this.mood, required this.ts});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text('Mood $mood', style: TextStyle(color: scheme.onPrimaryContainer)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(text, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 6),
              Text(
                ts != null ? _format(ts!) : '',
                style: TextStyle(color: scheme.outline),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// ---------------- CONTACTS ----------------
class ContactsScreen extends StatefulWidget {
  final String token;
  final String userId;
  const ContactsScreen({super.key, required this.token, required this.userId});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final name = TextEditingController();
  final email = TextEditingController();
  bool busy = false;
  List<Map<String, dynamic>> contacts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => busy = true);
    try {
      contacts = await Api.getContacts(widget.token, widget.userId);
      setState(() {});
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _submit() async {
    if (name.text.trim().isEmpty || email.text.trim().isEmpty) return;
    setState(() => busy = true);
    try {
      await Api.addContact(widget.token, widget.userId, name.text.trim(), email.text.trim());
      name.clear();
      email.clear();
      await _load();
      _snack('Contact added');
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _GradientHeader(title: 'Contacts', subtitle: 'Your support circle'),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.alternate_email),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy ? null : _submit,
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: Text(busy ? 'Saving...' : 'Add contact'),
                  ),
                ),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: Text('Your contacts',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 8),
        for (final c in contacts)
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: scheme.secondaryContainer,
                child: const Icon(Icons.person, color: Colors.white),
              ),
              title: Text(c['contact_name'] ?? ''),
              // FIX: handle nullable DateTime using a helper
              subtitle: Text('${c['contact_email'] ?? ''}\n${_formatMaybe(_parseLocal(c['created_at']))}'),
              isThreeLine: true,
            ),
          ),
        if (contacts.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Text('No contacts yet — add someone important.',
                style: TextStyle(color: scheme.outline)),
          ),
      ]),
    );
  }
}

/// ---------------- utils ----------------
DateTime? _parseLocal(dynamic s) {
  if (s is String && s.isNotEmpty) {
    try { return DateTime.parse(s).toLocal(); } catch (_) {}
  }
  return null;
}

String _pad2(int v) => v.toString().padLeft(2, '0');
String _format(DateTime d) =>
    '${d.year}-${_pad2(d.month)}-${_pad2(d.day)}  ${_pad2(d.hour)}:${_pad2(d.minute)}';

// NEW: safely format nullable datetimes
String _formatMaybe(DateTime? d) => d == null ? '' : _format(d);