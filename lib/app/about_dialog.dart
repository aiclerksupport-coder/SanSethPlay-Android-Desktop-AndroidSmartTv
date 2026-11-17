import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SanSethAboutDialog extends StatelessWidget {
  const SanSethAboutDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('About SanSeth Play'),
      content: SizedBox(
        width: 430,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Image.asset('assets/branding/app_icon_master.png',
                height: 88, width: 88, fit: BoxFit.contain),
            const SizedBox(height: 12),
            const Text('SanSeth Play',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22)),
            const SizedBox(height: 4),
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text('Version information unavailable');
                }
                if (!snapshot.hasData) {
                  return const Text('Loading version...');
                }
                final info = snapshot.data!;
                return Text('Version ${info.version}+${info.buildNumber}');
              },
            ),
            const Divider(height: 30),
            const ListTile(
              leading: Icon(Icons.person_outline_rounded),
              title: Text('Developer'),
              subtitle: Text('Kalpesh Patel'),
            ),
            const ListTile(
              leading: Icon(Icons.shield_outlined),
              title: Text('Your playlists are your choice'),
              subtitle: Text('Only add streams you are authorized to access.'),
            ),
            const Text(
                'Sanwariya is a brand name. See the source distribution '
                'for privacy, terms and third-party licensing information.',
                style: TextStyle(fontSize: 12, color: Colors.white70)),
          ]),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        )
      ],
    );
  }
}
