import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'modules.dart';
import 'screens.dart';

void main() => runApp(const YaApp());

class YaApp extends StatelessWidget {
  const YaApp({super.key});

  @override
  Widget build(BuildContext context) {
    const paper = Color(0xFFF6F4EF);
    return MaterialApp(
      title: 'YA CRM',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E)),
        scaffoldBackgroundColor: paper,
        appBarTheme: const AppBarTheme(
            backgroundColor: paper, surfaceTintColor: Colors.transparent, centerTitle: false),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.black.withValues(alpha: .07)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      home: const Boot(),
    );
  }
}

class Boot extends StatelessWidget {
  const Boot({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: Api.restore(),
      builder: (_, snap) {
        if (!snap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        return snap.data! ? const HomeScreen() : const LoginScreen();
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _user = TextEditingController(), _pass = TextEditingController();
  bool _busy = false, _hide = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) => _user.text = p.getString('lastUser') ?? '');
  }

  Future<void> _login() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Api.login(_user.text.trim(), _pass.text);
      (await SharedPreferences.getInstance()).setString('lastUser', _user.text.trim());
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('YA CRM', style: t.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700)),
                Text('Sign in with your email, username or employee ID',
                    style: t.textTheme.bodyMedium?.copyWith(color: Colors.black54)),
                const SizedBox(height: 32),
                TextField(
                    controller: _user,
                    autocorrect: false,
                    decoration: const InputDecoration(labelText: 'Email / Username / Employee ID')),
                const SizedBox(height: 14),
                TextField(
                  controller: _pass,
                  obscureText: _hide,
                  onSubmitted: (_) => _login(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                        icon: Icon(_hide ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _hide = !_hide)),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_error!, style: TextStyle(color: t.colorScheme.error)),
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _busy ? null : _login,
                    child: _busy
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Sign in'),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Api.session!;
    final t = Theme.of(context);
    final mods = kModules.where((m) => Api.access(m.key) != 'NONE').toList();
    return Scaffold(
      appBar: AppBar(title: const Text('YA CRM'), actions: [
        IconButton(
          tooltip: 'Sign out',
          icon: const Icon(Icons.logout),
          onPressed: () async {
            await Api.logout();
            if (context.mounted) {
              Navigator.pushAndRemoveUntil(
                  context, MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
            }
          },
        ),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('Hello, ${s.name}', style: t.textTheme.headlineSmall),
        const SizedBox(height: 2),
        Text(s.role.replaceAll('_', ' ').toUpperCase(),
            style: t.textTheme.labelSmall?.copyWith(letterSpacing: 1.2, color: t.colorScheme.primary)),
        const SizedBox(height: 16),
        if (mods.isEmpty)
          const Padding(padding: EdgeInsets.all(24), child: Text('No modules are enabled for your account.'))
        else
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.3,
            children: [for (final m in mods) _ModuleTile(m)],
          ),
      ]),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile(this.m);
  final Module m;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => switch (m.custom) {
              'portal' => const PortalScreen(),
              'dashboard' => const DashboardScreen(),
              _ => ResourceScreen(m),
            },
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Icon(m.icon, size: 28, color: Theme.of(context).colorScheme.primary),
            Text(m.title, style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}
