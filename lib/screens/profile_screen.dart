import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../providers/cart_provider.dart';
import '../providers/auth_provider.dart';
import 'cart_screen.dart';
import 'register_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _nameKey = 'profile_name';
  static const _phoneKey = 'profile_phone';
  static const _emailKey = 'profile_email';
  static const _addressKey = 'profile_address';

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();

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
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final authProvider = context.read<AuthProvider>();

    if (!mounted) return;
    setState(() {
      if (authProvider.isLoggedIn && authProvider.user != null) {
        _nameController.text = prefs.getString(_nameKey)?.isNotEmpty == true
            ? prefs.getString(_nameKey)!
            : authProvider.user!.name;
        _phoneController.text = prefs.getString(_phoneKey)?.isNotEmpty == true
            ? prefs.getString(_phoneKey)!
            : (authProvider.user!.phone ?? '');
        _emailController.text = authProvider.user!.email;
        _addressController.text = prefs.getString(_addressKey) ?? (authProvider.user!.address ?? '');
      } else {
        _nameController.text = prefs.getString(_nameKey) ?? '';
        _phoneController.text = prefs.getString(_phoneKey) ?? '';
        _emailController.text = prefs.getString(_emailKey) ?? '';
        _addressController.text = prefs.getString(_addressKey) ?? '';
      }
      _isLoading = false;
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, _nameController.text.trim());
    await prefs.setString(_phoneKey, _phoneController.text.trim());
    await prefs.setString(_emailKey, _emailController.text.trim());
    await prefs.setString(_addressKey, _addressController.text.trim());

    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ معلومات الحساب')),
    );
  }

  Future<void> _clearProfile() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل تريد حذف معلومات الحساب المحفوظة من هذا الجهاز؟'),
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
    await prefs.remove(_nameKey);
    await prefs.remove(_phoneKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_addressKey);

    if (!mounted) return;
    final authProvider = context.read<AuthProvider>();
    await authProvider.logout();
    
    setState(() {
      _nameController.clear();
      _phoneController.clear();
      _emailController.clear();
      _addressController.clear();
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
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
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
    final name = _nameController.text.trim();
    return name.isNotEmpty ? name : 'مستخدم دار البراق';
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

    // If not logged in, show login screen
    if (!authProvider.isLoggedIn) {
      return _buildLoginScreen(authProvider);
    }

    // If logged in, show profile
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
            itemCount: cart.items.length,
            totalPrice: cart.totalPrice,
            onOpenCart: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CartScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          _ProfileForm(
            formKey: _formKey,
            nameController: _nameController,
            phoneController: _phoneController,
            emailController: _emailController,
            addressController: _addressController,
            isSaving: _isSaving,
            onSave: _saveProfile,
          ),
          const SizedBox(height: 16),
          _ProfileSection(
            title: 'الحساب',
            children: [
              _ProfileTile(
                icon: Icons.receipt_long,
                title: 'طلباتي',
                subtitle: 'متابعة الطلبات وحالة الشحن',
                onTap: () => _showComingSoon('طلباتي'),
              ),
              _ProfileTile(
                icon: Icons.location_on_outlined,
                title: 'عناوين الشحن',
                subtitle: _addressController.text.trim().isEmpty
                    ? 'لا يوجد عنوان محفوظ بعد'
                    : _addressController.text.trim(),
                onTap: () => _showComingSoon('عناوين الشحن'),
              ),
              _ProfileTile(
                icon: Icons.favorite_border,
                title: 'المفضلة',
                subtitle: 'المنتجات التي أعجبتك',
                onTap: () => _showComingSoon('المفضلة'),
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
        ],
      ),
    );
  }

  Widget _buildLoginScreen(AuthProvider authProvider) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('حسابي'),
        backgroundColor: primaryColor,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header with gradient
            Container(
              height: 220,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [primaryColor, primaryColor.withOpacity(0.7)],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.account_circle,
                      size: 60,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'تسجيل الدخول',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'سجل دخولك للوصول إلى حسابك',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Login form
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Error message
                  if (authProvider.error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade600),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              authProvider.error!,
                              style: TextStyle(
                                color: Colors.red.shade600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: Colors.red.shade600),
                            onPressed: authProvider.clearError,
                          ),
                        ],
                      ),
                    ),
                  if (authProvider.error != null) const SizedBox(height: 16),
                  // Email field
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
                  // Password field
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
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
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
                  const SizedBox(height: 24),
                  // Login button
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
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
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
                      Text(
                        'ليس لديك حساب؟ ',
                        style: TextStyle(color: Colors.grey[600]),
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
  final double totalPrice;
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
            backgroundColor: Color(0xFFE8F5E9),
            child: Icon(Icons.shopping_cart_outlined, color: primaryColor),
          ),
          title: Text('$itemCount منتج في السلة'),
          subtitle: Text('المجموع: $totalPrice دولار'),
          trailing: const Icon(Icons.chevron_left),
          onTap: onOpenCart,
        ),
      ],
    );
  }
}

class _ProfileForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final TextEditingController addressController;
  final bool isSaving;
  final VoidCallback onSave;

  const _ProfileForm({
    required this.formKey,
    required this.nameController,
    required this.phoneController,
    required this.emailController,
    required this.addressController,
    required this.isSaving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return _ProfileSection(
      title: 'المعلومات الشخصية',
      children: [
        Form(
          key: formKey,
          child: Column(
            children: [
              _ProfileTextField(
                controller: nameController,
                label: 'الاسم الكامل',
                icon: Icons.person_outline,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'أدخل الاسم الكامل';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _ProfileTextField(
                controller: phoneController,
                label: 'رقم الهاتف',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  final phone = value?.trim() ?? '';
                  if (phone.isEmpty) return 'أدخل رقم الهاتف';
                  if (phone.length < 8) return 'رقم الهاتف غير صحيح';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _ProfileTextField(
                controller: emailController,
                label: 'البريد الإلكتروني',
                icon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty) return null;
                  if (!email.contains('@')) return 'البريد الإلكتروني غير صحيح';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _ProfileTextField(
                controller: addressController,
                label: 'عنوان الشحن',
                icon: Icons.home_outlined,
                maxLines: 3,
                textInputAction: TextInputAction.newline,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: isSaving ? null : onSave,
                  icon: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(isSaving ? 'جار الحفظ...' : 'حفظ المعلومات'),
                ),
              ),
            ],
          ),
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
    this.maxLines = 1,
    this.validator,
  });

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

  const _ProfileSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
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
          backgroundColor: const Color(0xFFE8F5E9),
          child: Icon(icon, color: primaryColor),
        ),
        title: Text(title),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_left),
        onTap: onTap,
      ),
    );
  }
}
