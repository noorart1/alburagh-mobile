import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api_service.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../widgets/country_picker_field.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final ApiService _api = ApiService();

  static final Uri _originalCartUri = Uri.parse(
    'https://alburagh.com/%d8%b3%d9%84%d8%a9-%d8%a7%d9%84%d9%85%d8%b4%d8%aa%d8%b1%d9%8a%d8%a7%d8%aa/',
  );

  final _billingFormKey = GlobalKey<FormState>();
  final _shippingFormKey = GlobalKey<FormState>();

  final _billingFirstNameController = TextEditingController();
  final _billingLastNameController = TextEditingController();
  final _billingPhoneController = TextEditingController();
  final _billingEmailController = TextEditingController();
  final _billingAddress1Controller = TextEditingController();
  final _billingAddress2Controller = TextEditingController();
  final _billingCityController = TextEditingController();
  final _billingStateController = TextEditingController();
  final _billingPostcodeController = TextEditingController();
  final _billingCountryController = TextEditingController();

  final _shippingFirstNameController = TextEditingController();
  final _shippingLastNameController = TextEditingController();
  final _shippingPhoneController = TextEditingController();
  final _shippingAddress1Controller = TextEditingController();
  final _shippingAddress2Controller = TextEditingController();
  final _shippingCityController = TextEditingController();
  final _shippingStateController = TextEditingController();
  final _shippingPostcodeController = TextEditingController();
  final _shippingCountryController = TextEditingController();

  bool _shippingSameAsBilling = true;
  bool _checkoutLoading = false;
  String? _selectedPaymentMethod;

  static const _iraqCountryValues = {'IQ', 'IRAQ', 'العراق'};

  // Gateway IDs of the WooCommerce PayPal Payments plugin active on
  // alburagh.com (see WooCommerce > Settings > Payments): 'ppcp-gateway' is
  // the PayPal smart-button gateway, 'ppcp-credit-card-gateway' is the
  // "Standard Card Button" (Visa/Mastercard) gateway.
  static const _paypalGateway = (id: 'ppcp-gateway', title: 'الدفع عبر PayPal');
  static const _cardGateway = (
    id: 'ppcp-credit-card-gateway',
    title: 'الدفع بواسطة بطاقة الفيزا/الماستركارد',
  );

  bool _isIraq(String country) =>
      _iraqCountryValues.contains(country.trim().toUpperCase());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<CartProvider>().loadCart();
        _prefillFromProfile();
      }
    });
  }

  @override
  void dispose() {
    _billingFirstNameController.dispose();
    _billingLastNameController.dispose();
    _billingPhoneController.dispose();
    _billingEmailController.dispose();
    _billingAddress1Controller.dispose();
    _billingAddress2Controller.dispose();
    _billingCityController.dispose();
    _billingStateController.dispose();
    _billingPostcodeController.dispose();
    _billingCountryController.dispose();
    _shippingFirstNameController.dispose();
    _shippingLastNameController.dispose();
    _shippingPhoneController.dispose();
    _shippingAddress1Controller.dispose();
    _shippingAddress2Controller.dispose();
    _shippingCityController.dispose();
    _shippingStateController.dispose();
    _shippingPostcodeController.dispose();
    _shippingCountryController.dispose();
    super.dispose();
  }

  Future<void> _prefillFromProfile() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn || auth.user == null) return;

    final fallbackFirstName = auth.user!.name.trim().split(' ').first;
    final fallbackLastName = auth.user!.name.trim().split(' ').length > 1
        ? auth.user!.name.trim().split(' ').skip(1).join(' ')
        : '';

    _billingFirstNameController.text = fallbackFirstName;
    _billingLastNameController.text = fallbackLastName;
    _billingEmailController.text = auth.user!.email;

    try {
      final token = auth.user!.token ?? '';
      if (token.isEmpty) return;
      final profile = await _api.getProfile(token);
      if (!mounted) return;

      final billing = profile['billing'] as Map<String, dynamic>? ?? {};
      final shipping = profile['shipping'] as Map<String, dynamic>? ?? {};

      String pick(Map<String, dynamic> m, String key) =>
          m[key]?.toString() ?? '';

      setState(() {
        if (pick(billing, 'first_name').isNotEmpty) {
          _billingFirstNameController.text = pick(billing, 'first_name');
        }
        if (pick(billing, 'last_name').isNotEmpty) {
          _billingLastNameController.text = pick(billing, 'last_name');
        }
        _billingPhoneController.text = pick(billing, 'phone');
        _billingAddress1Controller.text = pick(billing, 'address_1');
        _billingAddress2Controller.text = pick(billing, 'address_2');
        _billingCityController.text = pick(billing, 'city');
        _billingStateController.text = pick(billing, 'state');
        _billingPostcodeController.text = pick(billing, 'postcode');
        _billingCountryController.text = pick(billing, 'country');

        final shippingHasAddress = pick(shipping, 'address_1').isNotEmpty;
        _shippingSameAsBilling = !shippingHasAddress;

        if (shippingHasAddress) {
          _shippingFirstNameController.text = pick(shipping, 'first_name');
          _shippingLastNameController.text = pick(shipping, 'last_name');
          _shippingPhoneController.text = pick(shipping, 'phone');
          _shippingAddress1Controller.text = pick(shipping, 'address_1');
          _shippingAddress2Controller.text = pick(shipping, 'address_2');
          _shippingCityController.text = pick(shipping, 'city');
          _shippingStateController.text = pick(shipping, 'state');
          _shippingPostcodeController.text = pick(shipping, 'postcode');
          _shippingCountryController.text = pick(shipping, 'country');
        }
      });
    } catch (_) {
      // Keep the name/email fallback already set above; the checkout
      // form still works with the user typing the address manually.
    }
  }

  Map<String, dynamic> _addressPayload({
    required TextEditingController firstName,
    required TextEditingController lastName,
    required TextEditingController phone,
    required TextEditingController address1,
    required TextEditingController address2,
    required TextEditingController city,
    required TextEditingController state,
    required TextEditingController postcode,
    required TextEditingController country,
  }) {
    return {
      'first_name': firstName.text.trim(),
      'last_name': lastName.text.trim(),
      'phone': phone.text.trim(),
      'email': _billingEmailController.text.trim(),
      'address_1': address1.text.trim(),
      'address_2': address2.text.trim(),
      'city': city.text.trim(),
      'state': state.text.trim(),
      'postcode': postcode.text.trim(),
      'country': country.text.trim(),
    };
  }

  Future<void> _showClearConfirmation(CartProvider cart) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تفريغ السلة'),
        content: const Text('هل تريد إزالة جميع المنتجات من السلة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تفريغ'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await cart.clearCart();
      if (!mounted || cart.error != null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تفريغ السلة')),
      );
    }
  }

  Future<void> _openOriginalCart() async {
    if (await canLaunchUrl(_originalCartUri)) {
      await launchUrl(_originalCartUri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح صفحة السلة الأصلية')),
      );
    }
  }

  Future<void> _showCheckoutSheet(CartProvider cart) async {
    _selectedPaymentMethod = null;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final bottomInset = MediaQuery.of(context).viewInsets.bottom;

          return Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomInset),
            child: SingleChildScrollView(
              child: Form(
                key: _billingFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'إتمام الشراء',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _shippingSameAsBilling,
                      title: const Text('الشحن بنفس عنوان الفواتير'),
                      onChanged: (value) {
                        setState(() => _shippingSameAsBilling = value);
                        setSheetState(() {});
                      },
                    ),
                    const SizedBox(height: 12),
                    _CheckoutSection(
                      title: 'بيانات الفواتير',
                      children: [
                        _CheckoutTextField(
                          controller: _billingFirstNameController,
                          label: 'الاسم الأول',
                          validator: (value) =>
                              (value == null || value.trim().isEmpty)
                                  ? 'الحقل مطلوب'
                                  : null,
                        ),
                        _CheckoutTextField(
                          controller: _billingLastNameController,
                          label: 'اسم العائلة',
                        ),
                        _CheckoutTextField(
                          controller: _billingPhoneController,
                          label: 'رقم الهاتف',
                          keyboardType: TextInputType.phone,
                        ),
                        _CheckoutTextField(
                          controller: _billingEmailController,
                          label: 'البريد الإلكتروني',
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) =>
                              (value == null || value.trim().isEmpty)
                                  ? 'الحقل مطلوب'
                                  : null,
                        ),
                        _CheckoutTextField(
                          controller: _billingAddress1Controller,
                          label: 'العنوان 1',
                          validator: (value) =>
                              (value == null || value.trim().isEmpty)
                                  ? 'الحقل مطلوب'
                                  : null,
                        ),
                        _CheckoutTextField(
                          controller: _billingAddress2Controller,
                          label: 'العنوان 2',
                        ),
                        _CheckoutTextField(
                          controller: _billingCityController,
                          label: 'المدينة',
                        ),
                        _CheckoutTextField(
                          controller: _billingStateController,
                          label: 'المنطقة / المحافظة',
                        ),
                        _CheckoutTextField(
                          controller: _billingPostcodeController,
                          label: 'الرمز البريدي',
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: CountryPickerField(
                            controller: _billingCountryController,
                          ),
                        ),
                      ],
                    ),
                    if (!_shippingSameAsBilling) ...[
                      const SizedBox(height: 12),
                      Form(
                        key: _shippingFormKey,
                        child: _CheckoutSection(
                          title: 'بيانات الشحن',
                          children: [
                            _CheckoutTextField(
                              controller: _shippingFirstNameController,
                              label: 'الاسم الأول',
                              validator: (value) =>
                                  (value == null || value.trim().isEmpty)
                                      ? 'الحقل مطلوب'
                                      : null,
                            ),
                            _CheckoutTextField(
                              controller: _shippingLastNameController,
                              label: 'اسم العائلة',
                            ),
                            _CheckoutTextField(
                              controller: _shippingPhoneController,
                              label: 'رقم الهاتف',
                              keyboardType: TextInputType.phone,
                            ),
                            _CheckoutTextField(
                              controller: _shippingAddress1Controller,
                              label: 'العنوان 1',
                              validator: (value) =>
                                  (value == null || value.trim().isEmpty)
                                      ? 'الحقل مطلوب'
                                      : null,
                            ),
                            _CheckoutTextField(
                              controller: _shippingAddress2Controller,
                              label: 'العنوان 2',
                            ),
                            _CheckoutTextField(
                              controller: _shippingCityController,
                              label: 'المدينة',
                            ),
                            _CheckoutTextField(
                              controller: _shippingStateController,
                              label: 'المنطقة / المحافظة',
                            ),
                            _CheckoutTextField(
                              controller: _shippingPostcodeController,
                              label: 'الرمز البريدي',
                            ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: CountryPickerField(
                                controller: _shippingCountryController,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    AnimatedBuilder(
                      animation: Listenable.merge([
                        _billingCountryController,
                        _shippingCountryController,
                      ]),
                      builder: (context, _) {
                        final destinationCountry = _shippingSameAsBilling
                            ? _billingCountryController.text
                            : _shippingCountryController.text;
                        if (_isIraq(destinationCountry)) {
                          return const SizedBox.shrink();
                        }
                        return _CheckoutSection(
                          title: 'طريقة الدفع',
                          children: [
                            _PaymentMethodOption(
                              label: _paypalGateway.title,
                              icon: Icons.account_balance_wallet_outlined,
                              selected: _selectedPaymentMethod ==
                                  _paypalGateway.id,
                              onTap: () {
                                setState(
                                  () => _selectedPaymentMethod =
                                      _paypalGateway.id,
                                );
                                setSheetState(() {});
                              },
                            ),
                            const SizedBox(height: 8),
                            _PaymentMethodOption(
                              label: _cardGateway.title,
                              icon: Icons.credit_card,
                              selected: _selectedPaymentMethod ==
                                  _cardGateway.id,
                              onTap: () {
                                setState(
                                  () => _selectedPaymentMethod =
                                      _cardGateway.id,
                                );
                                setSheetState(() {});
                              },
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _checkoutLoading
                            ? null
                            : () async {
                                final billingValid = _billingFormKey.currentState?.validate() ?? false;
                                final shippingValid = _shippingSameAsBilling
                                    ? true
                                    : _shippingFormKey.currentState?.validate() ?? false;

                                if (!billingValid || !shippingValid) return;

                                final destinationCountryPreCheck =
                                    _shippingSameAsBilling
                                        ? _billingCountryController.text
                                        : _shippingCountryController.text;
                                if (!_isIraq(destinationCountryPreCheck) &&
                                    _selectedPaymentMethod == null) {
                                  ScaffoldMessenger.of(this.context)
                                      .showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('يرجى اختيار طريقة الدفع'),
                                    ),
                                  );
                                  return;
                                }

                                final messenger =
                                    ScaffoldMessenger.of(this.context);
                                setState(() => _checkoutLoading = true);
                                setSheetState(() {});

                                try {
                                  final billing = _addressPayload(
                                    firstName: _billingFirstNameController,
                                    lastName: _billingLastNameController,
                                    phone: _billingPhoneController,
                                    address1: _billingAddress1Controller,
                                    address2: _billingAddress2Controller,
                                    city: _billingCityController,
                                    state: _billingStateController,
                                    postcode: _billingPostcodeController,
                                    country: _billingCountryController,
                                  );

                                  final shipping = _shippingSameAsBilling
                                      ? billing
                                      : _addressPayload(
                                          firstName: _shippingFirstNameController,
                                          lastName: _shippingLastNameController,
                                          phone: _shippingPhoneController,
                                          address1: _shippingAddress1Controller,
                                          address2: _shippingAddress2Controller,
                                          city: _shippingCityController,
                                          state: _shippingStateController,
                                          postcode: _shippingPostcodeController,
                                          country: _shippingCountryController,
                                        );

                                  final destinationCountry =
                                      shipping['country'] as String? ?? '';
                                  final isIraq = _isIraq(destinationCountry);
                                  final selectedGateway =
                                      _selectedPaymentMethod ==
                                              _cardGateway.id
                                          ? _cardGateway
                                          : _paypalGateway;

                                  final result = await cart.checkout(
                                    billingAddress: billing,
                                    shippingAddress: shipping,
                                    paymentMethod: isIraq
                                        ? 'cod'
                                        : selectedGateway.id,
                                    paymentMethodTitle: isIraq
                                        ? 'الدفع عند الاستلام'
                                        : selectedGateway.title,
                                  );

                                  if (!context.mounted) return;
                                  Navigator.pop(context);

                                  if (!mounted) return;

                                  if (isIraq) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'تم إنشاء الطلب #${result['id'] ?? ''} بنجاح',
                                        ),
                                      ),
                                    );
                                  } else {
                                    final orderId = result['id'];
                                    final orderKey = result['order_key'];

                                    if (orderId == null || orderKey == null) {
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'تم إنشاء الطلب لكن تعذر فتح صفحة الدفع، '
                                            'يرجى المتابعة من صفحة "طلباتي" أو الموقع مباشرة',
                                          ),
                                        ),
                                      );
                                      return;
                                    }

                                    final payUri = Uri.parse(
                                      'https://alburagh.com/checkout/order-pay/$orderId/'
                                      '?pay_for_order=true&key=$orderKey',
                                    );
                                    if (await canLaunchUrl(payUri)) {
                                      await launchUrl(
                                        payUri,
                                        mode: LaunchMode.externalApplication,
                                      );
                                    }
                                    if (!mounted) return;
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'تم إنشاء الطلب #$orderId، '
                                          'أكمل الدفع عبر الموقع في الصفحة التي فُتحت',
                                        ),
                                      ),
                                    );
                                  }
                                } catch (_) {
                                  if (!mounted) return;
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(cart.error ?? 'فشل إتمام الطلب'),
                                    ),
                                  );
                                } finally {
                                  if (mounted) {
                                    setState(() => _checkoutLoading = false);
                                    setSheetState(() {});
                                  }
                                }
                              },
                        icon: const Icon(Icons.payment),
                        label: Text(_checkoutLoading ? 'جاري الإرسال...' : 'تأكيد الطلب'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text('سلة المشتريات (${cart.itemCount})'),
        actions: [
          IconButton(
            tooltip: 'فتح السلة الأصلية',
            icon: const Icon(Icons.open_in_new),
            onPressed: _openOriginalCart,
          ),
          if (cart.items.isNotEmpty)
            IconButton(
              tooltip: 'تفريغ السلة',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: cart.isLoading ? null : () => _showClearConfirmation(cart),
            ),
        ],
      ),
      body: _buildBody(cart),
      bottomNavigationBar: cart.items.isEmpty || cart.isLoading
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'الإجمالي',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${cart.formatPrice(cart.totalPrice)} دولار',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: _checkoutLoading
                            ? null
                            : () => _showCheckoutSheet(cart),
                        icon: const Icon(Icons.payment),
                        label: const Text('إتمام الشراء'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBody(CartProvider cart) {
    if (cart.isLoading && cart.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (cart.error != null && cart.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(cart.error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: cart.isLoading ? null : cart.loadCart,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    if (cart.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: cart.loadCart,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 180),
            Icon(Icons.shopping_cart_outlined, size: 72, color: Colors.grey),
            SizedBox(height: 16),
            Center(child: Text('سلة المشتريات فارغة')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: cart.loadCart,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: cart.items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) => _CartItemTile(
          item: cart.items[index],
          enabled: !cart.isLoading,
          onIncrease: () => cart.updateQuantity(
            cart.items[index].product,
            cart.items[index].quantity + 1,
          ),
          onDecrease: () => cart.updateQuantity(
            cart.items[index].product,
            cart.items[index].quantity - 1,
          ),
          onRemove: () => cart.removeFromCart(cart.items[index].product),
        ),
      ),
    );
  }
}

class _CheckoutSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _CheckoutSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _PaymentMethodOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentMethodOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? color : Colors.grey.shade400,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? color : null),
            const SizedBox(width: 10),
            Expanded(child: Text(label)),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color: selected ? color : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckoutTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const _CheckoutTextField({
    required this.controller,
    required this.label,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  final CartItem item;
  final bool enabled;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onRemove;

  const _CartItemTile({
    required this.item,
    required this.enabled,
    required this.onIncrease,
    required this.onDecrease,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final product = item.product;
    final price = double.tryParse(product.price) ?? 0;
    final image = product.imageUrl;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: image.isEmpty
                  ? Container(
                      width: 72,
                      height: 88,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.book_outlined, size: 32),
                    )
                  : CachedNetworkImage(
                      imageUrl: image,
                      width: 72,
                      height: 88,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.book_outlined, size: 32),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text('${price.toStringAsFixed(2)} دولار'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: enabled && item.quantity > 1
                            ? onDecrease
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text(
                        '${item.quantity}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: enabled ? onIncrease : null,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'إزالة',
              onPressed: enabled ? onRemove : null,
              icon: const Icon(Icons.delete_outline, color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }
}