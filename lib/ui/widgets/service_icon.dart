import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Displays a service icon for a token issuer.
/// Uses a built-in icon map for common services, falls back to favicon fetch,
/// then to a first-letter gradient avatar.
class ServiceIcon extends StatelessWidget {
  final String issuer;
  final String account;
  final double size;

  const ServiceIcon({
    super.key,
    required this.issuer,
    required this.account,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = issuer.isNotEmpty ? issuer : account;
    final normalized = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

    // Exact brand logos bundled as assets beat the generic Material glyphs,
    // and being local they never leak which services the user has.
    if (_bundledIcons.contains(normalized)) {
      return _buildBundledIcon(theme, normalized);
    }

    final iconData = _knownIcons[normalized];
    if (iconData != null) {
      return _buildKnownIcon(theme, iconData);
    }

    // Try favicon for unknown issuers
    final domain = _guessDomain(normalized);
    if (domain != null) {
      return _buildFaviconIcon(theme, domain, name);
    }

    return _buildLetterAvatar(theme, name);
  }

  Widget _buildBundledIcon(ThemeData theme, String name) {
    final brand = _knownIcons[name]?.color ?? theme.colorScheme.primary;
    // Near-black brand marks (GitHub, Apple) vanish on the dark theme —
    // render those glyphs in the foreground color instead.
    final glyph = theme.brightness == Brightness.dark &&
            brand.computeLuminance() < 0.08
        ? theme.colorScheme.onSurface
        : brand;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            brand.withAlpha(50),
            brand.withAlpha(20),
          ],
        ),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Center(
        child: SvgPicture.asset(
          'assets/icons/services/$name.svg',
          width: size * 0.5,
          height: size * 0.5,
          colorFilter: ColorFilter.mode(glyph, BlendMode.srcIn),
        ),
      ),
    );
  }

  Widget _buildKnownIcon(ThemeData theme, _ServiceIconData data) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            data.color.withAlpha(50),
            data.color.withAlpha(20),
          ],
        ),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Center(
        child: Icon(data.icon, size: size * 0.5, color: data.color),
      ),
    );
  }

  Widget _buildFaviconIcon(ThemeData theme, String domain, String name) {
    final faviconUrl = 'https://www.google.com/s2/favicons?domain=$domain&sz=64';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withAlpha(15),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      clipBehavior: Clip.antiAlias,
      child: CachedNetworkImage(
        imageUrl: faviconUrl,
        width: size * 0.6,
        height: size * 0.6,
        fit: BoxFit.contain,
        placeholder: (_, _) => _letterCenter(theme, name),
        errorWidget: (_, _, _) => _letterCenter(theme, name),
        imageBuilder: (context, imageProvider) => Center(
          child: Image(
            image: imageProvider,
            width: size * 0.55,
            height: size * 0.55,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Widget _buildLetterAvatar(ThemeData theme, String name) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withAlpha(40),
            theme.colorScheme.primary.withAlpha(15),
          ],
        ),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: _letterCenter(theme, name),
    );
  }

  Widget _letterCenter(ThemeData theme, String name) {
    final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Center(
      child: Text(
        letter,
        style: TextStyle(
          fontSize: size * 0.45,
          fontWeight: FontWeight.w800,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  static String? _guessDomain(String normalized) {
    // Only attempt for names that look like they could be domains
    if (normalized.length < 3) return null;
    // Check if it's a known service first (already handled)
    if (_knownIcons.containsKey(normalized)) return null;
    return '$normalized.com';
  }

  // Brand logos shipped in assets/icons/services/ (simple-icons, CC0).
  // Services missing here (e.g. Microsoft, Xbox) were pulled from that set
  // for trademark reasons and keep their Material-icon fallback below.
  static const Set<String> _bundledIcons = {
    'amazon', 'apple', 'aws', 'battlenet', 'binance', 'bitbucket',
    'bitwarden', 'blizzard', 'cloudflare', 'coinbase', 'digitalocean',
    'discord', 'docker', 'dropbox', 'ea', 'epicgames', 'facebook', 'github',
    'gitlab', 'gmail', 'godaddy', 'google', 'heroku', 'hetzner', 'instagram',
    'lastpass', 'linkedin', 'meta', 'namecheap', 'netflix', 'netlify',
    'nintendo', 'npm', 'ovh', 'paypal', 'playstation', 'proton',
    'protonmail', 'reddit', 'riot', 'riotgames', 'signal', 'slack',
    'snapchat', 'spotify', 'steam', 'stripe', 'telegram', 'tiktok',
    'tutanota', 'twitch', 'twitter', 'ubisoft', 'vercel', 'whatsapp', 'x',
  };

  static final Map<String, _ServiceIconData> _knownIcons = {
    'github': _ServiceIconData(Icons.code_rounded, Color(0xFF333333)),
    'google': _ServiceIconData(Icons.g_mobiledata_rounded, Color(0xFF4285F4)),
    'gmail': _ServiceIconData(Icons.mail_rounded, Color(0xFFEA4335)),
    'aws': _ServiceIconData(Icons.cloud_rounded, Color(0xFFFF9900)),
    'amazon': _ServiceIconData(Icons.shopping_cart_rounded, Color(0xFFFF9900)),
    'microsoft': _ServiceIconData(Icons.window_rounded, Color(0xFF00A4EF)),
    'azure': _ServiceIconData(Icons.cloud_rounded, Color(0xFF0078D4)),
    'apple': _ServiceIconData(Icons.apple_rounded, Color(0xFF555555)),
    'discord': _ServiceIconData(Icons.headset_mic_rounded, Color(0xFF5865F2)),
    'slack': _ServiceIconData(Icons.tag_rounded, Color(0xFF4A154B)),
    'twitter': _ServiceIconData(Icons.flutter_dash_rounded, Color(0xFF1DA1F2)),
    'x': _ServiceIconData(Icons.close_rounded, Color(0xFF000000)),
    'facebook': _ServiceIconData(Icons.facebook_rounded, Color(0xFF1877F2)),
    'meta': _ServiceIconData(Icons.all_inclusive_rounded, Color(0xFF0081FB)),
    'instagram': _ServiceIconData(Icons.camera_alt_rounded, Color(0xFFE4405F)),
    'reddit': _ServiceIconData(Icons.reddit_rounded, Color(0xFFFF4500)),
    'twitch': _ServiceIconData(Icons.videogame_asset_rounded, Color(0xFF9146FF)),
    'steam': _ServiceIconData(Icons.sports_esports_rounded, Color(0xFF1B2838)),
    'dropbox': _ServiceIconData(Icons.cloud_done_rounded, Color(0xFF0061FF)),
    'digitalocean': _ServiceIconData(Icons.water_drop_rounded, Color(0xFF0080FF)),
    'cloudflare': _ServiceIconData(Icons.shield_rounded, Color(0xFFF48120)),
    'gitlab': _ServiceIconData(Icons.merge_type_rounded, Color(0xFFFC6D26)),
    'bitbucket': _ServiceIconData(Icons.source_rounded, Color(0xFF0052CC)),
    'npm': _ServiceIconData(Icons.inventory_2_rounded, Color(0xFFCB3837)),
    'docker': _ServiceIconData(Icons.directions_boat_rounded, Color(0xFF2496ED)),
    'linkedin': _ServiceIconData(Icons.work_rounded, Color(0xFF0A66C2)),
    'paypal': _ServiceIconData(Icons.payment_rounded, Color(0xFF003087)),
    'stripe': _ServiceIconData(Icons.credit_card_rounded, Color(0xFF635BFF)),
    'coinbase': _ServiceIconData(Icons.currency_bitcoin_rounded, Color(0xFF0052FF)),
    'binance': _ServiceIconData(Icons.currency_exchange_rounded, Color(0xFFF0B90B)),
    'kraken': _ServiceIconData(Icons.waves_rounded, Color(0xFF5741D9)),
    'bitwarden': _ServiceIconData(Icons.lock_rounded, Color(0xFF175DDC)),
    'lastpass': _ServiceIconData(Icons.vpn_key_rounded, Color(0xFFD32D27)),
    'proton': _ServiceIconData(Icons.security_rounded, Color(0xFF6D4AFF)),
    'protonmail': _ServiceIconData(Icons.mail_lock_rounded, Color(0xFF6D4AFF)),
    'tutanota': _ServiceIconData(Icons.mail_lock_rounded, Color(0xFF840010)),
    'signal': _ServiceIconData(Icons.chat_rounded, Color(0xFF3A76F0)),
    'telegram': _ServiceIconData(Icons.send_rounded, Color(0xFF0088CC)),
    'whatsapp': _ServiceIconData(Icons.chat_bubble_rounded, Color(0xFF25D366)),
    'snapchat': _ServiceIconData(Icons.photo_camera_front_rounded, Color(0xFFFFFC00)),
    'tiktok': _ServiceIconData(Icons.music_note_rounded, Color(0xFF000000)),
    'spotify': _ServiceIconData(Icons.music_note_rounded, Color(0xFF1DB954)),
    'netflix': _ServiceIconData(Icons.movie_rounded, Color(0xFFE50914)),
    'epicgames': _ServiceIconData(Icons.sports_esports_rounded, Color(0xFF2F2D2E)),
    'nintendo': _ServiceIconData(Icons.gamepad_rounded, Color(0xFFE60012)),
    'playstation': _ServiceIconData(Icons.sports_esports_rounded, Color(0xFF003791)),
    'xbox': _ServiceIconData(Icons.sports_esports_rounded, Color(0xFF107C10)),
    'ubisoft': _ServiceIconData(Icons.sports_esports_rounded, Color(0xFF000000)),
    'ea': _ServiceIconData(Icons.sports_esports_rounded, Color(0xFF000000)),
    'riot': _ServiceIconData(Icons.sports_esports_rounded, Color(0xFFD32936)),
    'riotgames': _ServiceIconData(Icons.sports_esports_rounded, Color(0xFFD32936)),
    'blizzard': _ServiceIconData(Icons.sports_esports_rounded, Color(0xFF148EFF)),
    'battlenet': _ServiceIconData(Icons.sports_esports_rounded, Color(0xFF148EFF)),
    'heroku': _ServiceIconData(Icons.cloud_queue_rounded, Color(0xFF430098)),
    'vercel': _ServiceIconData(Icons.change_history_rounded, Color(0xFF000000)),
    'netlify': _ServiceIconData(Icons.language_rounded, Color(0xFF00C7B7)),
    'namecheap': _ServiceIconData(Icons.domain_rounded, Color(0xFFDE3723)),
    'godaddy': _ServiceIconData(Icons.domain_rounded, Color(0xFF1BDBDB)),
    'ovh': _ServiceIconData(Icons.dns_rounded, Color(0xFF000E9C)),
    'hetzner': _ServiceIconData(Icons.dns_rounded, Color(0xFFD50C2D)),
  };
}

class _ServiceIconData {
  final IconData icon;
  final Color color;
  const _ServiceIconData(this.icon, this.color);
}
