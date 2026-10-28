// Checks the compatibility rules on their own, without needing a server.
//
// These are the rules that stop a customer buying parts that cannot work
// together, so they are the most valuable thing to have tests for.
//
// Run with:  flutter test

import 'package:flutter_test/flutter_test.dart';
import 'package:etech_mobile/models/product.dart';
import 'package:etech_mobile/services/compatibility.dart';

/// Builds a product from a small map, so each test only states what matters.
Product make(int id, String name, String? sub, Map<String, dynamic> attrs,
    {double price = 100, String stock = 'in'}) {
  return Product(
    id: id,
    name: name,
    brand: 'Test',
    category: 'Components',
    subcategory: sub,
    price: price,
    stock: stock,
    description: '',
    imgSlug: 'default',
    attrs: attrs,
    excludeFromBuilder: false,
  );
}

void main() {
  group('memory type', () {
    test('a board taking either type accepts both', () {
      expect(Compatibility.ramGenFits('DDR4', 'DDR4/DDR5'), isTrue);
      expect(Compatibility.ramGenFits('DDR5', 'DDR4/DDR5'), isTrue);
    });

    test('a DDR5 board refuses DDR4', () {
      expect(Compatibility.ramGenFits('DDR4', 'DDR5'), isFalse);
    });
  });

  group('compatibility checks', () {
    test('a mismatched socket is critical', () {
      final checks = Compatibility.check({
        'CPU': make(1, 'CPU', 'CPU', {'socket': 'AM5', 'tdp': 65}),
        'Motherboard': make(2, 'Board', 'Motherboard', {'socket': 'LGA1700'}),
      });
      expect(checks.any((c) => c.level == Level.critical), isTrue);
    });

    test('a CPU with no built-in graphics needs a card', () {
      final checks = Compatibility.check({
        'CPU': make(1, 'CPU', 'CPU', {'socket': 'AM5', 'tdp': 65, 'igpu': 'No'}),
      });
      expect(
          checks.any((c) =>
              c.level == Level.critical && c.text.contains('Graphics card required')),
          isTrue);
    });

    test('an undersized cooler is critical, not a warning', () {
      final checks = Compatibility.check({
        'CPU': make(1, 'Core i7', 'CPU', {'socket': 'LGA1700', 'tdp': 219}),
        'Cooler': make(2, 'Stock cooler', 'Cooler',
            {'sockets': ['LGA1700'], 'coolerRating': 65}),
      });
      expect(
          checks.any((c) =>
              c.level == Level.critical && c.text.contains('too small')),
          isTrue);
    });

    // Since 15 Oct the rule warnings are gone and eTech AI's review says
    // what is worth knowing; the checker only blocks builds that will not
    // work, and a newer drive in an older slot still works.
    test('a newer drive in an older slot is not critical, since it still works', () {
      final checks = Compatibility.check({
        'Motherboard': make(1, 'Board', 'Motherboard', {'chipset': 'H610'}),
        'Storage': make(2, 'Gen 5 SSD', 'Storage', {'pcieGen': 5, 'heatsink': 'No'}),
      });
      expect(checks.any((c) => c.level == Level.critical), isFalse);
    });

    test('a full ATX board will not go in an mATX case', () {
      final checks = Compatibility.check({
        'Motherboard': make(1, 'ATX board', 'Motherboard', {'formFactor': 'ATX'}),
        'Case': make(2, 'Small case', 'Case', {
          'supportedFormFactors': ['mATX', 'mini-ITX'],
          'maxGpuLength': 320
        }),
      });
      expect(
          checks.any((c) =>
              c.level == Level.critical && c.text.contains('too big for case')),
          isTrue);
    });
  });

  group('choosing parts', () {
    final catalogue = [
      make(1, 'Hot CPU', 'CPU', {'socket': 'LGA1700', 'tdp': 219}),
      make(2, 'Stock cooler', 'Cooler', {'sockets': ['LGA1700'], 'coolerRating': 65}),
      make(3, 'Big cooler', 'Cooler', {'sockets': ['LGA1700'], 'coolerRating': 250}),
      make(4, 'Wrong socket cooler', 'Cooler', {'sockets': ['AM5'], 'coolerRating': 300}),
    ];

    test('only offers coolers that fit AND can cope with the heat', () {
      final options = Compatibility.eligible(
          'Cooler', catalogue, {'CPU': catalogue[0]});
      expect(options.length, 1);
      expect(options.first.name, 'Big cooler');
    });
  });
  // Part 13.1 (28 Oct): the builder's cooler, graphics and power rules,
  // one test per case the FYP brief lists. Same rules as slotRequirement()
  // and compatibilityChecks() in web/js/build.js.
  group('builder scenarios', () {
    final boxed = make(10, 'Ryzen 5 5500', 'CPU', {
      'socket': 'AM4', 'tdp': 65, 'coolerIncluded': 'Yes', 'igpu': 'No'});
    final noCooler = make(11, 'Ryzen 7 9700X', 'CPU', {
      'socket': 'AM5', 'tdp': 65, 'coolerIncluded': 'No', 'igpu': 'Yes'});
    final officeApu = make(12, 'Ryzen 5 3400G', 'CPU', {
      'socket': 'AM4', 'tdp': 65, 'coolerIncluded': 'Yes', 'igpu': 'Yes'});
    final unknown = make(13, 'Mystery CPU', 'CPU', {'socket': 'AM5', 'tdp': 65});

    Map<String, Product?> fullBuild(Product cpu, {Product? cooler, Product? gpu, Product? psu}) => {
          'CPU': cpu,
          'Cooler': cooler,
          'Motherboard': make(20, 'Board', 'Motherboard',
              {'socket': cpu.attrs['socket'], 'formFactor': 'ATX'}),
          'RAM': make(21, 'RAM', 'RAM', {}),
          'GPU': gpu,
          'Storage': make(22, 'SSD', 'Storage', {}),
          'PSU': psu ?? make(23, '750W', 'PSU', {'wattage': 750}),
          // Every board and case in the catalogue has these (checked 28 Oct).
          'Case': make(24, 'Case', 'Case',
              {'supportedFormFactors': ['ATX', 'mATX'], 'maxGpuLength': 400}),
        };

    test('a CPU with a cooler in the box makes the cooler optional', () {
      expect(Compatibility.requirement('Cooler', boxed).$1, 'optional');
      final build = fullBuild(boxed, gpu: make(30, 'RTX 3050', 'GPU', {'power': 130}));
      expect(Compatibility.missing(build), isNot(contains('Cooler')));
    });

    test('a CPU without one requires a cooler, and the build is incomplete without it', () {
      expect(Compatibility.requirement('Cooler', noCooler).$1, 'required');
      final build = fullBuild(noCooler);
      expect(Compatibility.missing(build), contains('Cooler'));
      expect(Compatibility.canOrder(build, Compatibility.check(build)), isFalse);
    });

    test('a CPU with no record either way is never assumed to have a cooler', () {
      final need = Compatibility.requirement('Cooler', unknown);
      expect(need.$1, 'required');
      expect(need.$2, contains("can't confirm"));
    });

    test('a cooler for the wrong socket is critical', () {
      final checks = Compatibility.check({
        'CPU': noCooler,
        'Cooler': make(31, 'AM4-only cooler', 'Cooler', {'sockets': ['AM4'], 'coolerRating': 150}),
      });
      expect(checks.any((c) => c.level == Level.critical), isTrue);
    });

    test('an RTX 5090 on a 600W supply is critical and cannot be ordered', () {
      final build = fullBuild(noCooler,
          cooler: make(32, 'Tower', 'Cooler', {'sockets': ['AM5'], 'coolerRating': 200}),
          gpu: make(33, 'RTX 5090', 'GPU', {'power': 575, 'recommendedPsu': 1000}),
          psu: make(34, '600W', 'PSU', {'wattage': 600}));
      final checks = Compatibility.check(build);
      expect(checks.any((c) => c.level == Level.critical && c.text.contains('PSU too small')), isTrue);
      expect(Compatibility.canOrder(build, checks), isFalse);
    });

    test('a compatible gaming PC can be ordered', () {
      final build = fullBuild(noCooler,
          cooler: make(35, 'Tower', 'Cooler', {'sockets': ['AM5'], 'coolerRating': 200}),
          gpu: make(36, 'RTX 5070', 'GPU', {'power': 250, 'recommendedPsu': 650}),
          psu: make(37, '850W', 'PSU', {'wattage': 850}));
      final checks = Compatibility.check(build);
      expect(Compatibility.missing(build), isEmpty);
      expect(Compatibility.canOrder(build, checks), isTrue);
    });

    test('an office PC on built-in graphics needs no card and no extra cooler', () {
      final build = fullBuild(officeApu, psu: make(38, '450W', 'PSU', {'wattage': 450}));
      expect(Compatibility.requirement('GPU', officeApu).$1, 'optional');
      expect(Compatibility.missing(build), isEmpty);
      expect(Compatibility.counted(build).length, 6);
      expect(Compatibility.canOrder(build, Compatibility.check(build)), isTrue);
    });

    test('a CPU without built-in graphics needs a graphics card', () {
      final build = fullBuild(boxed);
      expect(Compatibility.missing(build), contains('GPU'));
    });
  });
}
