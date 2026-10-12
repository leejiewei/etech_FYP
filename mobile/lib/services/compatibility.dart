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

  /// A cooler rated at 60% or more of the CPU's power copes, with the CPU
  /// running hotter. Below that it is critical. Matches COOLER_MIN_SHARE.
  static const double coolerMinShare = 0.6;

  /// Total memory in GB and the number of sticks, from the kit ("2 x 16GB").
  static ({int? sticks, int totalGb})? ramKit(Product ram) {
    final m = RegExp(r'(\d+)\s*x\s*(\d+)\s*GB', caseSensitive: false)
        .firstMatch((ram.attrs['kit'] ?? '').toString());
    if (m != null) {
      final n = int.parse(m.group(1)!);
      return (sticks: n, totalGb: n * int.parse(m.group(2)!));
    }
    final cap = int.tryParse(
        RegExp(r'\d+').stringMatch((ram.attrs['capacity'] ?? '').toString()) ?? '');
    return cap == null ? null : (sticks: null, totalGb: cap);
  }

  /// A supply should not run flat out: the draw plus a quarter again.
  static const double psuHeadroom = 1.25;

  /// How big a power supply a build needs: the larger of the supply the
  /// shop recommends for a full rig with the card (shopPsu, else NVIDIA's
  /// or AMD's own recommendedPsu) and the estimated draw plus headroom,
  /// rounded up to the next 50W. Matches psuNeedFor() in web/js/products.js.
  static PsuNeed psuNeed(Product? cpu, Product? gpu) {
    final cpuWatts = cpu?.tdp ?? 0;
    final gpuWatts = gpu?.power ?? 0;
    final draw = cpuWatts + gpuWatts + otherPartsWattage;
    final withHeadroom = ((draw * psuHeadroom) / 50).ceil() * 50;
    final makerPsu = gpu?.recommendedPsu ?? 0;
    final shopPsu = gpu?.shopPsu ?? 0;
    final cardMin = shopPsu > 0 ? shopPsu : makerPsu;
    return PsuNeed(
      cpuWatts: cpuWatts,
      gpuWatts: gpuWatts,
      draw: draw,
      makerPsu: makerPsu,
      maker: (gpu?.attrs['chip'] ?? '').toString().startsWith('RX ') ? 'AMD' : 'NVIDIA',
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
    // The Strix Z790-I's ROG Hyper M.2 card in the box adds a Gen 5 slot.
    if (chipset == 'Z790') return 5;
    if (['B760', 'B860', 'B850', 'A620', 'B650', 'H810'].contains(chipset)) return 4;
    if (['H610', 'B550', 'A520', 'H510'].contains(chipset)) return 3;
    return null;
  }

  /// Intel or AMD, from the socket name.
  static String _maker(String? socket) =>
      (socket ?? '').startsWith('AM') ? 'AMD' : 'Intel';

  /// True for the AM4 APUs (the "G" chips), which cut the graphics slot
  /// to Gen 3 on any board.
  static bool _isAm4Apu(Product? cpu) =>
      cpu != null && cpu.socket == 'AM4' && RegExp(r'\d{4}G').hasMatch(cpu.name);

  /// Which PCIe generation the board's graphics card slot runs at.
  /// Matches boardGpuSlotGen() in web/js/build.js.
  static int? boardGpuSlotGen(Product board, Product? cpu) {
    final chipset = (board.attrs['chipset'] ?? '').toString().toUpperCase();
    if (_isAm4Apu(cpu)) return 3;
    if (['H61', 'H81'].contains(chipset)) return 2;
    if (['A520', 'H110', 'H310', 'H510'].contains(chipset)) return 3;
    if (['B550', 'A620', 'B650', 'H610', 'B760', 'H810', 'B850', 'B860']
        .contains(chipset)) {
      return 4;
    }
    if (chipset == 'Z790' || chipset.startsWith('X870')) return 5;
    return null;
  }

  /// The PCIe generation and lane count a graphics card is built for.
  static ({int gen, int lanes})? gpuPcie(Product gpu) {
    final chip = (gpu.attrs['chip'] ?? '').toString();
    if (RegExp(r'^RTX 50|^RX 90').hasMatch(chip)) {
      return (gen: 5, lanes: RegExp(r'^RTX 50(50|60)').hasMatch(chip) ? 8 : 16);
    }
    if (chip.startsWith('RTX 30')) {
      return (gen: 4, lanes: chip == 'RTX 3050' ? 8 : 16);
    }
    return null;
  }

  /// Rough gaming tiers, so a badly out-of-step CPU and GPU can be spotted.
  /// Same tables as CPU_TIERS / GPU_TIERS in web/js/build.js.
  static final List<(RegExp, int)> _cpuTiers = [
    (RegExp(r'3200G|3400G'), 1),
    (RegExp(r'Ryzen 5 5500|Ryzen 5 5600'), 2),
    (RegExp(r'7800X3D|9800X3D|9950X3D'), 5),
    (RegExp(r'7500F|i5-14400|Ultra 5 225\b|5700X|i7-12700'), 3),
    (RegExp(r'7600X|9600X|7500X3D|5800X3D|i5-14600K|245K|i7-14700|265K|270K|9700X|9900X|285K|i9-14900'), 4),
  ];
  static final List<(RegExp, int)> _gpuTiers = [
    (RegExp(r'^GT '), 0),
    (RegExp(r'^GTX 1650|^RTX 3050'), 1),
    (RegExp(r'^RTX 5050|^RTX 5060$|^RX 9060'), 2),
    (RegExp(r'^RTX 5060 Ti|^RTX 5070$'), 3),
    (RegExp(r'^RTX 5070 Ti|^RX 9070|^RTX 5080'), 4),
    (RegExp(r'^RTX 5090'), 5),
  ];
  static int? _tierOf(List<(RegExp, int)> table, String text) {
    for (final row in table) {
      if (row.$1.hasMatch(text)) return row.$2;
    }
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
    // A cooler must mount on the socket AND cope with most of the heat.
    // A 65W stock cooler on a 219W Core i7 would cook it, so it isn't
    // offered; one a little under is offered with a warning.
    if (slot == 'Cooler' && cpu != null) {
      list = list
          .where((p) =>
              p.sockets.contains(cpu.socket) &&
              p.coolerRating >= cpu.tdp * coolerMinShare)
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
          : critical('Socket mismatch: CPU is ${cpu.socket} but motherboard is '
              '${mobo.socket}${_maker(cpu.socket) != _maker(mobo.socket) ? ' — an ${_maker(cpu.socket)} processor cannot go in an ${_maker(mobo.socket)} board.' : ', so this processor will not fit the board.'}');
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

    // Cooling. Well under the CPU's power is critical (the picker hides
    // those, so that only fires on a build loaded from earlier); a little
    // under still works, so it is a warning.
    if (cooler != null && cpu != null) {
      if (cooler.coolerRating >= cpu.tdp) {
        pass('Cooling OK: ${cooler.name} handles ${cooler.coolerRating}W, '
            'the ${cpu.name} needs ${cpu.tdp}W.');
      } else if (cooler.coolerRating < cpu.tdp * coolerMinShare) {
        critical('Cooler is too small for this processor: the ${cpu.name} puts out '
            '${cpu.tdp}W but ${cooler.name} only handles ${cooler.coolerRating}W. '
            'Please pick a cooler rated for ${cpu.tdp}W or more.');
      } else {
        warn('Cooler below the recommended size: the ${cpu.name} can put out '
            '${cpu.tdp}W and ${cooler.name} handles ${cooler.coolerRating}W. It will '
            'work, but under heavy load the processor runs hotter and boosts less. '
            'A cooler rated for ${cpu.tdp}W or more keeps it at full speed.');
      }
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

    // Below the estimated full-load draw the PC shuts down under load:
    // critical. Covering the draw but short of the recommended size still
    // runs: only a warning.
    if (psu != null && (cpu != null || gpu != null)) {
      final n = psuNeed(cpu, gpu);
      final why = n.byCard
          ? 'we recommend at least ${n.needed}W for a full rig with the ${gpu!.name}'
              '${n.makerPsu > 0 && n.makerPsu < n.needed ? " (${n.maker}'s own figure is ${n.makerPsu}W)" : ''}'
          : 'this build draws about ${n.draw}W (CPU ${n.cpuWatts}W + GPU '
              '${n.gpuWatts}W + ${otherPartsWattage}W other parts), so it needs '
              'at least ${n.needed}W with headroom';
      if (psu.wattage >= n.needed) {
        pass('Power OK: $why, and your PSU is ${psu.wattage}W.');
      } else if (psu.wattage < n.draw) {
        critical('PSU too small: this build draws about ${n.draw}W at full load, '
            'but your PSU is only ${psu.wattage}W, so the PC would shut down in '
            'games. Pick a ${n.needed}W or bigger supply.');
      } else {
        warn('PSU below the recommended size: $why, and your PSU is '
            '${psu.wattage}W. It covers the estimated ${n.draw}W draw, so it will '
            'run, but with little spare for load spikes. A ${n.needed}W supply '
            'is the safer pick.');
      }
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

    // Memory: one stick runs single channel; too little memory stutters.
    if (ram != null) {
      final kit = ramKit(ram);
      if (kit != null && kit.sticks == 1) {
        warn('${ram.name} is a single stick, so memory runs in single channel — '
            'noticeably slower in games and with built-in graphics. Two matching '
            'sticks (a 2 x kit) run in dual channel.');
      }
      if (kit != null && kit.totalGb < 16) {
        warn('${kit.totalGb}GB of memory is tight for Windows 11 and current games '
            'and apps. 16GB or more is the comfortable minimum.');
      }
    }

    // A hard drive as the only drive makes the whole PC feel slow.
    if (storage != null && storage.attrs['driveType'] == 'HDD') {
      warn('${storage.name} is a hard drive, so Windows and games will load slowly. '
          'It is great for bulk storage, but an SSD as the main drive makes the '
          'whole PC feel much faster.');
    }

    // A case with no fans needs some added, or the parts run hot.
    if (pcCase != null &&
        (pcCase.attrs['fansIncluded'] ?? '').toString().toLowerCase() == 'none') {
      warn('${pcCase.name} comes with no fans. The PC will run hot without them, '
          'so add at least two case fans (one in, one out).');
    }

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

    // A newer graphics card in a Gen 3 (or older) slot still works, with
    // less bandwidth. The x8 cards feel it most.
    if (gpu != null && mobo != null) {
      final card = gpuPcie(gpu);
      final slotGen = boardGpuSlotGen(mobo, cpu);
      if (card != null && slotGen != null && slotGen <= 3 && card.gen > slotGen) {
        warn('${gpu.name} is a PCIe Gen ${card.gen} card, but its slot runs at '
            'Gen $slotGen${_isAm4Apu(cpu) ? ' with the ${cpu!.name}' : ' on ${mobo.name}'}. '
            'It is fully compatible, but '
            '${card.lanes == 8 ? 'this card only uses 8 lanes, so it can lose a noticeable amount of performance in some games.' : 'it can lose a little performance.'}'
            '${_isAm4Apu(cpu) ? ' A processor without a "G" in its name runs the slot at full speed.' : ' A board with a Gen 4 or newer slot gets the most out of it.'}');
      }
    }

    // A processor and graphics card far apart in power.
    if (cpu != null && gpu != null) {
      final cpuTier = _tierOf(_cpuTiers, cpu.name);
      final gpuTier = _tierOf(_gpuTiers, (gpu.attrs['chip'] ?? '').toString());
      if (cpuTier != null && gpuTier != null) {
        if (gpuTier - cpuTier >= 2) {
          warn('Bottleneck: the ${cpu.name} will hold back the ${gpu.name} in '
              'games, so you would be paying for graphics power you cannot use. '
              'A faster processor, or a cheaper card, would balance this build better.');
        } else if (gpuTier >= 1 && cpuTier - gpuTier >= 3) {
          warn('Bottleneck: the ${gpu.name} will hold back the ${cpu.name} in '
              'games. Fine for work and light gaming, but a stronger graphics '
              'card would make far better use of this processor.');
        }
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
  /// NVIDIA's or AMD's own figure for the card, and which of the two.
  final int makerPsu;
  final String maker;
  /// True when the card maker's recommendation, not the draw, set [needed].
  final bool byCard;
  const PsuNeed({
    required this.cpuWatts,
    required this.gpuWatts,
    required this.draw,
    required this.needed,
    required this.makerPsu,
    required this.maker,
    required this.byCard,
  });
}
