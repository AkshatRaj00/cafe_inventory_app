import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/user_role.dart';
import '../../../core/models/app_user.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  late Box<AppUser> _userBox;

  @override
  void initState() {
    super.initState();
    _userBox = Hive.box<AppUser>('users');
  }

  void _showAddOrEditDialog({AppUser? user}) {
    final idCtrl = TextEditingController(text: user?.id ?? '');
    final nameCtrl = TextEditingController(text: user?.name ?? '');
    final passCtrl = TextEditingController();
    UserRole role = user?.role ?? UserRole.manager; // default
    final isEdit = user != null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? 'Edit User' : 'Add User'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: idCtrl,
                readOnly: isEdit, // id change na ho
                decoration: const InputDecoration(
                  labelText: 'User ID',
                ),
              ),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Name',
                ),
              ),
              if (!isEdit)
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                  ),
                ),
              const SizedBox(height: 12),
              DropdownButtonFormField<UserRole>(
                value: role,
                items: UserRole.values
                    .map(
                      (r) => DropdownMenuItem(
                        value: r,
                        child: Text(r.label),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) role = v;
                },
                decoration: const InputDecoration(
                  labelText: 'Role',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final id = idCtrl.text.trim();
              final name = nameCtrl.text.trim();
              final pass = passCtrl.text.trim();

              if (id.isEmpty || name.isEmpty || (!isEdit && pass.isEmpty)) {
                return;
              }

              if (isEdit) {
                user!
                  ..name = name
                  ..role = role
                  ..save();
              } else {
                // check duplicate id
                final exists = _userBox.values.any((u) => u.id == id);
                if (exists) return;

                _userBox.add(
                  AppUser(
                    id: id,
                    name: name,
                    passwordHash: pass,
                    role: role,
                    isActive: true,
                  ),
                );
              }

              Navigator.pop(context);
              setState(() {});
            },
            child: Text(isEdit ? 'Save' : 'Create'),
          ),
        ],
      ),
    );
  }

  void _toggleActive(AppUser user) {
    user
      ..isActive = !user.isActive
      ..save();
    setState(() {});
  }

  void _deleteUser(AppUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete user?'),
        content: Text('User "${user.name}" will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await user.delete();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = _userBox.values.toList()
      ..sort((a, b) => a.role.index.compareTo(b.role.index));

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddOrEditDialog(),
        child: const Icon(Icons.add),
      ),
      body: ListView.separated(
        itemCount: users.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final u = users[index];
          return ListTile(
            leading: Icon(
              u.role.icon,
              color: u.role.color,
            ),
            title: Text('${u.name} (${u.id})'),
            subtitle: Text(
              '${u.role.label} • ${u.isActive ? 'Active' : 'Inactive'}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: u.isActive,
                  onChanged: (_) => _toggleActive(u),
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _showAddOrEditDialog(user: u),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: Colors.redAccent,
                  onPressed: () => _deleteUser(u),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
