import 'package:flutter/material.dart';
import '../storage/local_store.dart';
import 'editor_screen.dart';

class RollchartLibraryScreen extends StatefulWidget {
  const RollchartLibraryScreen({super.key});

  @override
  State<RollchartLibraryScreen> createState() => _RollchartLibraryScreenState();
}

class _RollchartLibraryScreenState extends State<RollchartLibraryScreen> {
  bool loading = true;
  List<RollchartMeta> charts = [];

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    setState(() => loading = true);
    final list = await LocalStore.listCharts();
    if (!mounted) return;
    setState(() {
      charts = list;
      loading = false;
    });
  }

  Future<String?> promptName(String title, {String initial = ''}) async {
    final c = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Rollchart name'),
          onSubmitted: (_) => Navigator.pop(context, c.text.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('OK')),
        ],
      ),
    );
  }

  bool nameExists(String name) =>
      charts.any((m) => m.name.toLowerCase() == name.toLowerCase());

  Future<void> createNew() async {
    final name = await promptName('New rollchart', initial: 'New Rollchart');
    if (name == null || name.isEmpty) return;
    if (nameExists(name)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('That name already exists.')));
      return;
    }
    await LocalStore.saveChart(chartName: name, isDone: false, rows: []);
    await refresh();
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => RollChartEditorScreen(chartName: name)))
        .then((_) => refresh());
  }

  void openChart(String name) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => RollChartEditorScreen(chartName: name)))
        .then((_) => refresh());
  }

  Future<void> renameChart(RollchartMeta m) async {
    final newName = await promptName('Rename rollchart', initial: m.name);
    if (newName == null || newName.isEmpty || newName == m.name) return;
    if (nameExists(newName)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('That name already exists.')));
      return;
    }
    await LocalStore.renameChart(m.name, newName);
    await refresh();
  }

  Future<void> duplicateChart(RollchartMeta m) async {
    final newName = await promptName('Duplicate as…', initial: '${m.name} copy');
    if (newName == null || newName.isEmpty) return;
    if (nameExists(newName)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('That name already exists.')));
      return;
    }
    await LocalStore.duplicateChart(m.name, newName);
    await refresh();
    if (!mounted) return;
    openChart(newName);
  }

  Future<void> deleteChart(RollchartMeta m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete rollchart?'),
        content: Text('Delete "${m.name}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await LocalStore.deleteChart(m.name);
      await refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rollchart Library'),
        actions: [
          IconButton(onPressed: refresh, tooltip: 'Refresh', icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: createNew,
        icon: const Icon(Icons.add),
        label: const Text('New'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : charts.isEmpty
              ? const Center(child: Text('No rollcharts yet.\nTap New to start one.', textAlign: TextAlign.center))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: charts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final m = charts[i];
                    return Card(
                      child: ListTile(
                        title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text(m.isDone ? 'DONE (locked)' : 'In Progress'),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'open') openChart(m.name);
                            if (v == 'rename') renameChart(m);
                            if (v == 'dup') duplicateChart(m);
                            if (v == 'del') deleteChart(m);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'open', child: Text('Open')),
                            PopupMenuItem(value: 'rename', child: Text('Rename')),
                            PopupMenuItem(value: 'dup', child: Text('Duplicate')),
                            PopupMenuDivider(),
                            PopupMenuItem(value: 'del', child: Text('Delete')),
                          ],
                        ),
                        onTap: () => openChart(m.name),
                      ),
                    );
                  },
                ),
    );
  }
}
