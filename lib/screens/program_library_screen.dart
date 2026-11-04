import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/program_registry.dart';
import '../data/test_student.dart';
import '../services/program_check_service.dart';

class ProgramLibraryScreen extends StatefulWidget {
  const ProgramLibraryScreen({super.key});
  @override
  State<ProgramLibraryScreen> createState() => _ProgramLibraryScreenState();
}

class _ProgramLibraryScreenState extends State<ProgramLibraryScreen> {
  final _search = TextEditingController();
  late final Future<List<Map<String, dynamic>>> _pages = rootBundle
      .loadString('assets/programs/index.json')
      .then(
        (text) => (jsonDecode(text) as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList(),
      );
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _view(Map<String, dynamic> page) => Navigator.of(context).push(
    MaterialPageRoute(
      settings: const RouteSettings(name: 'ProgramSourceScreen'),
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text('${page['name']} · p. ${page['page']}')),
        body: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(10),
              child: Text(
                'Pinch or use your trackpad to zoom. Source: Benedict College Catalogue 2025–2026.',
              ),
            ),
            Expanded(
              child: InteractiveViewer(
                minScale: .5,
                maxScale: 5,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Image.asset(
                        page['image'] as String,
                        semanticLabel: 'Catalog source page ${page['page']}',
                      ),
                      if (page['continuationPage'] != null)
                        Image.asset(
                          'assets/programs/page-${page['continuationPage']}.jpg',
                          semanticLabel: 'Continuation page',
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Programs of Study')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: FutureBuilder(
          future: _pages,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text('Program library could not load. Please retry.'),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final pages =
                snapshot.data!
                    .where(
                      (p) => '${p['name']} ${p['text']} ${p['page']}'
                          .toLowerCase()
                          .contains(_search.text.toLowerCase()),
                    )
                    .toList()
                  ..sort((a, b) {
                    final ac = a['name'] == activeStudent.major,
                        bc = b['name'] == activeStudent.major;
                    return ac == bc
                        ? '${a['name']}${a['page']}'.compareTo(
                            '${b['name']}${b['page']}',
                          )
                        : ac
                        ? -1
                        : 1;
                  });
            final checks = ProgramCheckService.checkAll();
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Explore your program',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Your major: ${activeStudent.major} · Catalog ${activeStudent.catalogYear}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText:
                        'Search programs, concentrations or course codes',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${snapshot.data!.length} source entries · ${checks.length} app mappings checked automatically',
                ),
                const Text(
                  'Catalog reference pages are available for all listed programs. Only mapped programs power the planner; a source page alone does not validate degree rules.',
                ),
                ExpansionTile(
                  initiallyExpanded: false,
                  title: const Text('All program mapping checks'),
                  children: [
                    for (final c in checks)
                      ListTile(
                        leading: Icon(
                          c.errors.isEmpty
                              ? Icons.fact_check_outlined
                              : Icons.warning_amber,
                        ),
                        title: Text(
                          '${c.major}: ${c.errors.isEmpty ? 'structural checks passed' : 'mapping needs repair'}',
                        ),
                        subtitle: Text([...c.errors, ...c.review].join('\n')),
                      ),
                  ],
                ),
                for (final page in pages)
                  Card(
                    child: ListTile(
                      leading: Icon(
                        page['name'] == activeStudent.major
                            ? Icons.school
                            : Icons.menu_book_outlined,
                      ),
                      title: Text(
                        '${page['name']}${page['concentration'] != null ? ' · ${page['concentration']}' : ''}',
                      ),
                      subtitle: Text(
                        '2025–2026 · Catalog page ${page['page']}\n${programMappings.containsKey(page['name']) ? 'App mapping: ${programMappings[page['name']]!.catalogYear}' : 'Reference only · scheduling rules not mapped'}',
                      ),
                      trailing: const Icon(Icons.open_in_full),
                      onTap: () => _view(page),
                    ),
                  ),
                if (pages.isEmpty)
                  const Text(
                    'No matching programs. Try another name or course code.',
                  ),
              ],
            );
          },
        ),
      ),
    ),
  );
}
