import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// ==== Brand palette ====
const BRAND = Color(0xFF9B5DE0);     // primary
const BRAND_DARK = Color(0xFF7E3CCB); // gradient end
const ACCENT = Color(0xFF00D9C8);     // subtle accent

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MuudApp());
}

/// Root with light/dark toggle (nice for demos)
class MuudApp extends StatefulWidget {
  const MuudApp({super.key});
  @override
  State<MuudApp> createState() => _MuudAppState();
}

class _MuudAppState extends State<MuudApp> {
  ThemeMode mode = ThemeMode.light;

  @override
  Widget build(BuildContext context) {
    final light = _buildTheme(Brightness.light);
    final dark = _buildTheme(Brightness.dark);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MUUD Health',
      themeMode: mode,
      theme: light,
      darkTheme: dark,
      home: _Root(
        onToggleTheme: () {
          setState(() {
            mode = mode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
          });
        },
        isDark: mode == ThemeMode.dark,
      ),
    );
  }
}

/// Build a modern Material 3 theme from seed, with rounded elements.
ThemeData _buildTheme(Brightness b) {
  final scheme = ColorScheme.fromSeed(seedColor: BRAND, brightness: b);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
    cardTheme: CardThemeData(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withOpacity(0.35),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: scheme.primaryContainer,
      backgroundColor: scheme.surface,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurface),
      ),
    ),
  );
}

/// Handles session, shows Auth or Home.
class _Root extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDark;
  const _Root({super.key, required this.onToggleTheme, required this.isDark});

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  String? _token, _userId;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final sp = await SharedPreferences.getInstance();
    setState(() {
      _token = sp.getString('token');
      _userId = sp.getString('userId');
    });
  }

  Future<void> _saveSession(String token, String userId) async {
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
    return GradientScaffold(
      isDark: widget.isDark,
      onToggleTheme: widget.onToggleTheme,
      child: (_token == null || _userId == null)
          ? AuthScreen(onLogin: _saveSession)
          : HomeScreen(
              token: _token!,
              userId: _userId!,
              onLogout: _logout,
            ),
    );
  }
}

/// ============ API CLIENT (Web -> localhost:4000) ============
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

/// ============ Beautiful gradient scaffold ============
class GradientScaffold extends StatelessWidget {
  final Widget child;
  final VoidCallback? onToggleTheme;
  final bool isDark;
  const GradientScaffold({
    super.key,
    required this.child,
    this.onToggleTheme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [BRAND, BRAND_DARK],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: _GlassBar(
                left: Row(
                  children: [
                    const Icon(Icons.favorite, color: Colors.white),
                    const SizedBox(width: 8),
                    const Text('MUUD Health',
                        style: TextStyle(
                          color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800,
                        )),
                  ],
                ),
                right: Row(
                  children: [
                    if (onToggleTheme != null)
                      Tooltip(
                        message: isDark ? 'Switch to Light' : 'Switch to Dark',
                        child: _GlassIconButton(
                          icon: isDark ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                          onTap: onToggleTheme!,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: Stack(
          children: [
            // Soft accent circles for depth
            Positioned(
              top: -40,
              right: -30,
              child: _AccentBlob(size: 160, color: Colors.white.withOpacity(0.08)),
            ),
            Positioned(
              bottom: -60,
              left: -40,
              child: _AccentBlob(size: 220, color: ACCENT.withOpacity(0.12)),
            ),
            // Content surface
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: scheme.surface.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: child,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassBar extends StatelessWidget {
  final Widget left;
  final Widget right;
  const _GlassBar({required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [left, right],
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 24,
      child: Container(
        height: 36,
        width: 36,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.16),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}

class _AccentBlob extends StatelessWidget {
  final double size;
  final Color color;
  const _AccentBlob({required this.size, required this.color});
  @override
  Widget build(BuildContext context) =>
      Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

/// ============ AUTH SCREEN (card over gradient) ============
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

    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header section with gradient
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [BRAND, BRAND_DARK],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Icon(
                          showRegister ? Icons.person_add_rounded : Icons.login_rounded,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        showRegister ? 'Create Account' : 'Welcome Back',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        showRegister 
                            ? 'Join our wellness community'
                            : 'Sign in to continue your journey',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Form section
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      // Email field with enhanced styling
                      _ModernTextField(
                        controller: email,
                        label: 'Email Address',
                        hint: 'Enter your email',
                        icon: Icons.alternate_email_rounded,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 20),
                      
                      // Name field (only for registration)
                      if (showRegister) ...[
                        _ModernTextField(
                          controller: name,
                          label: 'Full Name',
                          hint: 'Enter your full name',
                          icon: Icons.person_outline_rounded,
                        ),
                        const SizedBox(height: 20),
                      ],
                      
                      // Password field with enhanced styling
                      _ModernTextField(
                        controller: password,
                        label: 'Password',
                        hint: 'Enter your password',
                        icon: Icons.lock_outline_rounded,
                        obscureText: true,
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Error message
                      if (error != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: scheme.errorContainer,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: scheme.error.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline_rounded, color: scheme.error, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  error!,
                                  style: TextStyle(
                                    color: scheme.onErrorContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      // Submit button with enhanced styling
                      Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [BRAND, BRAND_DARK],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: BRAND.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: busy ? null : _submit,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (busy)
                                    const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  else
                                    const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 24),
                                  const SizedBox(width: 12),
                                  Text(
                                    busy 
                                        ? 'Please wait...'
                                        : (showRegister ? 'Create Account' : 'Sign In'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Toggle between login/register
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => showRegister = false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: !showRegister ? BRAND : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Sign In',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: !showRegister ? Colors.white : scheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => showRegister = true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: showRegister ? BRAND : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Register',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: showRegister ? Colors.white : scheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Additional info
                      Text(
                        'By continuing, you agree to our Terms of Service and Privacy Policy',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Modern text field component with enhanced styling
class _ModernTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType keyboardType;

  const _ModernTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
  });

  @override
  State<_ModernTextField> createState() => _ModernTextFieldState();
}

class _ModernTextFieldState extends State<_ModernTextField> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: _isFocused ? [
              BoxShadow(
                color: BRAND.withOpacity(0.2 * _animation.value),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ] : [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: widget.controller,
            obscureText: widget.obscureText,
            keyboardType: widget.keyboardType,
            onTap: () {
              setState(() => _isFocused = true);
              _animationController.forward();
            },
            onSubmitted: (_) {
              setState(() => _isFocused = false);
              _animationController.reverse();
            },
            onEditingComplete: () {
              setState(() => _isFocused = false);
              _animationController.reverse();
            },
            decoration: InputDecoration(
              labelText: widget.label,
              hintText: widget.hint,
              prefixIcon: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _isFocused 
                      ? BRAND.withOpacity(0.1 + (0.1 * _animation.value))
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  widget.icon,
                  color: _isFocused ? BRAND : scheme.onSurfaceVariant,
                  size: 20,
                ),
              ),
              filled: true,
              fillColor: scheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: BRAND,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              labelStyle: TextStyle(
                color: _isFocused ? BRAND : scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Nice section header used on cards
class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _SectionHeader({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [BRAND, BRAND_DARK],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (subtitle != null)
          Text(
            subtitle!,
            style: TextStyle(
              color: scheme.onPrimary.withOpacity(0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
        Text(
          title,
          style: TextStyle(
            color: scheme.onPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ]),
    );
  }
}

/// ============ HOME (tabs) ============
class HomeScreen extends StatefulWidget {
  final String token;
  final String userId;
  final VoidCallback onLogout;
  const HomeScreen({
    super.key,
    required this.token,
    required this.userId,
    required this.onLogout,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pages = [
      JournalScreen(token: widget.token, userId: widget.userId),
      ContactsScreen(token: widget.token, userId: widget.userId),
    ];
    
    return Column(
      children: [
        // Enhanced top bar with better styling
        Container(
          margin: const EdgeInsets.fromLTRB(8, 8, 8, 12),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                scheme.primaryContainer.withOpacity(0.3),
                scheme.secondaryContainer.withOpacity(0.2),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: scheme.outlineVariant.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [BRAND, BRAND_DARK],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back!',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                    Text(
                      'Ready to continue your wellness journey?',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: widget.onLogout,
                  icon: Icon(
                    Icons.logout_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                  tooltip: 'Logout',
                ),
              ),
            ],
          ),
        ),
        
        // Main content area with enhanced animations
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.1, 0.0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeInOut,
                )),
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              );
            },
            child: Container(
              key: ValueKey<int>(index),
              child: pages[index],
            ),
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Enhanced navigation bar
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(
              color: scheme.outlineVariant.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (i) => setState(() => index = i),
            backgroundColor: Colors.transparent,
            elevation: 0,
            indicatorColor: scheme.primaryContainer,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              NavigationDestination(
                icon: Icon(
                  Icons.edit_note_rounded,
                  color: index == 0 ? BRAND : scheme.onSurfaceVariant,
                ),
                selectedIcon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [BRAND, BRAND_DARK],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.edit_note_rounded,
                    color: Colors.white,
                  ),
                ),
                label: 'Journal',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.groups_rounded,
                  color: index == 1 ? BRAND : scheme.onSurfaceVariant,
                ),
                selectedIcon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [BRAND, BRAND_DARK],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.groups_rounded,
                    color: Colors.white,
                  ),
                ),
                label: 'Contacts',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// ============ JOURNAL ============
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
      await Api.createJournal(
          widget.token, widget.userId, text.text.trim(), mood);
      text.clear();
      await _load();
      _snack('Entry saved');
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  String _getRandomPrompt() {
    final prompts = [
      'What made you smile today?',
      'What are you grateful for?',
      'What challenge did you overcome?',
      'How did you take care of yourself today?',
      'What are you looking forward to?',
      'What lesson did you learn today?',
      'What brought you joy today?',
      'How did you grow today?',
      'What are you proud of?',
      'What do you need to let go of?',
    ];
    return prompts[DateTime.now().millisecondsSinceEpoch % prompts.length];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          // Enhanced header with better styling
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [BRAND, BRAND_DARK],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: BRAND.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.edit_note_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Daily Journal',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'How are you feeling today?',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '💭 Take a moment to reflect on your day',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        Card(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                colors: [
                  BRAND.withOpacity(0.03),
                  BRAND_DARK.withOpacity(0.02),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with inspiration
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [BRAND, BRAND_DARK],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.edit_note_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'New Journal Entry',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              _getRandomPrompt(),
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Text input with better styling
                  Container(
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TextField(
                      controller: text,
                      minLines: 3,
                      maxLines: 6,
                      decoration: InputDecoration(
                        hintText: 'How are you feeling today? What\'s on your mind?',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                        hintStyle: TextStyle(
                          color: scheme.onSurfaceVariant.withOpacity(0.7),
                          fontSize: 16,
                        ),
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Mood selection with better layout
                  Row(
                    children: [
                      Icon(
                        Icons.mood_rounded,
                        color: scheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'How is your mood today?',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _MoodChips(
                    value: mood,
                    onChanged: (v) => setState(() => mood = v),
                  ),
                  const SizedBox(height: 20),
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: busy ? null : _submit,
                          icon: Icon(busy ? Icons.hourglass_empty : Icons.save_rounded),
                          label: Text(busy ? 'Saving...' : 'Save Entry'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: busy ? null : () {
                          text.clear();
                          setState(() => mood = 3);
                        },
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Clear'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Journal Statistics
        _JournalStats(entries: entries),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: Text('Recent entries',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 8),
        for (final e in entries)
          _JournalCard(
            text: e['entry_text'] ?? '',
            mood: (e['mood_rating'] ?? 0) as int,
            ts: _parseLocal(e['timestamp']),
          ),
        if (entries.isEmpty)
          _EmptyJournalState(),
      ]),
    );
  }
}

class _EmptyJournalState extends StatelessWidget {
  const _EmptyJournalState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    
    return Container(
      margin: const EdgeInsets.only(top: 40),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            BRAND.withOpacity(0.05),
            BRAND_DARK.withOpacity(0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: BRAND.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [BRAND, BRAND_DARK],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.edit_note_rounded,
              color: Colors.white,
              size: 48,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Start Your Journey',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Your first journal entry is waiting to be written. Take a moment to reflect on your day and begin documenting your thoughts and feelings.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 16,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.tips_and_updates_rounded,
                      color: scheme.onPrimaryContainer,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Tip: Journaling helps track your mental wellness',
                      style: TextStyle(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _JournalStats extends StatelessWidget {
  final List<Map<String, dynamic>> entries;
  const _JournalStats({required this.entries});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    final totalEntries = entries.length;
    final averageMood = entries.isNotEmpty 
        ? entries.map((e) => (e['mood_rating'] ?? 3) as int).reduce((a, b) => a + b) / entries.length
        : 3.0;
    
    final thisWeek = _getThisWeekEntries();
    final streakDays = _calculateStreak();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [BRAND, BRAND_DARK],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.analytics_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Journal Insights',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Track your mental wellness journey',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'Total Entries',
                    value: '$totalEntries',
                    subtitle: 'Journal entries',
                    icon: Icons.book_rounded,
                    color: BRAND,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    title: 'Average Mood',
                    value: '${averageMood.toStringAsFixed(1)}/5',
                    subtitle: _getMoodDescription(averageMood),
                    icon: Icons.mood_rounded,
                    color: _getMoodColor(averageMood),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'This Week',
                    value: '${thisWeek.length}',
                    subtitle: 'entries',
                    icon: Icons.calendar_view_week_rounded,
                    color: ACCENT,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    title: 'Streak',
                    value: '$streakDays',
                    subtitle: streakDays == 1 ? 'day' : 'days',
                    icon: Icons.local_fire_department_rounded,
                    color: const Color(0xFFFF6B35),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getThisWeekEntries() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));
    
    return entries.where((entry) {
      final timestamp = _parseLocal(entry['timestamp']);
      if (timestamp == null) return false;
      return timestamp.isAfter(weekStart) && timestamp.isBefore(weekEnd);
    }).toList();
  }

  int _calculateStreak() {
    if (entries.isEmpty) return 0;
    
    final sortedEntries = List<Map<String, dynamic>>.from(entries);
    sortedEntries.sort((a, b) {
      final aTime = _parseLocal(a['timestamp']);
      final bTime = _parseLocal(b['timestamp']);
      if (aTime == null || bTime == null) return 0;
      return bTime.compareTo(aTime);
    });
    
    int streak = 0;
    DateTime? lastDate;
    
    for (final entry in sortedEntries) {
      final entryDate = _parseLocal(entry['timestamp']);
      if (entryDate == null) continue;
      
      final entryDay = DateTime(entryDate.year, entryDate.month, entryDate.day);
      final today = DateTime.now();
      final todayDay = DateTime(today.year, today.month, today.day);
      
      if (lastDate == null) {
        // First entry
        if (entryDay == todayDay || entryDay == todayDay.subtract(const Duration(days: 1))) {
          streak = 1;
          lastDate = entryDay;
        }
      } else {
        // Check if this entry is consecutive
        if (entryDay == lastDate.subtract(const Duration(days: 1))) {
          streak++;
          lastDate = entryDay;
        } else if (entryDay != lastDate) {
          break;
        }
      }
    }
    
    return streak;
  }

  String _getMoodDescription(double mood) {
    if (mood <= 2) return 'Keep going!';
    if (mood <= 3) return 'Stable';
    if (mood <= 4) return 'Positive';
    return 'Excellent!';
  }

  Color _getMoodColor(double mood) {
    if (mood <= 2) return const Color(0xFFE57373);
    if (mood <= 3) return const Color(0xFF90A4AE);
    if (mood <= 4) return const Color(0xFF81C784);
    return const Color(0xFF4CAF50);
  }

  DateTime? _parseLocal(dynamic s) {
    if (s is String && s.isNotEmpty) {
      try {
        return DateTime.parse(s).toLocal();
      } catch (_) {}
    }
    return null;
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  
  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: color,
                size: 20,
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoodChips extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _MoodChips({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final moods = [
      {'value': 1, 'emoji': '😞', 'label': 'Very Low', 'color': const Color(0xFFE57373)},
      {'value': 2, 'emoji': '🙁', 'label': 'Low', 'color': const Color(0xFFFFB74D)},
      {'value': 3, 'emoji': '😐', 'label': 'Neutral', 'color': const Color(0xFF90A4AE)},
      {'value': 4, 'emoji': '🙂', 'label': 'Good', 'color': const Color(0xFF81C784)},
      {'value': 5, 'emoji': '😄', 'label': 'Excellent', 'color': const Color(0xFF4CAF50)},
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: moods.map((mood) {
          final isSelected = value == mood['value'];
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(mood['value'] as int),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                decoration: BoxDecoration(
                  color: isSelected ? mood['color'] as Color : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isSelected ? [
                    BoxShadow(
                      color: (mood['color'] as Color).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ] : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      mood['emoji'] as String,
                      style: TextStyle(
                        fontSize: isSelected ? 24 : 20,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${mood['value']}',
                      style: TextStyle(
                        color: isSelected ? Colors.white : scheme.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      mood['label'] as String,
                      style: TextStyle(
                        color: isSelected ? Colors.white : scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
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
    final moodData = _getMoodData(mood);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: [
              moodData['color'].withOpacity(0.05),
              moodData['color'].withOpacity(0.02),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with mood and timestamp
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: moodData['color'],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          moodData['emoji'],
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          moodData['label'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$mood/5',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (ts != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _formatDate(ts!),
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // Journal text
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Footer with actions and additional info
              Row(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 16,
                    color: scheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    ts != null ? _formatTime(ts!) : '',
                    style: TextStyle(
                      color: scheme.outline,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  // Mood trend indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: moodData['color'].withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      moodData['description'],
                      style: TextStyle(
                        color: moodData['color'],
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showEditDialog(context),
                      icon: Icon(Icons.edit_rounded, size: 16),
                      label: const Text('Edit'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        side: BorderSide(color: scheme.outline.withOpacity(0.3)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _shareEntry(context),
                      icon: Icon(Icons.share_rounded, size: 16),
                      label: const Text('Share'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        side: BorderSide(color: scheme.outline.withOpacity(0.3)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showDeleteDialog(context),
                      icon: Icon(Icons.delete_rounded, size: 16, color: scheme.error),
                      label: Text('Delete', style: TextStyle(color: scheme.error)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        side: BorderSide(color: scheme.error.withOpacity(0.3)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _getMoodData(int mood) {
    switch (mood) {
      case 1:
        return {
          'emoji': '😞',
          'label': 'Very Low',
          'description': 'Needs support',
          'color': const Color(0xFFE57373),
        };
      case 2:
        return {
          'emoji': '🙁',
          'label': 'Low',
          'description': 'Challenging day',
          'color': const Color(0xFFFFB74D),
        };
      case 3:
        return {
          'emoji': '😐',
          'label': 'Neutral',
          'description': 'Stable mood',
          'color': const Color(0xFF90A4AE),
        };
      case 4:
        return {
          'emoji': '🙂',
          'label': 'Good',
          'description': 'Feeling positive',
          'color': const Color(0xFF81C784),
        };
      case 5:
        return {
          'emoji': '😄',
          'label': 'Excellent',
          'description': 'Amazing day',
          'color': const Color(0xFF4CAF50),
        };
      default:
        return {
          'emoji': '😐',
          'label': 'Unknown',
          'description': 'No data',
          'color': const Color(0xFF90A4AE),
        };
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final entryDate = DateTime(date.year, date.month, date.day);

    if (entryDate == today) {
      return 'Today';
    } else if (entryDate == yesterday) {
      return 'Yesterday';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatTime(DateTime date) {
    return '${_pad2(date.hour)}:${_pad2(date.minute)}';
  }

  void _showEditDialog(BuildContext context) {
    // For now, show a placeholder dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Entry'),
        content: const Text('Edit functionality will be implemented in a future update.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _shareEntry(BuildContext context) {
    // For now, show a placeholder dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share Entry'),
        content: const Text('Share functionality will be implemented in a future update.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text('Are you sure you want to delete this journal entry? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // For now, show a placeholder message
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Delete functionality will be implemented in a future update.')),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

/// ============ CONTACTS ============
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
      await Api.addContact(
          widget.token, widget.userId, name.text.trim(), email.text.trim());
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

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          // Enhanced header with better styling
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [BRAND, BRAND_DARK],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: BRAND.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.groups_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Support Circle',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Your trusted contacts',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '🤝 Build your network of support',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // Enhanced add contact form
          Card(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(
                  colors: [
                    ACCENT.withOpacity(0.05),
                    ACCENT.withOpacity(0.02),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Form header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [ACCENT, Color(0xFF00C4B7)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.person_add_alt_1_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Add New Contact',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'Expand your support network',
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Form fields with modern styling
                    Row(
                      children: [
                        Expanded(
                          child: _ModernTextField(
                            controller: name,
                            label: 'Full Name',
                            hint: 'Enter full name',
                            icon: Icons.person_outline_rounded,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _ModernTextField(
                            controller: email,
                            label: 'Email Address',
                            hint: 'Enter email address',
                            icon: Icons.alternate_email_rounded,
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Submit button with enhanced styling
                    Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [ACCENT, Color(0xFF00C4B7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: ACCENT.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: busy ? null : _submit,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (busy)
                                  const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                else
                                  const Icon(Icons.person_add_rounded, color: Colors.white, size: 24),
                                const SizedBox(width: 12),
                                Text(
                                  busy ? 'Adding...' : 'Add Contact',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Contacts list header
          Row(
            children: [
              Icon(
                Icons.people_rounded,
                color: scheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Your Contacts',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${contacts.length}',
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Enhanced contacts list
          if (contacts.isNotEmpty)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: contacts.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final contact = contacts[index];
                return _ContactCard(contact: contact);
              },
            )
          else
            _EmptyContactsState(),
        ],
      ),
    );
  }
}

/// Enhanced contact card widget
class _ContactCard extends StatelessWidget {
  final Map<String, dynamic> contact;
  
  const _ContactCard({required this.contact});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = contact['contact_name'] ?? 'Unknown';
    final email = contact['contact_email'] ?? '';
    final createdAt = _parseLocal(contact['created_at']);
    
    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              ACCENT.withOpacity(0.03),
              ACCENT.withOpacity(0.01),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Avatar with gradient background
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [ACCENT, Color(0xFF00C4B7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              
              // Contact info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.email_outlined,
                          size: 16,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            email,
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (createdAt != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 16,
                            color: scheme.outline,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Added ${_formatDate(createdAt)}',
                            style: TextStyle(
                              color: scheme.outline,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              
              // Action buttons
              Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: () => _showContactOptions(context),
                      icon: Icon(
                        Icons.more_vert_rounded,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContactOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.email_rounded),
              title: const Text('Send Email'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement email functionality
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Edit Contact'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement edit functionality
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_rounded, color: Theme.of(context).colorScheme.error),
              title: Text('Delete Contact', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement delete functionality
              },
            ),
          ],
        ),
      ),
    );
  }

  DateTime? _parseLocal(dynamic s) {
    if (s is String && s.isNotEmpty) {
      try {
        return DateTime.parse(s).toLocal();
      } catch (_) {}
    }
    return null;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final entryDate = DateTime(date.year, date.month, date.day);

    if (entryDate == today) {
      return 'today';
    } else if (entryDate == yesterday) {
      return 'yesterday';
    } else {
      return 'on ${date.day}/${date.month}/${date.year}';
    }
  }
}

/// Empty state for contacts
class _EmptyContactsState extends StatelessWidget {
  const _EmptyContactsState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    
    return Container(
      margin: const EdgeInsets.only(top: 40),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ACCENT.withOpacity(0.05),
            ACCENT.withOpacity(0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: ACCENT.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [ACCENT, Color(0xFF00C4B7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.people_outline_rounded,
              color: Colors.white,
              size: 48,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Build Your Support Network',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Add trusted contacts who can support you on your wellness journey. These could be family, friends, or healthcare professionals.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 16,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: ACCENT.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '💡 Tip: Start with 2-3 close family members or friends',
              style: TextStyle(
                color: ACCENT,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ==== utils ====
DateTime? _parseLocal(dynamic s) {
  if (s is String && s.isNotEmpty) {
    try {
      return DateTime.parse(s).toLocal();
    } catch (_) {}
  }
  return null;
}

String _pad2(int v) => v.toString().padLeft(2, '0');
String _format(DateTime d) =>
    '${d.year}-${_pad2(d.month)}-${_pad2(d.day)}  ${_pad2(d.hour)}:${_pad2(d.minute)}';
String _formatMaybe(DateTime? d) => d == null ? '' : _format(d);
