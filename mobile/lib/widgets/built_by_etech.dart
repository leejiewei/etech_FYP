import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';
import '../theme.dart';

/// "Built by eTech" on the home screen: the shop's own high-end builds,
/// one photo each, and a tap through to the Facebook post that has the
/// rest. The website's home page has the same section.
///
/// This list mirrors HIGHEND_BUILDS in web/js/highend-builds.js -- add a
/// build there first (it explains where the photo and post link come
/// from), then copy the entry here. The photo is fetched from the
/// website, so it only needs saving once, into web/images/builds/.
class HighendBuild {
  final String title;
  final String photo; // path under the website, e.g. images/builds/x.jpg
  final String post;
  final List<String> specs;
  const HighendBuild(this.title, this.photo, this.post, this.specs);
}

const highendBuilds = [
  HighendBuild(
    'ROG Astral RTX 5080 Upgrade',
    'images/builds/black-rtx5080-astral.jpg',
    'https://www.facebook.com/etech.computer.7/posts/pfbid023VzpZ3WmPAipXfEi5PxSjrebM38FKw93rQTNHcQYGH2TxLGkBmecEd1gv2BjfHmsl',
    ['ROG Astral RTX 5080 OC', 'TUF Gaming B850M-Plus WiFi 7', '32GB DDR5 6000', 'TUF LC III 360 ARGB LCD'],
  ),
  HighendBuild(
    'White 9800X3D RTX 5070 Ti',
    'images/builds/white-rtx5070ti-tuf.jpg',
    'https://www.facebook.com/etech.computer.7/posts/pfbid0BezEx2AqaiZFW4ErwhsuKyrWp6vw2iizBSEDqs68xVAuPKXPR7dhcArwFYwXRji3l',
    ['Ryzen 7 9800X3D', 'TUF Gaming RTX 5070 Ti 16GB', '32GB DDR5 6000 CL30', 'Prime LC 360 ARGB'],
  ),
  HighendBuild(
    'White 7800X3D RTX 5070',
    'images/builds/white-rtx5070-zotac.jpg',
    'https://www.facebook.com/etech.computer.7/posts/pfbid02od1URxTpwMkCxyNz9J1fs9AJPGX9UF5fdq5MxowMZ6wyNhxWJvuL4vaHqdj4XLKvl',
    ['Ryzen 7 7800X3D', 'ZOTAC RTX 5070 AMP White', '16GB DDR5 6000 CL30', 'Prime LC 360 ARGB'],
  ),
  HighendBuild(
    '9700X RTX 5070 Ti Build',
    'images/builds/black-rtx5070ti-tuf.jpg',
    'https://www.facebook.com/etech.computer.7/posts/pfbid04d64B4Ec83uKgy4C6S8M8qHdTxEW31sVSvfYNfWzirgmDnjLknkLVVGYv6Buv5atl',
    ['Ryzen 7 9700X', 'TUF Gaming RTX 5070 Ti 16GB', '32GB DDR5', 'FX360 LCD ARGB AIO'],
  ),
  HighendBuild(
    '9800X3D RTX 5070 RGB Build',
    'images/builds/black-rtx5070-prime.jpg',
    'https://www.facebook.com/etech.computer.7/posts/pfbid022NMyVEvDS5qLY61pRVki4yaz3JASqWnPgEJJN69wpCYY9kPN4fPcigPWc483347tl',
    ['Ryzen 7 9800X3D', 'Prime RTX 5070 12GB OC', '32GB DDR5 6000', 'TUF LC III 360 ARGB LCD'],
  ),
  HighendBuild(
    'Core Ultra 7 RTX 5070 Upgrade',
    'images/builds/black-rtx5070-ultra7.jpg',
    'https://www.facebook.com/etech.computer.7/posts/pfbid0Vgg5JZktiwzzgJcaf8tG9aGUAePEYbGEkhUcdz6MeG8ivRoR1CYyWe4zCTUEhjyGl',
    ['Core Ultra 7 270K Plus', 'Prime RTX 5070 12GB OC', '32GB DDR5 6000 CL30', 'FX240 LCD ARGB AIO'],
  ),
];

const _etechFacebook = 'https://www.facebook.com/etech.computer.7/';

class BuiltByEtech extends StatelessWidget {
  const BuiltByEtech({super.key});

  // externalApplication hands the link to Android, which opens the
  // Facebook app when it is installed and the browser when it is not.
  // Only facebook.com links are opened; anything else falls back to the
  // shop's page, the same as safeUrl() on the website.
  Future<void> _open(BuildContext context, String link) async {
    final uri = Uri.tryParse(link);
    final safe = uri != null &&
            uri.scheme == 'https' &&
            (uri.host == 'www.facebook.com' || uri.host == 'facebook.com')
        ? uri
        : Uri.parse(_etechFacebook);
    final ok = await launchUrl(safe, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Facebook.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (highendBuilds.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 22, 16, 2),
          child: Text(
            'Built by eTech',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Text(
            'High-end builds from our shop. Tap one for all its photos.',
            style: TextStyle(fontSize: 12.5, color: Colors.black54),
          ),
        ),
        SizedBox(
          // The shop photographs its builds upright, so the photo is 4:5
          // (220 wide -> 275 tall) with the title and parts beneath it.
          height: 420,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: highendBuilds.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _card(context, highendBuilds[i]),
          ),
        ),
      ],
    );
  }

  Widget _card(BuildContext context, HighendBuild b) => SizedBox(
    width: 220,
    child: Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppTheme.line),
      ),
      child: InkWell(
        onTap: () => _open(context, b.post),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 4 / 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    '${Config.webOrigin}/${b.photo}',
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : const ColoredBox(color: AppTheme.pageBg),
                    errorBuilder: (_, __, ___) => const ColoredBox(
                      color: AppTheme.pageBg,
                      child: Icon(Icons.computer, size: 48, color: Colors.black26),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'See all photos',
                        style: TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    for (final s in b.specs.take(4))
                      Text(
                        '• $s',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, color: AppTheme.ink),
                      ),
                    const Spacer(),
                    const Text(
                      'View on Facebook ↗',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.red,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
