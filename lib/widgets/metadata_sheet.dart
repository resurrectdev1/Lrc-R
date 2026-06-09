import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/lrc_session.dart';
import '../theme/lrc_theme.dart';

class MetadataSheet extends StatefulWidget {
  final LrcTheme theme;
  const MetadataSheet({super.key, required this.theme});

  @override
  State<MetadataSheet> createState() => _MetadataSheetState();
}

class _MetadataSheetState extends State<MetadataSheet> {
  late TextEditingController _titleCtrl;
  late TextEditingController _artistCtrl;
  late TextEditingController _albumCtrl;

  @override
  void initState() {
    super.initState();
    final session = context.read<LrcSession>();
    _titleCtrl  = TextEditingController(text: session.title);
    _artistCtrl = TextEditingController(text: session.artist);
    _albumCtrl  = TextEditingController(text: session.album);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _artistCtrl.dispose();
    _albumCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme     = widget.theme;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final session   = context.read<LrcSession>();

    return Container(
      decoration: BoxDecoration(
        color:        theme.surfaceHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomPad),
      child: Column(
        mainAxisSize:       MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color:        theme.textMuted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('LRC Metadata', style: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w800, color: theme.textPrimary)),
            Text('Embedded in the [ti:] [ar:] [al:] tags',
                 style: TextStyle(fontSize: 12, color: theme.textSecondary)),
                 const SizedBox(height: 20),
                 _field(_titleCtrl,  'Title',  Icons.music_note_rounded, theme),
                 const SizedBox(height: 12),
                 _field(_artistCtrl, 'Artist', Icons.person_rounded,     theme),
                 const SizedBox(height: 12),
                 _field(_albumCtrl,  'Album',  Icons.album_rounded,      theme),
                 const SizedBox(height: 20),
                 SizedBox(
                   width: double.infinity, height: 50,
                   child: FilledButton(
                     style: FilledButton.styleFrom(
                       backgroundColor: theme.primary,
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                     ),
                     onPressed: () {
                       session.setTitle(_titleCtrl.text.trim());
                       session.setArtist(_artistCtrl.text.trim());
                       session.setAlbum(_albumCtrl.text.trim());
                       Navigator.pop(context);
                     },
                     child: const Text('Save',
                                       style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                   ),
                 ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon, LrcTheme theme) =>
  TextField(
    controller: ctrl,
    style:      TextStyle(color: theme.textPrimary, fontSize: 14),
    decoration: InputDecoration(
      labelText:  label,
      prefixIcon: Icon(icon, size: 18, color: theme.textMuted),
    ),
  );
}
