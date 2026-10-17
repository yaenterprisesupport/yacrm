import 'package:flutter/material.dart';
import 'api.dart';
import 'modules.dart';

String pickVal(Map<String, dynamic> r, List<String> keys) {
  for (final k in keys) {
    final v = r[k];
    if (v != null && v is! Map && v is! List && '$v'.isNotEmpty) return '$v';
  }
  return '';
}

String label(String k) => k
    .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
    .replaceAll('_', ' ');

String shorten(Object? v) {
  final s = '$v';
  return s.length > 160 ? '${s.substring(0, 160)}…' : s;
}

String money(String k, String v) {
  final n = num.tryParse(v);
  final isMoney = RegExp(r'price|total|amount|revenue|value|salary|pay|ctc', caseSensitive: false).hasMatch(k);
  if (n == null || !isMoney) return v;
  return '₹${n.toStringAsFixed(n % 1 == 0 ? 0 : 2)}';
}

void toast(BuildContext c, String m) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

// ───────────────────────── Generic list + detail ─────────────────────────

class ResourceScreen extends StatefulWidget {
  const ResourceScreen(this.m, {super.key});
  final Module m;
  @override
  State<ResourceScreen> createState() => _ResourceScreenState();
}

class _ResourceScreenState extends State<ResourceScreen> {
  List<Map<String, dynamic>> _all = [];
  bool _loading = true;
  String? _error;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = Api.session!;
      final d = await Api.get(widget.m.path!, q: widget.m.mine ? {'employeeId': s.id} : null);
      var rows = Api.asList(d);
      if (widget.m.mine) {
        rows = rows.where((r) => r['employeeId'] == null || '${r['employeeId']}' == s.id).toList();
      }
      if (mounted) setState(() => _all = rows);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.m;
    final canWrite = Api.access(m.key) == 'WRITE';
    final q = _q.toLowerCase();
    final rows = q.isEmpty
        ? _all
        : _all
            .where((r) => r.values.any((v) =>
                ((v is String && v.length < 200) || v is num) && '$v'.toLowerCase().contains(q)))
            .toList();
    return Scaffold(
      appBar: AppBar(title: Text(m.title)),
      floatingActionButton: canWrite && m.fields.isNotEmpty
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('New'),
              onPressed: () async {
                final ok = await Navigator.push<bool>(
                    context, MaterialPageRoute(builder: (_) => FormScreen(m)));
                if (ok == true) _load();
              })
          : null,
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            decoration: const InputDecoration(
                hintText: 'Search', prefixIcon: Icon(Icons.search), isDense: true),
            onChanged: (v) => setState(() => _q = v),
          ),
        ),
        Expanded(child: _body(rows)),
      ]),
    );
  }

  Widget _body(List<Map<String, dynamic>> rows) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ]),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: rows.isEmpty
          ? ListView(children: const [SizedBox(height: 120), Center(child: Text('Nothing here yet'))])
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _tile(rows[i]),
            ),
    );
  }

  Widget _tile(Map<String, dynamic> r) {
    final m = widget.m;
    final title = pickVal(r, m.titleKeys);
    final sub = m.subKeys.map((k) => pickVal(r, [k])).where((s) => s.isNotEmpty).join(' · ');
    var trail = '';
    for (final k in m.trailKeys) {
      final v = pickVal(r, [k]);
      if (v.isNotEmpty) {
        trail = money(k, v);
        break;
      }
    }
    return Card(
      child: ListTile(
        title: Text(title.isEmpty ? '#${pickVal(r, ['id'])}' : title,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: sub.isEmpty ? null : Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: trail.isEmpty
            ? null
            : Text(trail, style: const TextStyle(fontWeight: FontWeight.w600)),
        onTap: () => _detail(r),
      ),
    );
  }

  void _detail(Map<String, dynamic> r) {
    final m = widget.m;
    final canWrite = Api.access(m.key) == 'WRITE';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .7,
        maxChildSize: .95,
        builder: (_, sc) => ListView(
          controller: sc,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            for (final e in r.entries)
              if (e.value != null &&
                  !e.key.toLowerCase().contains('password') &&
                  !'${e.value}'.startsWith('data:'))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(label(e.key), style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    Text(shorten(e.value)),
                  ]),
                ),
            if (canWrite && m.actions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Wrap(spacing: 8, children: [
                  for (final a in m.actions)
                    FilledButton.tonal(onPressed: () => _run(ctx, a, r), child: Text(a.label)),
                ]),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _run(BuildContext ctx, RowAction a, Map<String, dynamic> r) async {
    Navigator.pop(ctx);
    try {
      await Api.send(a.method, a.path.replaceAll('{id}', '${r['id']}'), body: a.body);
      if (mounted) toast(context, '${a.label} done');
      _load();
    } catch (e) {
      if (mounted) toast(context, '$e');
    }
  }
}

// ───────────────────────── Generic create form ─────────────────────────

class FormScreen extends StatefulWidget {
  const FormScreen(this.m, {super.key});
  final Module m;
  @override
  State<FormScreen> createState() => _FormScreenState();
}

class _FormScreenState extends State<FormScreen> {
  final _key = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _c = {
    for (final f in widget.m.fields) f.key: TextEditingController()
  };
  bool _busy = false;

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _busy = true);
    final s = Api.session!;
    final body = <String, dynamic>{for (final e in _c.entries) e.key: e.value.text.trim()};
    if (widget.m.mine) {
      body['employeeId'] = s.id;
      body['employeeName'] = s.name;
    }
    try {
      await Api.post(widget.m.path!, body);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        toast(context, '$e');
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('New · ${widget.m.title}')),
      body: Form(
        key: _key,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          for (final f in widget.m.fields)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: TextFormField(
                controller: _c[f.key],
                decoration: InputDecoration(labelText: f.label + (f.required ? ' *' : '')),
                readOnly: f.type == FType.date,
                maxLines: f.type == FType.multiline ? 3 : 1,
                keyboardType: switch (f.type) {
                  FType.email => TextInputType.emailAddress,
                  FType.phone => TextInputType.phone,
                  FType.multiline => TextInputType.multiline,
                  _ => TextInputType.text,
                },
                validator: f.required
                    ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
                    : null,
                onTap: f.type == FType.date
                    ? () async {
                        final d = await showDatePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                            initialDate: DateTime.now());
                        if (d != null) _c[f.key]!.text = d.toIso8601String().substring(0, 10);
                      }
                    : null,
              ),
            ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ]),
      ),
    );
  }
}

// ───────────────────────── Employee portal (punch clock) ─────────────────────────

const _inKeys = ['checkIn', 'checkInTime', 'check_in', 'punchIn', 'inTime'];
const _outKeys = ['checkOut', 'checkOutTime', 'check_out', 'punchOut', 'outTime'];

class PortalScreen extends StatefulWidget {
  const PortalScreen({super.key});
  @override
  State<PortalScreen> createState() => _PortalScreenState();
}

class _PortalScreenState extends State<PortalScreen> {
  List<Map<String, dynamic>> _today = [];
  bool _in = false, _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = Api.session!;
    try {
      final d = await Api.get('/attendance',
          q: {'employeeId': s.id, 'date': DateTime.now().toIso8601String().substring(0, 10)});
      final rows = Api.asList(d);
      if (mounted) {
        setState(() {
          _today = rows;
          _in = rows.any((r) => pickVal(r, _inKeys).isNotEmpty && pickVal(r, _outKeys).isEmpty);
        });
      }
    } catch (_) {}
  }

  Future<void> _punch() async {
    setState(() => _busy = true);
    try {
      await Api.post('/attendance/punch',
          {'employeeId': Api.session!.id, 'action': _in ? 'check-out' : 'check-in'});
      if (mounted) toast(context, _in ? 'Punched out' : 'Punched in');
      await _load();
    } catch (e) {
      if (mounted) toast(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = Api.session!;
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Employee Portal')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Hello, ${s.name}', style: t.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(_in ? 'You are punched in' : 'Ready to start your day',
                    style: t.textTheme.bodyMedium?.copyWith(color: Colors.black54)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: _in ? Colors.red.shade700 : null),
                    onPressed: _busy ? null : _punch,
                    icon: Icon(_in ? Icons.logout : Icons.login),
                    label: Text(_in ? 'Punch out' : 'Punch in'),
                  ),
                ),
              ]),
            ),
          ),
          for (final r in _today)
            Card(
              child: ListTile(
                leading: const Icon(Icons.access_time),
                title: Text('In ${pickVal(r, _inKeys)}   Out ${pickVal(r, _outKeys)}'),
                subtitle: Text(pickVal(r, ['status', 'workingHours'])),
              ),
            ),
          const SizedBox(height: 8),
          for (final m in kPortalModules)
            Card(
              child: ListTile(
                leading: Icon(m.icon),
                title: Text(m.title),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ResourceScreen(m))),
              ),
            ),
        ]),
      ),
    );
  }
}

// ───────────────────────── Dashboard ─────────────────────────

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<dynamic> _f = Api.get('/dashboard/summary');

  void _flat(String p, dynamic v, Map<String, String> out) {
    if (v is Map) {
      v.forEach((k, x) => _flat(p.isEmpty ? '$k' : '$p · $k', x, out));
    } else if (v is num || v is String) {
      out[p] = '$v';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: RefreshIndicator(
        onRefresh: () async => setState(() => _f = Api.get('/dashboard/summary')),
        child: FutureBuilder(
          future: _f,
          builder: (_, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) return Center(child: Text('${snap.error}'));
            final out = <String, String>{};
            _flat('', snap.data, out);
            return GridView.count(
              padding: const EdgeInsets.all(16),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                for (final e in out.entries)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(money(e.key, e.value),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.headlineSmall),
                            const SizedBox(height: 4),
                            Text(label(e.key),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: Colors.black54)),
                          ]),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
