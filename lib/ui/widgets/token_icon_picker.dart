import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'group_icon.dart';
import 'service_icon.dart';

/// Returned by [pickTokenIcon] for "Automatic", because null means dismissed.
const automaticTokenIcon = '';

/// Lets the user choose a token's icon. Returns the value to store,
/// [automaticTokenIcon] to go back to the name-based icon, or null if dismissed.
Future<String?> pickTokenIcon(
  BuildContext context, {
  required String issuer,
  required String account,
  String? current,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) =>
        _TokenIconSheet(issuer: issuer, account: account, current: current),
  );
}

class _TokenIconSheet extends StatefulWidget {
  final String issuer;
  final String account;
  final String? current;

  const _TokenIconSheet({
    required this.issuer,
    required this.account,
    required this.current,
  });

  @override
  State<_TokenIconSheet> createState() => _TokenIconSheetState();
}

class _TokenIconSheetState extends State<_TokenIconSheet> {
  String _query = '';

  List<String> get _matches {
    final query = _query.trim().toLowerCase();
    return ServiceIcon.pickableServices
        .where((service) =>
            service.contains(query) ||
            ServiceIcon.serviceLabel(service).toLowerCase().contains(query))
        .toList();
  }

  Future<void> _pickEmoji() async {
    final emoji = await pickGroupIcon(context);
    if (emoji != null && mounted) {
      Navigator.pop(context, ServiceIcon.iconForEmoji(emoji));
    }
  }

  Future<void> _pickImage() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Shrunk on the device before we see it: an icon never needs more, and
      // the result is stored in the vault with the token.
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 128,
        maxHeight: 128,
        imageQuality: 85,
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > ServiceIcon.maxImageBytes) {
        messenger.showSnackBar(
            const SnackBar(content: Text('That image is too large to use')));
        return;
      }
      if (mounted) Navigator.pop(context, ServiceIcon.iconForImage(bytes));
    } on PlatformException {
      messenger.showSnackBar(
          const SnackBar(content: Text('Could not open your photos')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final current = widget.current;
    final hasImage = ServiceIcon.isImage(current);
    final matches = _matches;

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SizedBox(
        height: media.size.height * 0.75,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withAlpha(40),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Text('Token Icon',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            ListTile(
              leading: ServiceIcon(
                issuer: widget.issuer,
                account: widget.account,
                useFavicon: false,
                size: 36,
              ),
              title: const Text('Automatic'),
              subtitle: const Text('Based on the service name'),
              trailing: widget.current == null
                  ? Icon(Icons.check_rounded, color: theme.colorScheme.primary)
                  : null,
              onTap: () => Navigator.pop(context, automaticTokenIcon),
            ),
            ListTile(
              leading: SizedBox(
                width: 36,
                child: Icon(Icons.emoji_symbols_rounded,
                    color: theme.colorScheme.primary),
              ),
              title: const Text('Choose an emoji'),
              onTap: _pickEmoji,
            ),
            ListTile(
              leading: hasImage
                  ? ServiceIcon(
                      issuer: widget.issuer,
                      account: widget.account,
                      iconPath: current,
                      size: 36,
                    )
                  : SizedBox(
                      width: 36,
                      child: Icon(Icons.image_outlined,
                          color: theme.colorScheme.primary),
                    ),
              title: Text(hasImage ? 'Change image' : 'Choose an image'),
              subtitle: const Text('From your photos'),
              trailing: hasImage
                  ? Icon(Icons.check_rounded, color: theme.colorScheme.primary)
                  : null,
              onTap: _pickImage,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  hintText: 'Search services',
                  prefixIcon: Icon(Icons.search_rounded),
                  isDense: true,
                ),
              ),
            ),
            Expanded(
              child: matches.isEmpty
                  ? Center(
                      child: Text('No matching services',
                          style: TextStyle(
                              color:
                                  theme.colorScheme.onSurface.withAlpha(140))),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 84,
                        mainAxisExtent: 84,
                      ),
                      itemCount: matches.length,
                      itemBuilder: (context, index) =>
                          _buildService(theme, matches[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildService(ThemeData theme, String service) {
    final value = ServiceIcon.iconForService(service);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.pop(context, value),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value == widget.current
                ? theme.colorScheme.primary
                : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ServiceIcon(issuer: service, account: '', iconPath: value, size: 40),
            const SizedBox(height: 4),
            Text(
              ServiceIcon.serviceLabel(service),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withAlpha(180),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
