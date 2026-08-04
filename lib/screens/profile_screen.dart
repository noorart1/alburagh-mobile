import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_service.dart';
import '../core/constants.dart';
import '../core/currency_utils.dart';
import '../core/theme/app_colors.dart';
import '../models/user.dart';
import '../providers/cart_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/country_picker_field.dart';
import 'cart_screen.dart';
import 'register_screen.dart';
import 'wishlist_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _api = ApiService();

  // SharedPreferences keys
  static const _firstNameKey = 'profile_first_name';
  static const _lastNameKey = 'profile_last_name';
  static const _phoneKey = 'profile_phone';
  static const _emailKey = 'profile_email';
  static const _address1Key = 'profile_address1';
  static const _address2Key = 'profile_address2';
  static const _cityKey = 'profile_city';
  static const _stateKey = 'profile_state';
  static const _postcodeKey = 'profile_postcode';
  static const _countryKey = 'profile_country';

  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _address1Controller = TextEditingController();
  final _address2Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _postcodeController = TextEditingController();
  final _countryController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  // Login form controllers
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _address1Controller.dispose();
    _address2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postcodeController.dispose();
    _countryController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final authProvider = context.read<AuthProvider>();
    // This screen is built immediately at app start (it's one of
    // MainScreen's IndexedStack tabs), which can race AuthProvider's
    // saved-session restore. Wait for that to finish so isLoggedIn below
    // reflects the real, restored state instead of its initial `false`.
    await authProvider.initialized;
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();

    if (authProvider.isLoggedIn && authProvider.user != null) {
      // Usually already cached by AuthProvider right after login/auto-login,
      // so this returns instantly instead of this screen making its own
      // GET /profile round trip every time it's opened.
      await authProvider.ensureProfileLoaded();
      final profile = authProvider.profile;

      if (profile != null) {
        if (!mounted) return;
        _applyProfileData(profile, authProvider.user!);
        return;
      }
      // Preload failed (e.g. no connection at the time) — fall through to
      // the cached prefs copy below rather than getting stuck loading.
    }

    if (!mounted) return;
    setState(() {
      _firstNameController.text = prefs.getString(_firstNameKey) ?? '';
      _lastNameController.text = prefs.getString(_lastNameKey) ?? '';
      _phoneController.text = prefs.getString(_phoneKey) ?? '';
      _emailController.text = prefs.getString(_emailKey) ?? '';
      _address1Controller.text = prefs.getString(_address1Key) ?? '';
      _address2Controller.text = prefs.getString(_address2Key) ?? '';
      _cityController.text = prefs.getString(_cityKey) ?? '';
      _stateController.text = prefs.getString(_stateKey) ?? '';
      _postcodeController.text = prefs.getString(_postcodeKey) ?? '';
      _countryController.text = prefs.getString(_countryKey) ?? '';
      _isLoading = false;
    });
  }

  void _applyProfileData(Map<String, dynamic> profile, User user) {
    String firstName = profile['first_name']?.toString() ?? '';
    String lastName = profile['last_name']?.toString() ?? '';
    if (firstName.isEmpty) {
      firstName = user.name.split(' ').first;
    }
    if (lastName.isEmpty && user.name.split(' ').length > 1) {
      lastName = user.name.split(' ').skip(1).join(' ');
    }

    final billing = profile['billing'] as Map<String, dynamic>? ?? {};
    final shipping = profile['shipping'] as Map<String, dynamic>? ?? {};

    setState(() {
      _firstNameController.text = firstName;
      _lastNameController.text = lastName;
      _phoneController.text =
          profile['phone']?.toString() ?? billing['phone']?.toString() ?? '';
      _emailController.text = profile['email']?.toString() ?? user.email;
      _address1Controller.text =
          billing['address_1']?.toString() ??
          shipping['address_1']?.toString() ??
          '';
      _address2Controller.text =
          billing['address_2']?.toString() ??
          shipping['address_2']?.toString() ??
          '';
      _cityController.text =
          billing['city']?.toString() ?? shipping['city']?.toString() ?? '';
      _stateController.text =
          billing['state']?.toString() ?? shipping['state']?.toString() ?? '';
      _postcodeController.text =
          billing['postcode']?.toString() ??
          shipping['postcode']?.toString() ??
          '';
      _countryController.text =
          billing['country']?.toString() ??
          shipping['country']?.toString() ??
          '';
      _isLoading = false;
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();

    setState(() => _isSaving = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_firstNameKey, _firstNameController.text.trim());
    await prefs.setString(_lastNameKey, _lastNameController.text.trim());
    await prefs.setString(_phoneKey, _phoneController.text.trim());
    await prefs.setString(_emailKey, _emailController.text.trim());
    await prefs.setString(_address1Key, _address1Controller.text.trim());
    await prefs.setString(_address2Key, _address2Controller.text.trim());
    await prefs.setString(_cityKey, _cityController.text.trim());
    await prefs.setString(_stateKey, _stateController.text.trim());
    await prefs.setString(_postcodeKey, _postcodeController.text.trim());
    await prefs.setString(_countryKey, _countryController.text.trim());

    final token = authProvider.user?.token;
    String? errorMessage;

    if (authProvider.isLoggedIn && token != null && token.isNotEmpty) {
      final address = {
        'address_1': _address1Controller.text.trim(),
        'address_2': _address2Controller.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'postcode': _postcodeController.text.trim(),
        'country': _countryController.text.trim(),
        'phone': _phoneController.text.trim(),
      };
      try {
        final updated = await _api.updateProfile(token, {
          'first_name': _firstNameController.text.trim(),
          'last_name': _lastNameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'email': _emailController.text.trim(),
          'billing': address,
          'shipping': address,
        });
        // Keep AuthProvider's cached profile in sync with what was just
        // saved — otherwise it would keep serving the pre-save snapshot to
        // this screen (or others) until the next full app restart.
        authProvider.setProfile(updated);
      } catch (e) {
        errorMessage = 'تم الحفظ على الجهاز فقط، فشل التحديث في الحساب: $e';
      }
    }

    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(errorMessage ?? 'تم حفظ معلومات الحساب')),
    );
  }

  Future<void> _clearProfile() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text(
          'هل تريد حذف معلومات الحساب المحفوظة من هذا الجهاز؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (shouldClear != true) return;

    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      _firstNameKey,
      _lastNameKey,
      _phoneKey,
      _emailKey,
      _address1Key,
      _address2Key,
      _cityKey,
      _stateKey,
      _postcodeKey,
      _countryKey,
    ]) {
      await prefs.remove(key);
    }

    if (!mounted) return;
    final authProvider = context.read<AuthProvider>();
    await authProvider.logout();

    setState(() {
      _firstNameController.clear();
      _lastNameController.clear();
      _phoneController.clear();
      _emailController.clear();
      _address1Controller.clear();
      _address2Controller.clear();
      _cityController.clear();
      _stateController.clear();
      _postcodeController.clear();
      _countryController.clear();
    });
  }

  void _showComingSoon(String title) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('هذا القسم جاهز للربط بخدمة الحساب والطلبات.'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('حسنا'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _displayName {
    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();
    if (first.isNotEmpty && last.isNotEmpty) return '$first $last';
    if (first.isNotEmpty) return first;
    if (last.isNotEmpty) return last;
    return 'مستخدم دار البراق';
  }

  String get _subtitle {
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    if (phone.isNotEmpty) return phone;
    if (email.isNotEmpty) return email;
    return 'أكمل معلومات حسابك';
  }

  String get _initial {
    final name = _displayName.trim();
    return name.isNotEmpty ? name.characters.first : 'م';
  }

  String get _fullAddressSummary {
    final parts = [
      _address1Controller.text.trim(),
      _address2Controller.text.trim(),
      _cityController.text.trim(),
      _stateController.text.trim(),
      _postcodeController.text.trim(),
      _countryController.text.trim(),
    ].where((e) => e.isNotEmpty).toList();
    return parts.isEmpty ? 'لا يوجد عنوان محفوظ بعد' : parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final authProvider = context.watch<AuthProvider>();

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('حسابي'),
          backgroundColor: primaryColor,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!authProvider.isLoggedIn) {
      return _buildLoginScreen(authProvider);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('حسابي'),
        backgroundColor: primaryColor,
        actions: [
          IconButton(
            tooltip: 'تسجيل الخروج',
            onPressed: _clearProfile,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ProfileHeader(
            name: _displayName,
            subtitle: _subtitle,
            initial: _initial,
          ),
          const SizedBox(height: 16),
          _CartSummary(
            itemCount: cart.itemCount,
            // Item prices only — see the note on cart_screen.dart's subtotal
            // display for why this isn't cart.totalPrice.
            totalPrice: CurrencyUtils.format(
              cart.subtotal,
              cart.currencySymbol,
            ),
            onOpenCart: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CartScreen()),
              );
            },
          ),
          const SizedBox(height: 16),
          // Personal Information Section
          _ProfileSection(
            title: 'المعلومات الشخصية',
            children: [
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _ProfileTextField(
                            controller: _firstNameController,
                            label: 'الاسم الأول',
                            icon: Icons.person_outline,
                            textInputAction: TextInputAction.next,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'أدخل الاسم';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ProfileTextField(
                            controller: _lastNameController,
                            label: 'اسم العائلة',
                            icon: Icons.person_outline,
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _ProfileTextField(
                      controller: _phoneController,
                      label: 'رقم الهاتف',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        final phone = v?.trim() ?? '';
                        if (phone.isEmpty) return 'أدخل رقم الهاتف';
                        if (phone.length < 8) return 'رقم غير صحيح';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _ProfileTextField(
                      controller: _emailController,
                      label: 'البريد الإلكتروني',
                      icon: Icons.mail_outline,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        final email = v?.trim() ?? '';
                        if (email.isEmpty) return null;
                        if (!email.contains('@')) return 'بريد غير صحيح';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Address Section
          _ProfileSection(
            title: 'عنوان الشحن',
            children: [
              _ProfileTextField(
                controller: _address1Controller,
                label: 'الشارع والعنوان',
                icon: Icons.home_outlined,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              _ProfileTextField(
                controller: _address2Controller,
                label: 'الشقة / الدور / التفاصيل الإضافية',
                icon: Icons.apartment_outlined,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ProfileTextField(
                      controller: _cityController,
                      label: 'المدينة',
                      icon: Icons.location_city_outlined,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ProfileTextField(
                      controller: _stateController,
                      label: 'المحافظة',
                      icon: Icons.map_outlined,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ProfileTextField(
                      controller: _postcodeController,
                      label: 'الرمز البريدي',
                      icon: Icons.markunread_mailbox_outlined,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: CountryPickerField(controller: _countryController),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _saveProfile,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_isSaving ? 'جار الحفظ...' : 'حفظ المعلومات'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ProfileSection(
            title: 'الحساب',
            children: [
              _ProfileTile(
                icon: Icons.receipt_long,
                title: 'طلباتي',
                subtitle: 'متابعة الطلبات وحالة الشحن',
                onTap: () async {
                  final token = context.read<AuthProvider>().user?.token;
                  if (token == null || token.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('يجب تسجيل الدخول أولاً')),
                    );
                    return;
                  }
                  final orders = await _api.getOrders(token);
                  if (!mounted) return;
                  showModalBottomSheet<void>(
                    context: context,
                    builder: (context) => Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'طلباتي',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (orders.isEmpty)
                            const Text('لا توجد طلبات بعد.')
                          else
                            SizedBox(
                              height: 220,
                              child: ListView.builder(
                                itemCount: orders.length,
                                itemBuilder: (context, index) {
                                  final order =
                                      orders[index] as Map<String, dynamic>;
                                  return ListTile(
                                    title: Text('الطلب #${order['id']}'),
                                    subtitle: Text(
                                      'الحالة: ${order['status']}',
                                    ),
                                    trailing: Text('${order['total']}'),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              _ProfileTile(
                icon: Icons.location_on_outlined,
                title: 'عناوين الشحن',
                subtitle: _fullAddressSummary,
                onTap: () async {
                  final token = context.read<AuthProvider>().user?.token;
                  if (token == null || token.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('يجب تسجيل الدخول أولاً')),
                    );
                    return;
                  }
                  try {
                    final addresses = await _api.getAddresses(token);
                    if (!mounted) return;
                    final primary = addresses.isNotEmpty
                        ? addresses.first
                        : null;
                    if (primary != null) {
                      setState(() {
                        _firstNameController.text = primary.firstName;
                        _lastNameController.text = primary.lastName;
                        _phoneController.text = primary.phone;
                        _address1Controller.text = primary.address1;
                        _address2Controller.text = primary.address2;
                        _cityController.text = primary.city;
                        _stateController.text = primary.state;
                        _postcodeController.text = primary.postcode;
                        _countryController.text = primary.country;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم تحميل العنوان')),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('لا يوجد عنوان محفوظ')),
                      );
                    }
                  } catch (_) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('فشل تحميل العناوين')),
                    );
                  }
                },
              ),
              _ProfileTile(
                icon: Icons.favorite_border,
                title: 'المفضلة',
                subtitle: 'المنتجات التي أعجبتك',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const WishlistScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ProfileSection(
            title: 'العملة',
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'USD', label: Text('USD (\$)')),
                    ButtonSegment(value: 'IQD', label: Text('IQD (د.ع)')),
                  ],
                  selected: {context.watch<CurrencyProvider>().currency},
                  onSelectionChanged: (selection) {
                    context.read<CurrencyProvider>().setCurrency(
                      selection.first,
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ProfileSection(
            title: 'الدعم',
            children: [
              _ProfileTile(
                icon: Icons.support_agent,
                title: 'التواصل مع الدعم',
                subtitle: 'المساعدة في الشراء ومتابعة الطلبات',
                onTap: () => _showComingSoon('التواصل مع الدعم'),
              ),
              _ProfileTile(
                icon: Icons.info_outline,
                title: 'عن دار البراق',
                subtitle: 'متجر للكتب والمنتجات الثقافية',
                onTap: () => _showComingSoon('عن دار البراق'),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _showForgotPasswordDialog() async {
    final emailController = TextEditingController(
      text: _loginEmailController.text.contains('@')
          ? _loginEmailController.text
          : '',
    );
    final formKey = GlobalKey<FormState>();
    bool loading = false;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('استعادة كلمة المرور'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'أدخل بريدك الإلكتروني وسنرسل لك رابط إعادة تعيين كلمة المرور',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: emailController,
                  enabled: !loading,
                  autofocus: true,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'البريد الإلكتروني',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'الرجاء إدخال البريد الإلكتروني';
                    }
                    return null;
                  },
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!, style: const TextStyle(color: AppColors.error)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: loading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;

                      setDialogState(() {
                        loading = true;
                        error = null;
                      });

                      try {
                        await _api.forgotPassword(emailController.text.trim());
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'تم إرسال رابط استعادة كلمة المرور إلى بريدك الإلكتروني',
                            ),
                          ),
                        );
                      } on DioException catch (e) {
                        setDialogState(() {
                          loading = false;
                          error = e.response?.statusCode == 404
                              ? 'لا يوجد حساب مرتبط بهذا البريد الإلكتروني'
                              : (e.response?.data?['message'] as String? ??
                                    'تعذر إرسال طلب الاستعادة');
                        });
                      } catch (_) {
                        setDialogState(() {
                          loading = false;
                          error = 'تعذر إرسال طلب الاستعادة';
                        });
                      }
                    },
              child: loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('إرسال'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginScreen(AuthProvider authProvider) {
    return Scaffold(
      appBar: AppBar(title: const Text('حسابي'), backgroundColor: primaryColor),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              height: 220,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [primaryColor, primaryColor.withValues(alpha: 0.7)],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.account_circle, size: 60, color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'تسجيل الدخول',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'سجل دخولك للوصول إلى حسابك',
                      style: TextStyle(fontSize: 14, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (authProvider.error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              authProvider.error!,
                              style: const TextStyle(
                                color: AppColors.error,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: AppColors.error,
                            ),
                            onPressed: authProvider.clearError,
                          ),
                        ],
                      ),
                    ),
                  if (authProvider.error != null) const SizedBox(height: 16),
                  TextField(
                    controller: _loginEmailController,
                    enabled: !authProvider.isLoading,
                    decoration: InputDecoration(
                      hintText: 'البريد الإلكتروني',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _loginPasswordController,
                    enabled: !authProvider.isLoading,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      hintText: 'كلمة المرور',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: authProvider.isLoading
                          ? null
                          : _showForgotPasswordDialog,
                      child: Text(
                        'نسيت كلمة المرور؟',
                        style: TextStyle(color: primaryColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: authProvider.isLoading
                        ? null
                        : () async {
                            final success = await authProvider.login(
                              _loginEmailController.text,
                              _loginPasswordController.text,
                            );
                            if (success && mounted) {
                              _loadProfile();
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: authProvider.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'تسجيل الدخول',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      const Text(
                        'ليس لديك حساب؟ ',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RegisterScreen(),
                            ),
                          );
                        },
                        child: Text(
                          'أنشئ حساباً',
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────── Widgets ────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final String name;
  final String subtitle;
  final String initial;

  const _ProfileHeader({
    required this.name,
    required this.subtitle,
    required this.initial,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: Colors.white,
            child: Text(
              initial,
              style: const TextStyle(
                color: primaryColor,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.86)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CartSummary extends StatelessWidget {
  final int itemCount;
  final String totalPrice;
  final VoidCallback onOpenCart;

  const _CartSummary({
    required this.itemCount,
    required this.totalPrice,
    required this.onOpenCart,
  });

  @override
  Widget build(BuildContext context) {
    return _ProfileSection(
      title: 'ملخص السلة',
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const CircleAvatar(
            backgroundColor: AppColors.surfaceSoft,
            child: Icon(Icons.shopping_cart_outlined, color: primaryColor),
          ),
          title: Text('$itemCount منتج في السلة'),
          subtitle: Text('المجموع الفرعي: $totalPrice'),
          trailing: const Icon(Icons.chevron_left),
          onTap: onOpenCart,
        ),
      ],
    );
  }
}

class _ProfileTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int maxLines;
  final String? Function(String?)? validator;

  const _ProfileTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.textInputAction,
    this.validator,
  }) : maxLines = 1;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _ProfileSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: AppColors.surfaceSoft,
          child: Icon(icon, color: primaryColor),
        ),
        title: Text(title),
        subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_left),
        onTap: onTap,
      ),
    );
  }
}
