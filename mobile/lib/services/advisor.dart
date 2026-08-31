import '../models/product.dart';
import 'compatibility.dart';

/// The AI hardware consultant's brain.
///
/// It is NOT a large language model — there is no AI service involved. It
/// reads the budget, screen resolution and intended use out of a sentence,
/// then searches every CPU and graphics card pairing we sell and keeps the
/// best complete build that fits the budget and passes every compatibility
/// rule. The answers are always technically correct because they are
/// assembled from the real catalogue, not guessed at.
class Advisor {
  final List<Product> products;
  Advisor(this.products);

  // How quick each part is, 0-100, used only for recommending.
  static const Map<String, Map<String, int>> cpuScore = {
    'Ryzen 5 7500F': {'gaming': 78, 'multi': 48},
    'Ryzen 5 7600X': {'gaming': 82, 'multi': 52},
    'Ryzen 5 7500X3D': {'gaming': 88, 'multi': 50},
    'Ryzen 5 9600X': {'gaming': 86, 'multi': 56},
    'Ryzen 7 7800X3D': {'gaming': 96, 'multi': 62},
    'Ryzen 7 9700X': {'gaming': 88, 'multi': 68},
    'Ryzen 9 9900X': {'gaming': 90, 'multi': 88},
    'Ryzen 7 9800X3D': {'gaming': 100, 'multi': 70},
    'Ryzen 9 9950X3D': {'gaming': 100, 'multi': 100},
    'Ryzen 3 3200G': {'gaming': 30, 'multi': 18},
    'Ryzen 5 5500': {'gaming': 55, 'multi': 40},
    'Ryzen 5 3400G': {'gaming': 33, 'multi': 22},
    'Ryzen 5 5600': {'gaming': 62, 'multi': 44},
    'Ryzen 5 5600GT': {'gaming': 62, 'multi': 44},
    'Ryzen 7 5700X': {'gaming': 68, 'multi': 58},
    'Ryzen 7 5800X3D (10th Anniversary)': {'gaming': 84, 'multi': 60},
    'Core Ultra 5 225': {'gaming': 68, 'multi': 46},
    'Core Ultra 5 245KF': {'gaming': 80, 'multi': 62},
    'Core Ultra 7 265K': {'gaming': 86, 'multi': 84},
    'Core Ultra 7 270K Plus': {'gaming': 88, 'multi': 88},
    'Core Ultra 9 285K': {'gaming': 90, 'multi': 96},
    'Core i5-14400F': {'gaming': 68, 'multi': 48},
    'Core i5-14400': {'gaming': 68, 'multi': 48},
    'Core i5-14600K': {'gaming': 82, 'multi': 66},
    'Core i7-12700': {'gaming': 74, 'multi': 62},
    'Core i7-14700F': {'gaming': 88, 'multi': 86},
    'Core i7-14700': {'gaming': 88, 'multi': 86},
    'Core i9-14900K': {'gaming': 92, 'multi': 96},
  };

  static const Map<String, int> gpuScore = {
    'GT 710': 3, 'GT 730': 5, 'GT 1030': 8, 'GTX 1650': 22, 'RTX 3050': 30,
    'RTX 5050': 38, 'RTX 5060': 48, 'RTX 5060 Ti': 60, 'RX 9060 XT': 58,
    'RTX 5070': 72, 'RX 9070 XT': 85, 'RTX 5070 Ti': 88,
    'RTX 5080': 100, 'RTX 5090': 130,
  };

  int _score(Product p, String key) {
    if (p.subcategory == 'GPU') return gpuScore[p.attrs['chip']] ?? 0;
    // Product names start with the brand, so try without it too.
    var row = cpuScore[p.name];
    if (row == null && p.name.startsWith('${p.brand} ')) {
      row = cpuScore[p.name.substring(p.brand.length + 1)];
    }
    return row?[key] ?? 0;
  }

  // ------------------------------------------------------------
  // Reading the question
  // ------------------------------------------------------------
  static const Map<String, List<String>> _workloadWords = {
    'esports': ['cs2', 'cs:go', 'csgo', 'counter strike', 'valorant', 'dota',
      'lol', 'league of legends', 'overwatch', 'apex', 'rainbow six', 'r6',
      'pubg', 'rocket league', 'esports', 'competitive'],
    'aaa': ['cyberpunk', 'aaa', 'gta', 'elden ring', 'starfield', 'witcher',
      'battlefield', 'call of duty', 'cod', 'open world', 'ray tracing'],
    'creator': ['video editing', 'editing', 'premiere', 'render', 'rendering',
      'blender', '3d', 'cad', 'photoshop', 'streaming', 'stream', 'obs'],
    'office': ['office', 'study', 'assignment', 'word', 'excel', 'browsing',
      'admin', 'school', 'homework'],
  };

  Request parse(String message) {
    var text = ' ${message.toLowerCase()} ';
    final request = Request();

    // Budget first, so "bajet 4k" is not mistaken for 4K resolution.
    final budgetPattern = RegExp(
        r'(budget|bajet|belanjawan|rm|myr|ringgit|under|below|around|about|max|spend|harga)\s*:?\s*(?:rm|myr)?\s*(\d[\d,]*(?:\.\d+)?)\s*(k|ribu)?',
        caseSensitive: false);
    final budgetMatch = budgetPattern.firstMatch(text);
    if (budgetMatch != null) {
      request.budget = _toRinggit(budgetMatch.group(2)!, budgetMatch.group(3));
      text = text.replaceFirst(budgetMatch.group(0)!, ' ');
    }

    // Resolution, from whatever is left
    if (RegExp(r'\b(1080p?|full\s*hd|fhd)\b').hasMatch(text)) {
      request.resolution = '1080p';
    } else if (RegExp(r'\b(1440p|qhd|2\s*k)\b').hasMatch(text)) {
      request.resolution = '1440p';
    } else if (RegExp(r'\b(2160p|uhd|4\s*k)\b').hasMatch(text)) {
      request.resolution = '4K';
    }

    // Still no budget? accept a bare number
    if (request.budget == null) {
      final bare = RegExp(r'\b(\d[\d,]*(?:\.\d+)?)\s*(k|ribu)?\b').firstMatch(text);
      if (bare != null) {
        final value = _toRinggit(bare.group(1)!, bare.group(2));
        if (value != null && value >= 1000 && value <= 60000) {
          request.budget = value;
        }
      }
    }

    for (final entry in _workloadWords.entries) {
      if (entry.value.any(text.contains)) {
        request.workload = entry.key;
        break;
      }
    }

    final buildWords = RegExp(
        r'(build|recommend|recomend|suggest|spec|rig|setup|assemble|what should i|which pc|cadang)');
    final pcWords = RegExp(r'(pc|computer|desktop|rig|system|build)');
    request.wantsBuild =
        (request.budget != null && pcWords.hasMatch(text)) ||
            (buildWords.hasMatch(text) && pcWords.hasMatch(text)) ||
            (request.workload != null && request.budget != null);

    return request;
  }

  static int? _toRinggit(String number, String? suffix) {
    var value = double.tryParse(number.replaceAll(',', ''));
    if (value == null) return null;
    if (suffix != null && (suffix == 'k' || suffix == 'ribu')) value *= 1000;
    if (value > 0 && value < 100) value *= 1000;
    return value.round();
  }

  // ------------------------------------------------------------
  // What the build needs to be good at
  // ------------------------------------------------------------
  Target _targetFor(Request r) {
    final resolution = r.resolution ?? '1080p';
    final workload = r.workload ?? 'gaming';

    if (workload == 'office') {
      return Target('office and study work', 'gaming', 1, 0.3, 45, 0, 16);
    }
    if (workload == 'creator') {
      return Target('video editing and content creation', 'multi', 2, 1, 55, 38, 64);
    }
    if (workload == 'esports') {
      if (resolution == '4K') return Target('esports at 4K', 'gaming', 1.5, 2, 90, 72, 32);
      if (resolution == '1440p') return Target('esports at 1440p', 'gaming', 2, 1.2, 60, 48, 32);
      return Target('esports at 1080p', 'gaming', 2.5, 1, 45, 30, 32);
    }
    if (resolution == '4K') return Target('gaming at 4K', 'gaming', 0.8, 2.5, 90, 72, 32);
    if (resolution == '1440p') return Target('gaming at 1440p', 'gaming', 1, 2, 75, 48, 32);
    return Target('gaming at 1080p', 'gaming', 1.2, 1.5, 55, 38, 32);
  }

  List<Product> _inStock(String sub) => products
      .where((p) => p.subcategory == sub && p.inStock && !p.excludeFromBuilder)
      .toList();

  Product? _cheapest(List<Product> list) {
    if (list.isEmpty) return null;
    final sorted = List<Product>.from(list)
      ..sort((a, b) => a.price.compareTo(b.price));
    return sorted.first;
  }

  /// Fills every remaining slot with the cheapest part that works.
  Map<String, Product?>? _assemble(Product cpu, Product gpu) {
    final cooler = _cheapest(_inStock('Cooler').where((c) =>
        c.sockets.contains(cpu.socket) && c.coolerRating >= cpu.tdp).toList());
    if (cooler == null) return null;

    final mobo = _cheapest(
        _inStock('Motherboard').where((m) => m.socket == cpu.socket).toList());
    if (mobo == null) return null;

    final ram = _cheapest(_inStock('RAM').where((r) =>
        Compatibility.ramGenFits(r.ramGen, mobo.ramGen) &&
        !r.incompatibleSockets.contains(cpu.socket)).toList());
    if (ram == null) return null;

    final storage = _cheapest(_inStock('Storage'));
    if (storage == null) return null;

    // 25% spare on the power supply, and the RTX 50 cards want a native
    // 12VHPWR lead rather than the adapter.
    final needed = cpu.tdp + gpu.power + Compatibility.otherPartsWattage;
    final wanted = (needed * 1.25).ceil();
    final needsHpwr = (gpu.attrs['chip'] ?? '').toString().startsWith('RTX 5');
    final psus = _inStock('PSU')
        .where((p) => !needsHpwr || p.attrs['connector12VHPWR'] != 'No')
        .toList();
    final psu = _cheapest(psus.where((p) => p.wattage >= wanted).toList()) ??
        _cheapest(psus.where((p) => p.wattage >= needed).toList());
    if (psu == null) return null;

    final pcCase = _cheapest(_inStock('Case').where((c) =>
        c.supportedFormFactors.contains(mobo.formFactor) &&
        c.maxGpuLength >= gpu.length &&
        (mobo.attrs['backConnector'] != 'Yes' ||
            c.attrs['supportsBackConnector'] == 'Yes')).toList());
    if (pcCase == null) return null;

    return {
      'CPU': cpu, 'Cooler': cooler, 'Motherboard': mobo, 'RAM': ram,
      'GPU': gpu, 'Storage': storage, 'PSU': psu, 'Case': pcCase,
    };
  }

  /// Tries every CPU and graphics card pairing and keeps the best affordable one.
  Recommendation recommend(Request request) {
    final target = _targetFor(request);
    final cpus = _inStock('CPU');

    // The GT cards are display-output parts for repair and office machines.
    const displayOnly = ['GT 710', 'GT 730', 'GT 1030'];
    var gpus = _inStock('GPU')
        .where((g) =>
            request.workload == 'office' ||
            !displayOnly.contains(g.attrs['chip']))
        .toList();

    // Prefer cards that suit the job; fall back if the budget can't reach them.
    final goodEnough =
        gpus.where((g) => _score(g, 'gpu') >= target.minGpu).toList();
    if (goodEnough.isNotEmpty) gpus = goodEnough;

    Map<String, Product?>? best;
    double bestScore = -1;
    double bestTotal = 0;
    // Tracked so we can say what the cheapest complete build would cost if
    // nothing fits the budget.
    double cheapestTotal = double.infinity;

    for (final cpu in cpus) {
      for (final gpu in gpus) {
        final parts = _assemble(cpu, gpu);
        if (parts == null) continue;
        final total = Compatibility.subtotal(parts);

        if (total < cheapestTotal) cheapestTotal = total;
        if (request.budget != null && total > request.budget!) continue;

        // A card far above what the resolution needs is wasted money, so
        // stop counting the extra past the target.
        final usefulGpu =
            _score(gpu, 'gpu').clamp(0, target.targetGpu + 10).toDouble();
        final score =
            _score(cpu, target.cpuKey) * target.cpuWeight + usefulGpu * target.gpuWeight;

        if (score > bestScore || (score == bestScore && total < bestTotal)) {
          bestScore = score;
          bestTotal = total;
          best = parts;
        }
      }
    }

    if (best == null) {
      return Recommendation(
          ok: false, target: target, cheapestTotal: cheapestTotal);
    }

    _spendLeftover(best, request.budget, target);
    return Recommendation(
        ok: true,
        target: target,
        parts: best,
        total: Compatibility.subtotal(best));
  }

  /// Money left over goes on a roomier drive, then a bigger memory kit.
  void _spendLeftover(Map<String, Product?> build, int? budget, Target target) {
    if (budget == null) return;
    final cpu = build['CPU']!;
    final mobo = build['Motherboard']!;

    final drives = _inStock('Storage')
        .where((d) => d.attrs['driveType'] == 'SSD')
        .toList()
      ..sort((a, b) => b.price.compareTo(a.price));

    final kits = _inStock('RAM')
        .where((r) =>
            Compatibility.ramGenFits(r.ramGen, mobo.ramGen) &&
            !r.incompatibleSockets.contains(cpu.socket) &&
            _capacityGB(r) <= target.maxRamGB)
        .toList()
      ..sort((a, b) => b.price.compareTo(a.price));

    for (final upgrade in [
      ['Storage', drives],
      ['RAM', kits]
    ]) {
      final slot = upgrade[0] as String;
      final options = upgrade[1] as List<Product>;
      final current = build[slot]!;
      for (final better in options) {
        if (better.price <= current.price) break;
        final newTotal =
            Compatibility.subtotal(build) - current.price + better.price;
        if (newTotal <= budget) {
          build[slot] = better;
          break;
        }
      }
    }
  }

  int _capacityGB(Product p) {
    final match = RegExp(r'(\d+)').firstMatch('${p.attrs['capacity'] ?? ''}');
    return match == null ? 0 : int.parse(match.group(1)!);
  }
}

class Request {
  int? budget;
  String? resolution;
  String? workload;
  bool wantsBuild = false;
}

class Target {
  final String label;
  final String cpuKey;
  final double cpuWeight;
  final double gpuWeight;
  final int targetGpu;
  final int minGpu;
  final int maxRamGB;
  Target(this.label, this.cpuKey, this.cpuWeight, this.gpuWeight,
      this.targetGpu, this.minGpu, this.maxRamGB);
}

class Recommendation {
  final bool ok;
  final Target target;
  final Map<String, Product?>? parts;
  final double total;
  final double cheapestTotal;
  Recommendation({
    required this.ok,
    required this.target,
    this.parts,
    this.total = 0,
    this.cheapestTotal = 0,
  });
}
