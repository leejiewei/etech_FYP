import 'package:flutter/material.dart';
import '../services/shop.dart';

/// Student, Gamer or Enterprise, for the sign-up and profile forms.
///
/// What the home screen's "Picked for you" leans on before an account has
/// any history of its own. The list is Shop.shopperRoles, the same three
/// the database accepts.
class RoleDropdown extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  final String label;

  const RoleDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'I am shopping as a…',
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: Shop.isShopperRole(value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      hint: const Text('Choose one'),
      items: [
        for (final r in Shop.shopperRoles)
          DropdownMenuItem(
            value: r.value,
            child: Text('${r.label}: ${r.hint}', overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
    );
  }
}
