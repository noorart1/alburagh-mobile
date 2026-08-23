import 'package:flutter/material.dart';
import 'package:country_picker/country_picker.dart';
import '../core/theme/app_colors.dart';

/// A tap-to-select country field. Displays the localized country name but
/// keeps the underlying [controller] value as an ISO 3166-1 alpha-2 code
/// (e.g. "IQ"), since that's what WooCommerce expects for shipping/tax and
/// what the Iraq-only COD check on the backend compares against.
class CountryPickerField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const CountryPickerField({
    super.key,
    required this.controller,
    this.label = 'الدولة',
  });

  static Country? _countryForCode(String code) {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return null;
    try {
      return CountryService().findByCode(trimmed.toUpperCase());
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final country = _countryForCode(value.text);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Matches _ProfileTextField's label-above style so a field
            // placed next to it in a Row (e.g. postcode + country) lines
            // up instead of one having a floating label and the other not.
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => showCountryPicker(
                context: context,
                showPhoneCode: false,
                onSelect: (picked) => controller.text = picked.countryCode,
              ),
              child: InputDecorator(
                // No border override -- inherits the app's shared
                // InputDecorationTheme, same as every other field.
                decoration: InputDecoration(
                  prefixIcon: country != null
                      ? Center(
                          widthFactor: 1,
                          child: Text(
                            country.flagEmoji,
                            style: const TextStyle(fontSize: 20),
                          ),
                        )
                      : const Icon(Icons.flag_outlined),
                  suffixIcon: const Icon(Icons.arrow_drop_down),
                ),
                child: Text(
                  country?.name ??
                      (value.text.isEmpty ? 'اختر الدولة' : value.text),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
