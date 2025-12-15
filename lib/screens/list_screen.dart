import 'package:flutter/material.dart';
import 'editor_screen.dart';

class RollChartListScreen extends StatefulWidget {
  const RollChartListScreen({super.key});

  @override
  State<RollChartListScreen> createState() => _RollChartListScreenState();
}

class _RollChartListScreenState extends State<RollChartListScreen> {
  final List<String> charts = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ROLLCHART-BLDR')),
      body: charts.isEmpty
          ? const Center(child: Text('No roll charts yet.\nTap New.', textAlign: TextAlign.center))
          : ListView.separated(
              itemCount: charts.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final name = charts[i];
                return ListTile(
                  title: Text(name),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => RollChartEditorScreen(chartName: name)),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final ctrl = TextEditingController(text: 'New Roll Chart');
          final ok = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Create roll chart'),
              content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Name')),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create')),
              ],
            ),
          );
          if (ok == true) {
            setState(() => charts.add(ctrl.text.trim().isEmpty ? 'Untitled' : ctrl.text.trim()));
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('New'),
      ),
    );
  }
}