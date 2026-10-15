import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/product.dart';
import '../services/shop.dart';
import '../theme.dart';
import 'product_detail.dart';

/// Powered by ASUS: machines customers built, shown off.
///
/// Two halves, and the join between them is the point. A build is
/// photographs plus a list of parts, and each part is a real product id
/// rather than a line of text — so the gallery is not a scrapbook, it is
/// a set of routes back into the shop.
///
/// Nothing on this screen decides what is published. It reads a view
/// that only ever returns approved submissions, and the policy
/// underneath says the same thing; a screen that forgot to filter would
/// come back empty rather than publishing a stranger's photograph.
///
/// The ASUS badge is not decided here either. A trigger in the database
/// works it out from the tagged parts every time they change. This
/// screen draws what it is told.
class RigsScreen extends StatefulWidget {
  final Shop shop;
  const RigsScreen({super.key, required this.shop});

  @override
  State<RigsScreen> createState() => _RigsScreenState();
}

class _RigsScreenState extends State<RigsScreen> {
  late Future<List<RigShowcase>> _future;
  bool _asusOnly = false;

  @override
  void initState() {
    super.initState();
    _future = widget.shop.loadRigGallery();
  }

  void _reload() => setState(() => _future = widget.shop.loadRigGallery());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Powered by ASUS'),
        actions: [
          IconButton(
            tooltip: 'Show us yours',
            icon: const Icon(Icons.add_a_photo_outlined),
            onPressed: () async {
              final sent = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                    builder: (_) => RigSubmitScreen(shop: widget.shop)),
              );
              // A new submission is not published yet, so the gallery
              // will not have changed — but reloading costs one request
              // and avoids the screen looking stale after the trip.
              if (sent == true) _reload();
            },
          ),
        ],
      ),
      body: FutureBuilder<List<RigShowcase>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final all = snapshot.data ?? [];
          final shown =
              _asusOnly ? all.where((r) => r.asusVerified).toList() : all;

          return RefreshIndicator(
            onRefresh: () async {
              _reload();
              await _future;
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
              children: [
                Text(
                  'Machines our customers built, with the parts they used. Tag '
                  'an ASUS, ROG or TUF component in yours and it earns the '
                  'certified badge.',
                  style:
                      TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  ChoiceChip(
                    label: Text('All builds (${all.length})'),
                    selected: !_asusOnly,
                    onSelected: (_) => setState(() => _asusOnly = false),
                    selectedColor: AppTheme.redDark,
                    labelStyle: TextStyle(
                        fontSize: 12,
                        color: _asusOnly ? AppTheme.ink : Colors.white),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(
                        'ASUS Certified (${all.where((r) => r.asusVerified).length})'),
                    selected: _asusOnly,
                    onSelected: (_) => setState(() => _asusOnly = true),
                    selectedColor: AppTheme.redDark,
                    labelStyle: TextStyle(
                        fontSize: 12,
                        color: _asusOnly ? Colors.white : AppTheme.ink),
                  ),
                ]),
                const SizedBox(height: 14),
                if (shown.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(children: [
                      Icon(Icons.photo_library_outlined,
                          size: 46, color: Colors.grey.shade400),
                      const SizedBox(height: 10),
                      Text('No builds published yet.',
                          style: TextStyle(color: Colors.grey.shade600)),
                    ]),
                  )
                else
                  ...shown.map(_rigCard),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _rigCard(RigShowcase rig) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (rig.imageUrls.isNotEmpty)
              SizedBox(
                height: 180,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: rig.imageUrls.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    child: Image.network(
                      rig.imageUrls[i],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 180,
                        color: AppTheme.line,
                        child: const Icon(Icons.broken_image_outlined,
                            color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: Text(rig.title,
                    style: const TextStyle(
                        fontSize: 15.5, fontWeight: FontWeight.bold)),
              ),
              if (rig.asusVerified)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(4),
                    border: const Border(
                        left: BorderSide(color: AppTheme.red, width: 3)),
                  ),
                  child: const Text('ASUS CERTIFIED',
                      style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
            ]),
            const SizedBox(height: 3),
            Text('Built by ${rig.builder}',
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
            if (rig.description != null) ...[
              const SizedBox(height: 8),
              Text(rig.description!,
                  style: const TextStyle(fontSize: 13, height: 1.5)),
            ],
            if (rig.parts.isNotEmpty) ...[
              const Divider(height: 22),
              const Text('Parts used',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              // Each tag is a real product id, so it goes to the product.
              // One that has since been switched off is shown but not
              // tappable rather than leading somewhere empty.
              ...rig.parts.map((part) {
                final product = widget.shop.byId(part.productId);
                return InkWell(
                  onTap: product == null
                      ? null
                      : () {
                          widget.shop.trackView(product.id);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProductDetailScreen(
                                  product: product, shop: widget.shop),
                            ),
                          );
                        },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Expanded(
                        child: Text(part.name,
                            style: TextStyle(
                                fontSize: 12.5,
                                color: product == null
                                    ? Colors.grey
                                    : AppTheme.redDark,
                                decoration: product == null
                                    ? null
                                    : TextDecoration.underline)),
                      ),
                      Text(part.brand,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500)),
                    ]),
                  ),
                );
              }),
            ],
          ],
        ),
      );
}

/// Photograph the build, name the parts, send it in.
class RigSubmitScreen extends StatefulWidget {
  final Shop shop;
  const RigSubmitScreen({super.key, required this.shop});

  @override
  State<RigSubmitScreen> createState() => _RigSubmitScreenState();
}

class _RigSubmitScreenState extends State<RigSubmitScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _search = TextEditingController();

  final List<Uint8List> _photos = [];
  final List<Product> _tagged = [];

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_title, _description, _search]) {
      c.dispose();
    }
    super.dispose();
  }

  // Asked for at a size the gallery can actually show, and well inside
  // the bucket's 5MB limit, rather than uploading whatever came off the
  // sensor and shrinking it afterwards.
  Future<void> _addPhotos() async {
    final picker = ImagePicker();
    try {
      final files = await picker.pickMultiImage(maxWidth: 1600, imageQuality: 85);
      if (files.isEmpty) return;

      for (final file in files) {
        if (_photos.length >= 6) break;
        _photos.add(await file.readAsBytes());
      }
      if (mounted) setState(() {});
    } catch (e) {
      setState(() => _error = 'Could not open the gallery.');
    }
  }

  /// Searched against the catalogue already in memory: every screen has
  /// the products loaded before it draws anything, so this is a filter
  /// over a list and costs nothing per keystroke.
  List<Product> get _matches {
    final needle = _search.text.trim().toLowerCase();
    if (needle.length < 2) return const [];

    return widget.shop.products
        .where((p) => '${p.name} ${p.brand}'.toLowerCase().contains(needle))
        .where((p) => !_tagged.any((t) => t.id == p.id))
        .take(8)
        .toList();
  }

  /// The badge the submission is heading for, worked out from the same
  /// rule the database uses. A preview and nothing more — the trigger has
  /// the final word — but somebody choosing parts should see the badge
  /// appear as they tag the board that earns it.
  bool get _looksAsus => _tagged.any(
      (p) => RegExp(r'^(asus|rog)', caseSensitive: false).hasMatch(p.brand));

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _busy = true;
    });

    final problem = await widget.shop.submitRig(
      title: _title.text.trim(),
      description: _description.text.trim(),
      photos: _photos,
      productIds: _tagged.map((p) => p.id).toList(),
    );

    if (!mounted) return;
    setState(() => _busy = false);

    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Thanks — your build is with us. It appears in the '
          'gallery once a member of staff has looked at it.'),
    ));
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.shop.loggedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('Show us yours')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Text('Please sign in to submit a build.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600)),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Show us yours')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'Give it a name',
              hintText: 'e.g. White ROG build, first attempt',
            ),
          ),
          TextField(
            controller: _description,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Anything you want to say about it (optional)',
            ),
          ),
          const SizedBox(height: 18),

          Row(children: [
            const Text('Photos',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const Spacer(),
            TextButton.icon(
              onPressed: _photos.length >= 6 ? null : _addPhotos,
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
              label: Text(_photos.isEmpty ? 'Add photos' : 'Add more'),
            ),
          ]),
          Text('Up to six. ${_photos.length} chosen.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          if (_photos.isNotEmpty)
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => Stack(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    child: Image.memory(_photos[i],
                        height: 90, width: 90, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: InkWell(
                      onTap: () => setState(() => _photos.removeAt(i)),
                      child: Container(
                        color: Colors.black54,
                        padding: const EdgeInsets.all(2),
                        child: const Icon(Icons.close,
                            size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ]),
              ),
            ),

          const SizedBox(height: 20),
          const Text('Which parts did you use?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 6),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Start typing a product name…',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          ..._matches.map((p) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(p.name, style: const TextStyle(fontSize: 13)),
                subtitle: Text(p.brand, style: const TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.add, size: 18),
                onTap: () => setState(() {
                  _tagged.add(p);
                  _search.clear();
                }),
              )),

          if (_looksAsus)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F8E8),
                borderRadius: BorderRadius.circular(AppTheme.radius),
              ),
              child: const Text(
                'ASUS Certified — one of these is ASUS, ROG or TUF hardware.',
                style: TextStyle(fontSize: 12.5, color: AppTheme.green),
              ),
            ),

          Wrap(
            spacing: 6,
            children: _tagged
                .map((p) => Chip(
                      label: Text(p.name,
                          style: const TextStyle(fontSize: 11.5)),
                      deleteIcon: const Icon(Icons.close, size: 15),
                      onDeleted: () =>
                          setState(() => _tagged.removeWhere((t) => t.id == p.id)),
                    ))
                .toList(),
          ),
          Text(
            'Each part you tag becomes a link back to it in the shop. An ASUS, '
            'ROG or TUF part earns the certified badge automatically.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),

          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!,
                style: const TextStyle(color: AppTheme.red, fontSize: 13)),
          ],

          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Submit my build'),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
