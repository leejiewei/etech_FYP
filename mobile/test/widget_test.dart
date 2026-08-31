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

  group('PCIe generation from the chipset', () {
    test('reads the ones the supplier confirmed', () {
      expect(Compatibility.boardPcieGen(make(1, 'b', 'Motherboard', {'chipset': 'H610'})), 3);
      expect(Compatibility.boardPcieGen(make(2, 'b', 'Motherboard', {'chipset': 'B760'})), 4);
      expect(Compatibility.boardPcieGen(make(3, 'b', 'Motherboard', {'chipset': 'X870E'})), 5);
    });

    test('returns null rather than guessing at an unlisted chipset', () {
      expect(Compatibility.boardPcieGen(make(4, 'b', 'Motherboard', {'chipset': 'Z790'})), isNull);
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

    test('a newer drive in an older slot only warns, since it still works', () {
      final checks = Compatibility.check({
        'Motherboard': make(1, 'Board', 'Motherboard', {'chipset': 'H610'}),
        'Storage': make(2, 'Gen 5 SSD', 'Storage', {'pcieGen': 5, 'heatsink': 'No'}),
      });
      expect(checks.any((c) => c.level == Level.warning), isTrue);
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
}
