import '../models/product.dart';

/// How serious a compatibility finding is.
///
///   critical — the parts physically cannot work together. Must be changed,
///              and it stops the build going in the basket.
///   warning  — the build runs, just not at its best. Never blocks.
///   pass     — all good.
enum Level { critical, warning, pass }

class Check {
  final Level level;
  final String text;
  Check(this.level, this.text);
}

/// The same compatibility rules the website uses, kept in one place so the
/// screen only has to draw the result.
class Compatibility {
  static const List<String> slots = [
    'CPU', 'Cooler', 'Motherboard', 'RAM', 'GPU', 'Storage', 'PSU', 'Case'
  ];

  /// Rough extra wattage for the board, drives and fans.
  static const int otherPartsWattage = 100;

  /// A supply should not run flat out: the draw plus a quarter again.
  static const double psuHeadroom = 1.25;

  /// How big a power supply a build needs: the larger of the graphics
  /// card maker's recommended PSU and the estimated draw plus headroom,
  /// rounded up to the next 50W. Matches psuNeedFor() in web/js/products.js.
  static PsuNeed psuNeed(Product? cpu, Product? gpu) {
    final cpuWatts = cpu?.tdp ?? 0;
    final gpuWatts = gpu?.power ?? 0;
    final draw = cpuWatts + gpuWatts + otherPartsWattage;
    final withHeadroom = ((draw * psuHeadroom) / 50).ceil() * 50;
    final cardMin = gpu?.recommendedPsu ?? 0;
    return PsuNeed(
      cpuWatts: cpuWatts,
      gpuWatts: gpuWatts,
      draw: draw,
      needed: cardMin > withHeadroom ? cardMin : withHeadroom,
      byCard: cardMin > 0 && cardMin >= withHeadroom,
    );
  }

  /// Some CPUs take either memory type, recorded as "DDR4/DDR5".
  static bool ramGenFits(String? ramGen, String? supported) {
    if (supported == null || ramGen == null) return true;
    return supported.split('/').contains(ramGen);
  }

  /// Which PCIe generation a board's M.2 slot runs at, from its chipset.
  /// Only the chipsets the supplier confirmed are listed; anything else
  /// returns null and the speed note is skipped rather than guessed.
  static int? boardPcieGen(Product board) {
    final chipset = (board.attrs['chipset'] ?? '').toString().toUpperCase();
    if (chipset.startsWith('X870')) return 5;
    if (['B760', 'B860', 'B850'].contains(chipset)) return 4;
    if (['H610', 'B550'].contains(chipset)) return 3;
    return null;
  }

  /// Parts that can go in a slot given what has already been chosen.
  static List<Product> eligible(
      String slot, List<Product> all, Map<String, Product?> build) {
    // Repair-only stock is sold in the shop but never offered in a build.
    var list = all
        .where((p) => p.subcategory == slot && !p.excludeFromBuilder && p.inStock)
        .toList();

    final cpu = build['CPU'];
    final mobo = build['Motherboard'];

    if (slot == 'Motherboard' && cpu != null) {
      list = list.where((p) => p.socket == cpu.socket).toList();
    }
    if (slot == 'CPU' && mobo != null) {
      list = list.where((p) => p.socket == mobo.socket).toList();
    }
    if (slot == 'RAM') {
      final gen = mobo?.ramGen ?? cpu?.ramGen;
      if (gen != null) list = list.where((p) => ramGenFits(p.ramGen, gen)).toList();
      // Kits our own testing found don't work with this processor.
      if (cpu != null) {
        list = list
            .where((p) => !p.incompatibleSockets.contains(cpu.socket))
            .toList();
      }
    }
    // A cooler must mount on the socket AND be able to shift the heat.
    // A 65W stock cooler on a 219W Core i7 would cook it, so it isn't offered.
    if (slot == 'Cooler' && cpu != null) {
      list = list
          .where((p) =>
              p.sockets.contains(cpu.socket) && p.coolerRating >= cpu.tdp)
          .toList();
    }
    // A back-connector board only fits a case built for it.
    if (slot == 'Case' && mobo != null && mobo.attrs['backConnector'] == 'Yes') {
      list = list
          .where((p) => p.attrs['supportsBackConnector'] == 'Yes')
          .toList();
    }

    list.sort((a, b) => a.price.compareTo(b.price));
    return list;
  }

  /// Runs every rule and returns what it found.
  static List<Check> check(Map<String, Product?> build) {
    final checks = <Check>[];
    final cpu = build['CPU'];
    final cooler = build['Cooler'];
    final mobo = build['Motherboard'];
    final ram = build['RAM'];
    final gpu = build['GPU'];
    final psu = build['PSU'];
    final pcCase = build['Case'];
    final storage = build['Storage'];

    void critical(String t) => checks.add(Check(Level.critical, t));
    void warn(String t) => checks.add(Check(Level.warning, t));
    void pass(String t) => checks.add(Check(Level.pass, t));

    // ---- CRITICAL: parts that physically cannot work together ----

    if (cpu != null && mobo != null) {
      cpu.socket == mobo.socket
          ? pass('Socket match: CPU and motherboard are both ${cpu.socket}.')
          : critical(
              'Socket mismatch: CPU is ${cpu.socket} but motherboard is ${mobo.socket}.');
    }

    if (ram != null && cpu != null && ram.incompatibleSockets.contains(cpu.socket)) {
      critical('${ram.name} does not work with ${cpu.socket} processors. '
          'We confirmed this by testing in the shop — it is not listed in the specs. '
          'Please pick another kit.');
    }

    if (ram != null && (mobo != null || cpu != null)) {
      final boardGen = mobo?.ramGen ?? cpu?.ramGen;
      ramGenFits(ram.ramGen, boardGen)
          ? pass('Memory type match: ${ram.ramGen} RAM fits your board.')
          : critical(
              'Memory type mismatch: board needs $boardGen but you picked ${ram.ramGen} RAM.');
    }

    if (cooler != null && cpu != null) {
      cooler.sockets.contains(cpu.socket)
          ? pass('Cooler mounting OK: ${cooler.name} supports ${cpu.socket}.')
          : critical('Cooler will not mount: ${cooler.name} does not support ${cpu.socket}.');
    }

    // Cooling is a hard limit — the picker already hides coolers that cannot
    // cope, so this only fires on a build loaded from earlier.
    if (cooler != null && cpu != null) {
      cooler.coolerRating >= cpu.tdp
          ? pass('Cooling OK: ${cooler.name} handles ${cooler.coolerRating}W, '
              'the ${cpu.name} needs ${cpu.tdp}W.')
          : critical('Cooler is too small for this processor: the ${cpu.name} puts out '
              '${cpu.tdp}W but ${cooler.name} only handles ${cooler.coolerRating}W. '
              'Please pick a cooler rated for ${cpu.tdp}W or more.');
    }

    if (cpu != null && cpu.attrs['igpu'] == 'No') {
      gpu != null
          ? pass('Graphics OK: the ${cpu.name} has no built-in graphics, '
              'and you have added the ${gpu.name}.')
          : critical('Graphics card required: the ${cpu.name} has NO integrated '
              'graphics, so this PC will not display anything without one.');
    }

    if (pcCase != null && mobo != null) {
      final fits = pcCase.supportedFormFactors;
      fits.contains(mobo.formFactor)
          ? pass('Case fits board: ${pcCase.name} accepts ${mobo.formFactor} boards.')
          : critical('Board too big for case: ${mobo.name} is ${mobo.formFactor}, '
              'but ${pcCase.name} only fits ${fits.join(" / ")} boards.');
    }

    if (pcCase != null && mobo != null && mobo.attrs['backConnector'] == 'Yes') {
      pcCase.attrs['supportsBackConnector'] == 'Yes'
          ? pass('Back-connector pairing OK: ${pcCase.name} supports ${mobo.name}.')
          : critical('Back-connector mismatch: ${mobo.name} routes its cables behind '
              'the board, which ${pcCase.name} cannot take.');
    }

    if (pcCase != null && gpu != null) {
      gpu.length <= pcCase.maxGpuLength
          ? pass('Graphics card fits: ${gpu.length}mm card in a case that takes '
              'up to ${pcCase.maxGpuLength}mm.')
          : critical('Graphics card too long: ${gpu.name} is ${gpu.length}mm but '
              '${pcCase.name} only fits up to ${pcCase.maxGpuLength}mm.');
    }

    if (psu != null && (cpu != null || gpu != null)) {
      final n = psuNeed(cpu, gpu);
      final why = n.byCard
          ? '${gpu!.name} needs at least a ${n.needed}W supply'
          : 'this build draws about ${n.draw}W (CPU ${n.cpuWatts}W + GPU '
              '${n.gpuWatts}W + ${otherPartsWattage}W other parts), so it needs '
              'at least ${n.needed}W with headroom';
      psu.wattage >= n.needed
          ? pass('Power OK: $why, and your PSU is ${psu.wattage}W.')
          : critical('PSU too small: $why, but your PSU is only '
              '${psu.wattage}W. Pick a ${n.needed}W or bigger supply.');
    }

    // We stock no SFX supplies, so a small build still needs a case that
    // takes a full-size ATX unit. Every case we carry does.
    if (mobo != null && mobo.formFactor == 'mini-ITX' && psu != null && pcCase != null) {
      pcCase.attrs['acceptsAtxPsu'] == 'Yes'
          ? pass('Power supply fits: we only stock full-size ATX supplies, '
              'and ${pcCase.name} takes one.')
          : critical('${pcCase.name} needs a small SFX power supply, and we do not '
              'stock any at the moment.');
    }

    // ---- WARNINGS: it builds and runs, just not at its best ----

    if (storage != null && mobo != null && storage.attrs['pcieGen'] != null) {
      final driveGen = storage._pcieGen;
      final boardGen = boardPcieGen(mobo);
      if (boardGen != null && driveGen > boardGen) {
        warn('${storage.name} is a Gen $driveGen drive and ${mobo.name} runs its '
            'M.2 slot at Gen $boardGen. It is fully compatible and will work '
            'perfectly — it just will not reach its top speed.');
      }
      if (driveGen == 5 && storage.attrs['heatsink'] == 'No') {
        warn('Gen 5 drives run hot: check ${mobo.name} has its own M.2 heat shield, '
            'or pick a drive with a heatsink built in.');
      }
    }

    if (psu != null && gpu != null &&
        psu.attrs['connector12VHPWR'] == 'No' &&
        (gpu.attrs['chip'] ?? '').toString().startsWith('RTX 5')) {
      warn('${psu.name} has no 12VHPWR connector, which the ${gpu.attrs['chip']} '
          'expects. It will work using the adapter in the card\'s box, but a supply '
          'with a native lead is tidier.');
    }

    // ---- Good news ----
    if (cpu != null && cpu.attrs['coolerIncluded'] == 'Yes' && cooler == null) {
      pass('The ${cpu.name} comes with a cooler in the box, so a separate '
          'cooler is optional.');
    }

    return checks;
  }

  /// Can this build go in the basket?
  static bool canOrder(Map<String, Product?> build, List<Check> checks) {
    final coolerOptional = build['CPU']?.attrs['coolerIncluded'] == 'Yes';
    final allPicked = slots.every((slot) {
      if (slot == 'Cooler' && coolerOptional) return true;
      return build[slot] != null;
    });
    final noCriticals = !checks.any((c) => c.level == Level.critical);
    return allPicked && noCriticals;
  }

  static double subtotal(Map<String, Product?> build) {
    double total = 0;
    for (final slot in slots) {
      total += build[slot]?.price ?? 0;
    }
    return total;
  }
}

extension on Product {
  int get _pcieGen {
    final v = attrs['pcieGen'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }
}

/// What [Compatibility.psuNeed] works out for a build.
class PsuNeed {
  final int cpuWatts;
  final int gpuWatts;
  final int draw;
  final int needed;
  /// True when the card maker's recommendation, not the draw, set [needed].
  final bool byCard;
  const PsuNeed({
    required this.cpuWatts,
    required this.gpuWatts,
    required this.draw,
    required this.needed,
    required this.byCard,
  });
}
