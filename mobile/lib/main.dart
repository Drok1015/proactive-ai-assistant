import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api_client.dart';

void main() => runApp(const ProactiveAiApp());

class ProactiveAiApp extends StatelessWidget {
  const ProactiveAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '主动 AI',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final api = ApiClient();
  int index = 0;

  Future<void> refresh() async => setState(() {});

  @override
  Widget build(BuildContext context) {
    final pages = [TasksPage(api: api, onChanged: refresh), NotificationsPage(api: api), SettingsPage(api: api)];
    return Scaffold(
      appBar: AppBar(title: Text(['主动任务', '通知记录', '设置'][index])),
      body: pages[index],
      floatingActionButton: index == 0
          ? FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => TaskEditor(api: api)));
                refresh();
              },
              icon: const Icon(Icons.add_alert_outlined),
              label: const Text('新建任务'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.auto_awesome), label: '任务'),
          NavigationDestination(icon: Icon(Icons.notifications_outlined), label: '记录'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: '设置'),
        ],
      ),
    );
  }
}

class TasksPage extends StatelessWidget {
  const TasksPage({super.key, required this.api, required this.onChanged});
  final ApiClient api;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: api.tasks(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('无法加载任务：${snapshot.error}'));
        final tasks = snapshot.data!;
        if (tasks.isEmpty) return const Center(child: Text('还没有主动任务。先创建一个天气带伞提醒吧。'));
        return RefreshIndicator(
          onRefresh: onChanged,
          child: ListView.builder(
            itemCount: tasks.length,
            itemBuilder: (context, i) {
              final task = tasks[i];
              final config = Map<String, dynamic>.from(task['config'] as Map);
              final enabled = task['enabled'] as bool;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SwitchListTile(
                  value: enabled,
                  onChanged: (value) async {
                    await api.toggleTask(task, value);
                    await onChanged();
                  },
                  title: Text(task['name'] as String),
                  subtitle: Text('每日 ${task['schedule_time']} 检查 · ${config['start_hour']}:00–${config['end_hour']}:00 任意降雨概率 > ${config['precipitation_probability_gt']}%'),
                  secondary: const Icon(Icons.umbrella_outlined),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key, required this.api});
  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: api.notifications(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('无法加载记录：${snapshot.error}'));
        final logs = snapshot.data!;
        if (logs.isEmpty) return const Center(child: Text('还没有触发过通知。'));
        return ListView(
          children: logs
              .map((log) => ListTile(
                    leading: const Icon(Icons.notifications_active_outlined),
                    title: Text(log['title'] as String),
                    subtitle: Text('${log['body']}\n${log['status']} · ${log['created_at']}'),
                    isThreeLine: true,
                  ))
              .toList(),
        );
      },
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.api});
  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const ListTile(title: Text('推送状态'), subtitle: Text('请在原生层完成极光注册与通知权限授权。')),
        ListTile(
          leading: const Icon(Icons.system_update_outlined),
          title: const Text('检查更新'),
          subtitle: const Text('发现新版后跳转至蒲公英安装页'),
          onTap: () async {
            final package = await PackageInfo.fromPlatform();
            final version = await api.checkUpdate(package.version);
            final hasUpdate = version['hasUpdate'] as bool? ?? false;
            final url = version['downloadUrl'] as String?;
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(hasUpdate ? '发现新版本 ${version['version']} (${version['build']})' : '已是最新版本')));
            }
            if (hasUpdate && url != null && url.isNotEmpty) await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
          },
        ),
      ],
    );
  }
}

class TaskEditor extends StatefulWidget {
  const TaskEditor({super.key, required this.api});
  final ApiClient api;

  @override
  State<TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<TaskEditor> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController(text: '天气带伞提醒');
  final latitude = TextEditingController(text: '36.0671');
  final longitude = TextEditingController(text: '120.3826');
  TimeOfDay time = const TimeOfDay(hour: 0, minute: 5);
  bool saving = false;

  @override
  void dispose() {
    name.dispose();
    latitude.dispose();
    longitude.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('新建天气提醒')),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(controller: name, decoration: const InputDecoration(labelText: '任务名称'), validator: _required),
            TextFormField(controller: latitude, decoration: const InputDecoration(labelText: '纬度'), keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: _number),
            TextFormField(controller: longitude, decoration: const InputDecoration(labelText: '经度'), keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: _number),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('每日检测时间'),
              subtitle: Text(time.format(context)),
              trailing: const Icon(Icons.schedule),
              onTap: () async {
                final picked = await showTimePicker(context: context, initialTime: time);
                if (picked != null) setState(() => time = picked);
              },
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('默认只检查当天 08:00–19:00；任一小时降雨概率大于 0% 时推送一次。'),
            ),
            FilledButton(
              onPressed: saving ? null : _save,
              child: Text(saving ? '保存中…' : '创建提醒'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      final schedule = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      await widget.api.createWeatherTask(
        name: name.text,
        latitude: double.parse(latitude.text),
        longitude: double.parse(longitude.text),
        scheduleTime: schedule,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('创建失败：$error')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String? _required(String? value) => value == null || value.trim().isEmpty ? '请填写此项' : null;
  String? _number(String? value) => double.tryParse(value ?? '') == null ? '请输入有效数字' : null;
}
