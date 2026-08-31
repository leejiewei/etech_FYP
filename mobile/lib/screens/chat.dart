import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/advisor.dart';
import '../services/compatibility.dart';
import '../services/shop.dart';
import '../theme.dart';
import '../widgets/product_image.dart';
import 'product_detail.dart';

/// The AI hardware consultant.
///
/// Questions go to Gemini, through the chat-advisor Edge Function, which
/// hands the model the shop's catalogue and makes it answer in a fixed
/// shape. The model chooses which products to recommend and returns their
/// ids; everything shown about a product -- name, price, stock -- is read
/// from the catalogue this app already holds, so it cannot quote a price
/// we do not charge.
///
/// When the consultant cannot answer -- no key configured, no quota left,
/// no signal -- the older rule-based advisor below answers instead. It
/// recommends a complete build from the real catalogue, or answers a
/// hardware question from the same compatibility data the PC Builder
/// uses. That path is why the chat still works with no internet service
/// behind it at all.
class ChatScreen extends StatefulWidget {
  final Shop shop;
  const ChatScreen({super.key, required this.shop});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<_Message> _messages = [];

  @override
  void initState() {
    super.initState();
    _messages.add(_Message.bot(
        'Hi! Tell me what the PC is for and your budget and I will spec the '
        'whole thing out — try "build a pc for CS2, full HD, budget 4k".'));
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// The last few turns, so a follow-up question ("what about a cheaper
  /// one?") is understood in context.
  final List<Map<String, String>> _history = [];

  bool _thinking = false;

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _thinking) return;

    setState(() {
      _messages.add(_Message.user(text));
      _input.clear();
      _thinking = true;
    });
    _scrollToEnd();

    final answer = await widget.shop.askAdvisor(text, _history.take(6).toList());

    _Message reply;
    bool wasBuildRequest;

    if (answer != null) {
      // Gemini chose the products; we supply everything shown about them.
      // An id for a product we do not have -- withdrawn, or invented --
      // is dropped rather than drawn as an empty card.
      final ids = (answer['product_ids'] as List?) ?? const [];
      final picks = ids
          .map((id) => widget.shop.byId(id is int ? id : int.tryParse('$id') ?? -1))
          .whereType<Product>()
          .toList();

      reply = _Message.ai('${answer['reply']}'.trim(), picks);
      wasBuildRequest = answer['is_build_request'] == true;
    } else {
      // No key, no quota or no signal. The built-in advisor still works.
      final advisor = Advisor(widget.shop.products);
      final request = advisor.parse(text);
      wasBuildRequest = request.wantsBuild;

      if (request.wantsBuild && request.budget == null) {
        reply = _Message.bot('Happy to spec that out. What is your budget in RM? '
            'For example: "build a pc for CS2, full HD, budget 4k".');
      } else if (request.wantsBuild) {
        final result = advisor.recommend(request);
        reply = result.ok
            ? _Message.build(result, request)
            : _Message.bot('Sorry — I cannot put a complete PC together for '
                'RM${request.budget}. The cheapest full build I can make from '
                'what is in stock is ${money(result.cheapestTotal)}.');
      } else {
        reply = _Message.bot(_answerQuestion(text));
      }
    }

    if (!mounted) return;
    setState(() {
      _messages.add(reply);
      _thinking = false;
    });

    _history.add({'role': 'user', 'text': text});
    _history.add({'role': 'bot', 'text': reply.plainText});

    widget.shop.logChat(text, reply.plainText, wasBuildRequest);
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  /// General hardware questions, answered from the product data.
  String _answerQuestion(String message) {
    final text = message.toLowerCase();

    // Getting this wrong destroys hardware, so it comes first.
    if (text.contains('argb') || text.contains('rgb') ||
        text.contains('lighting') || text.contains('led strip')) {
      return 'Careful with this one. Everything we stock is 3-pin 5V ARGB '
          '(addressable). That is NOT the same as 4-pin 12V RGB, and the two are '
          'not interchangeable — plugging a 5V ARGB device into a 12V RGB header '
          'will destroy it. The plugs look similar, so check your motherboard '
          'header is marked 5V / ARGB before connecting anything.';
    }

    for (final socket in ['am4', 'am5', 'lga1851', 'lga1700']) {
      if (text.contains(socket)) {
        final label = socket.toUpperCase();
        final cpus = widget.shop.products
            .where((p) => p.subcategory == 'CPU' && p.socket == label);
        final boards = widget.shop.products
            .where((p) => p.subcategory == 'Motherboard' && p.socket == label);
        final ramGen = boards.isEmpty ? '?' : boards.first.ramGen;
        return '$label boards use $ramGen memory. We stock ${cpus.length} '
            'processors and ${boards.length} motherboards for it. '
            'Cheapest CPU: ${_cheapestName(cpus.toList())}.';
      }
    }

    if (text.contains('ddr4') || text.contains('ddr5')) {
      final gen = text.contains('ddr5') ? 'DDR5' : 'DDR4';
      final kits = widget.shop.products
          .where((p) => p.subcategory == 'RAM' && p.ramGen == gen)
          .toList();
      return 'We carry ${kits.length} $gen desktop kits, from '
          '${_cheapestName(kits)}. Remember the board decides which type you '
          'need — the PC Builder only shows memory that fits.';
    }

    if (text.contains('aio') || text.contains('liquid') || text.contains('radiator')) {
      return 'We carry all-in-one liquid coolers with 360mm radiators (rated to '
          'about 300W) and 240mm (about 250W), several with an LCD screen on the '
          'pump. All mount on AM4, AM5, LGA1700 and LGA1851. Air coolers are '
          'cheaper and go up to about 260W. Tell me your CPU and I will say '
          'what is enough.';
    }

    if (text.contains('cooler') || text.contains('cooling') ||
        text.contains('overheat') || text.contains('thermal')) {
      return 'Every CPU has a cooling requirement in watts and every cooler has '
          'a capacity. A stock cooler handles about 65W, which is fine for a '
          'Core i5-14400, but a Core i7-14700 needs 219W — the PC Builder will '
          'not even offer you a cooler that cannot cope.';
    }

    if (text.contains('psu') || text.contains('power supply') || text.contains('wattage')) {
      return 'We add your CPU wattage plus the graphics card wattage plus about '
          '${Compatibility.otherPartsWattage}W for the board, drives and fans, '
          'then check the supply covers it. The PC Builder does this for you and '
          'shows the full sum.';
    }

    if (text.contains('case') || text.contains('casing') || text.contains('form factor')) {
      return 'Board sizes go ATX (biggest), mATX, then Mini-ITX. A case fits its '
          'own size and anything smaller, so an mATX case will NOT take a full ATX '
          'board. Cases also have a maximum graphics card length. The PC Builder '
          'checks both.';
    }

    if (text.contains('compatib')) {
      return 'The PC Builder checks the CPU socket against the motherboard, the '
          'memory type, that the cooler mounts and is strong enough, that the board '
          'fits the case, that the graphics card is short enough, and that the '
          'power supply covers the whole system. It will not let you order a build '
          'that cannot work.';
    }

    if (text.contains('hi') || text.contains('hello')) {
      return 'Hi! Tell me what the PC is for and your budget and I will spec the '
          'whole thing out. I can also answer questions on sockets, memory, '
          'cooling, cases and lighting.';
    }

    return 'Tell me what the PC is for and your budget and I will build you a '
        'full spec — for example "gaming pc for 1440p, budget 6000". I can also '
        'answer questions about socket compatibility, DDR4 vs DDR5, cooling, '
        'case sizes and ARGB lighting.';
  }

  String _cheapestName(List<Product> list) {
    if (list.isEmpty) return 'none in stock';
    final sorted = List<Product>.from(list)
      ..sort((a, b) => a.price.compareTo(b.price));
    return '${sorted.first.name} at ${money(sorted.first.price)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AI Hardware Consultant'),
            Text('Answers built from real stock',
                style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(14),
              itemCount: _messages.length + (_thinking ? 1 : 0),
              itemBuilder: (_, i) => i < _messages.length
                  ? _bubble(_messages[i])
                  : _bubble(_Message.bot('Thinking…')),
            ),
          ),
          if (_messages.length <= 1)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  'build a pc for cs2 full hd bajet 4k',
                  'gaming pc 1440p budget 7000',
                  'can i use ARGB with a 12V header?',
                  'what cooler for a Core i7?',
                ].map((s) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(s, style: const TextStyle(fontSize: 11.5)),
                        onPressed: () => _send(s),
                      ),
                    )).toList(),
              ),
            ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppTheme.line)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Ask a question...',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: AppTheme.red),
                    icon: const Icon(Icons.send, size: 19),
                    onPressed: () => _send(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(_Message m) {
    if (m.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10, left: 50),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.red,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(m.text,
              style: const TextStyle(color: Colors.white, fontSize: 13.5)),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10, right: 26),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: m.recommendation != null
            ? _buildTable(m)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.text,
                      style: const TextStyle(fontSize: 13.5, height: 1.4)),
                  ...m.products.map(_recommendationRow),
                  if (m.products.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Total: ${money(m.products.fold<double>(0, (sum, p) => sum + p.price))}',
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  /// One product the consultant recommended.
  ///
  /// The model supplied the id and nothing else: the name, the price and
  /// the stock all come from the catalogue the app already holds, so the
  /// customer can never be quoted a price we do not charge.
  Widget _recommendationRow(Product p) {
    final outOfStock = p.stock == 'out';

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailScreen(shop: widget.shop, product: p),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE3E5E8)),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          children: [
            ProductImage(url: p.imageUrl, isSvg: p.isSvg, height: 38),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name,
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w600)),
                  Text(
                    '${p.subcategory ?? p.category}'
                    '${outOfStock ? " · Out of Stock" : ""}',
                    style: TextStyle(
                        fontSize: 11,
                        color: outOfStock ? AppTheme.red : Colors.black54),
                  ),
                  Text(money(p.price),
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTable(_Message m) {
    final result = m.recommendation!;
    final parts = result.parts!;
    final checks = Compatibility.check(parts);
    final problems = checks.where((c) => c.level == Level.critical).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('My recommendation for ${result.target.label}'
            '${m.request?.budget != null ? " with a RM${m.request!.budget} budget" : ""}:',
            style: const TextStyle(fontSize: 13.5, height: 1.4)),
        const SizedBox(height: 10),
        ...Compatibility.slots.map((slot) {
          final p = parts[slot];
          if (p == null) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 72,
                  child: Text(slot,
                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
                ),
                Expanded(
                  child: Text(p.name,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                Text(money(p.price), style: const TextStyle(fontSize: 12)),
              ],
            ),
          );
        }),
        const Divider(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Total',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            Text(money(result.total),
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.redDark)),
          ],
        ),
        if (m.request?.budget != null) ...[
          const SizedBox(height: 4),
          Text('That leaves ${money(m.request!.budget! - result.total)} '
              'of your budget.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: problems == 0 ? const Color(0xFFE3F8E8) : const Color(0xFFFDE8E8),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            children: [
              Icon(problems == 0 ? Icons.check_circle : Icons.error,
                  size: 15,
                  color: problems == 0 ? AppTheme.green : AppTheme.red),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  problems == 0
                      ? 'All compatibility checks passed.'
                      : '$problems problem${problems > 1 ? "s" : ""} found.',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: problems == 0 ? AppTheme.green : AppTheme.red),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add_shopping_cart, size: 17),
            label: const Text('Add this build to cart'),
            style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                textStyle: const TextStyle(fontSize: 13)),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              for (final slot in Compatibility.slots) {
                final p = parts[slot];
                if (p != null) await widget.shop.addToCart(p.id);
              }
              messenger.showSnackBar(
                  const SnackBar(content: Text('Build added to your cart')));
            },
          ),
        ),
      ],
    );
  }
}

class _Message {
  final String text;
  final bool isUser;
  final Recommendation? recommendation;
  final Request? request;

  /// Products the AI consultant recommended. Empty for every other kind
  /// of message. Only the ids came from the model; these are our own rows.
  final List<Product> products;

  _Message.user(this.text)
      : isUser = true,
        recommendation = null,
        request = null,
        products = const [];

  _Message.bot(this.text)
      : isUser = false,
        recommendation = null,
        request = null,
        products = const [];

  _Message.ai(this.text, this.products)
      : isUser = false,
        recommendation = null,
        request = null;

  _Message.build(this.recommendation, this.request)
      : isUser = false,
        text = 'Here is my recommendation.',
        products = const [];

  String get plainText {
    if (products.isNotEmpty) {
      return '$text (${products.map((p) => p.name).join('; ')})';
    }
    if (recommendation == null) return text;
    final parts = recommendation!.parts!;
    final lines = Compatibility.slots
        .where((s) => parts[s] != null)
        .map((s) => '$s: ${parts[s]!.name}')
        .join('; ');
    return 'Recommended for ${recommendation!.target.label}: $lines. '
        'Total ${money(recommendation!.total)}.';
  }
}
