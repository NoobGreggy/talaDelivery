part of '../../app.dart';

class CustomerSplash extends StatefulWidget {
  const CustomerSplash({super.key});
  @override
  State<CustomerSplash> createState() => _CustomerSplashState();
}

class _CustomerSplashState extends State<CustomerSplash> {
  Timer? timer;

  @override
  void initState() {
    super.initState();
    timer = Timer(const Duration(milliseconds: 1600), _restoreSession);
  }

  Future<void> _restoreSession() async {
    final dependencies = CustomerDependencyScope.of(context);
    final routes = CustomerRouteScope.of(context);
    CustomerUser? user;
    var hasAddress = false;
    try {
      user = await dependencies.authRepository.restoreSession();
      if (user?.role == 'customer') {
        hasAddress = (await dependencies.addressRepository.list()).isNotEmpty;
      }
    } catch (_) {
      user = null;
    }
    if (!mounted) return;

    routes.finishRestoring();
    if (user != null) {
      routes.signInWithUser(user, hasDeliveryAddress: hasAddress);
      final destination = routes.destinationAfterSignIn();
      Navigator.of(context).pushReplacementNamed(
        destination.name!,
        arguments: destination.arguments,
      );
    } else {
      Navigator.of(context).pushReplacementNamed(CustomerRoutes.login);
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = appPaletteOf(context);
    return Scaffold(
      backgroundColor: palette.splashBg,
      body: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    palette.splashStart,
                    palette.splashMid,
                    palette.splashEnd,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            CustomPaint(painter: _CustomerSplashPainter(palette: palette)),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: palette.frosted.withValues(alpha: .76),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'CUSTOMER APP',
                          style: TextStyle(
                            color: sky,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 238,
                      height: 238,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: palette.frosted.withValues(alpha: .72),
                        shape: BoxShape.circle,
                        border: Border.all(color: palette.frosted, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: sky.withValues(alpha: .15),
                            blurRadius: 34,
                            offset: const Offset(0, 18),
                          ),
                        ],
                      ),
                      child: Image.asset('assets/images/tala_rider.png'),
                    ),
                    const SizedBox(height: 24),
                    const Brand(size: 38, centered: true),
                    const SizedBox(height: 9),
                    Text(
                      'Your neighborhood, delivered.',
                      style: TextStyle(color: palette.quiet, fontSize: 16),
                    ),
                    const Spacer(),
                    const Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _SplashFeature(
                          icon: Icons.restaurant_rounded,
                          label: 'Food',
                        ),
                        _SplashFeature(
                          icon: Icons.local_grocery_store_rounded,
                          label: 'Grocery',
                        ),
                        _SplashFeature(
                          icon: Icons.medication_rounded,
                          label: 'Pharmacy',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: 150,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 1250),
                        builder: (context, value, child) =>
                            LinearProgressIndicator(
                              value: value,
                              minHeight: 5,
                              borderRadius: BorderRadius.circular(8),
                              backgroundColor: palette.surface,
                            ),
                      ),
                    ),
                    const SizedBox(height: 11),
                    Text(
                      'Preparing stores near you…',
                      style: TextStyle(
                        color: palette.quiet,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashFeature extends StatelessWidget {
  const _SplashFeature({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = appPaletteOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: palette.frosted.withValues(alpha: .76),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: sky, size: 15),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: palette.text,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerSplashPainter extends CustomPainter {
  const _CustomerSplashPainter({required this.palette});

  final AppPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final softBlue = Paint()..color = sky.withValues(alpha: .06);
    canvas.drawCircle(
      Offset(size.width + 28, size.height * .18),
      120,
      softBlue,
    );
    canvas.drawCircle(Offset(-35, size.height * .78), 105, softBlue);
    canvas.drawCircle(
      Offset(size.width * .72, size.height * .7),
      34,
      Paint()..color = palette.frosted.withValues(alpha: .32),
    );
  }

  @override
  bool shouldRepaint(covariant _CustomerSplashPainter oldDelegate) =>
      oldDelegate.palette != palette;
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  CustomerAuthViewModel? viewModel;
  bool hidden = true;
  bool isCheckingAddress = false;
  bool hasSubmitted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    viewModel ??= CustomerAuthViewModel(
      CustomerDependencyScope.of(context).authRepository,
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    viewModel?.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!hasSubmitted) setState(() => hasSubmitted = true);
    if (!(formKey.currentState?.validate() ?? false)) return;
    final user = await viewModel!.login(
      email: emailController.text,
      password: passwordController.text,
    );
    if (!mounted || user == null) return;

    var hasDeliveryAddress = false;
    if (user.role == 'customer') {
      setState(() => isCheckingAddress = true);
      try {
        hasDeliveryAddress = (await CustomerDependencyScope.of(
          context,
        ).addressRepository.list()).isNotEmpty;
      } catch (error) {
        if (mounted) {
          message(context, apiErrorMessage(error), kind: ToastKind.error);
        }
        return;
      } finally {
        if (mounted) setState(() => isCheckingAddress = false);
      }
    }
    if (!mounted) return;

    final routes = CustomerRouteScope.of(context)
      ..signInWithUser(user, hasDeliveryAddress: hasDeliveryAddress);
    final destination = routes.destinationAfterSignIn();
    message(context, 'Login successful.', kind: ToastKind.success);
    Navigator.of(context).pushNamedAndRemoveUntil(
      destination.name!,
      (_) => false,
      arguments: destination.arguments,
    );
  }

  @override
  Widget build(BuildContext context) {
    final continueAsRider = RiderSwitchScope.maybeOf(context);
    return ListenableBuilder(
      listenable: viewModel!,
      builder: (context, _) => AuthScaffold(
        formKey: formKey,
        autovalidateMode: hasSubmitted
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        title: 'Welcome back',
        subtitle: 'Log in to order from stores near you.',
        children: [
          TextFormField(
            key: const Key('login-email'),
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            validator: CustomerValidators.email,
            decoration: InputDecoration(
              labelText: 'Email',
              prefixIcon: const Icon(Icons.mail_outline_rounded),
              errorText: viewModel!.fieldError('email'),
            ),
          ),
          const SizedBox(height: 13),
          TextFormField(
            key: const Key('login-password'),
            controller: passwordController,
            obscureText: hidden,
            validator: CustomerValidators.password,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              errorText: viewModel!.fieldError('password'),
              suffixIcon: IconButton(
                onPressed: () => setState(() => hidden = !hidden),
                icon: Icon(
                  hidden
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () =>
                  Navigator.pushNamed(context, CustomerRoutes.forgotPassword),
              child: const Text('Forgot password?'),
            ),
          ),
          AuthErrorBanner(errorMessage: viewModel!.errorMessage),
          const SizedBox(height: 14),
          PrimaryAction(
            label: viewModel!.isSubmitting
                ? 'Logging in…'
                : isCheckingAddress
                ? 'Checking saved address…'
                : 'Log in',
            onTap: viewModel!.isSubmitting || isCheckingAddress
                ? () {}
                : submit,
          ),
          const SizedBox(height: 18),
          if (continueAsRider != null) ...[
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'NOT A CUSTOMER?',
                    style: TextStyle(
                      color: appPaletteOf(context).quiet,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: continueAsRider,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                side: const BorderSide(color: sky),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.delivery_dining_rounded),
              label: const Text(
                'Continue as rider',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 14),
          ],
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Don’t have an account?'),
              TextButton(
                onPressed: () =>
                    Navigator.pushNamed(context, CustomerRoutes.register),
                child: const Text('Create account'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmationController = TextEditingController();
  CustomerAuthViewModel? viewModel;
  bool hidden = true;
  bool hasSubmitted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    viewModel ??= CustomerAuthViewModel(
      CustomerDependencyScope.of(context).authRepository,
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmationController.dispose();
    viewModel?.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!hasSubmitted) setState(() => hasSubmitted = true);
    if (!(formKey.currentState?.validate() ?? false)) return;
    final user = await viewModel!.register(
      name: nameController.text,
      phone: phoneController.text,
      email: emailController.text,
      password: passwordController.text,
    );
    if (!mounted || user == null) return;

    final routes = CustomerRouteScope.of(context)..signInWithUser(user);
    final destination = routes.destinationAfterSignIn();
    message(context, 'Account created successfully.', kind: ToastKind.success);
    Navigator.of(context).pushNamedAndRemoveUntil(
      destination.name!,
      (_) => false,
      arguments: destination.arguments,
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: viewModel!,
    builder: (context, _) => AuthScaffold(
      formKey: formKey,
      autovalidateMode: hasSubmitted
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      canPop: true,
      title: 'Create your account',
      subtitle: 'A few details and you’re ready to order.',
      children: [
        TextFormField(
          key: const Key('register-name'),
          controller: nameController,
          validator: CustomerValidators.name,
          decoration: InputDecoration(
            labelText: 'Full name',
            prefixIcon: const Icon(Icons.person_outline_rounded),
            errorText: viewModel!.fieldError('name'),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: const Key('register-phone'),
          controller: phoneController,
          keyboardType: TextInputType.phone,
          validator: (value) => CustomerValidators.phone(value, required: true),
          decoration: InputDecoration(
            labelText: 'Phone number',
            prefixIcon: const Icon(Icons.phone_outlined),
            errorText: viewModel!.fieldError('phone'),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: const Key('register-email'),
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          validator: CustomerValidators.email,
          decoration: InputDecoration(
            labelText: 'Email',
            prefixIcon: const Icon(Icons.mail_outline_rounded),
            errorText: viewModel!.fieldError('email'),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: const Key('register-password'),
          controller: passwordController,
          obscureText: hidden,
          validator: CustomerValidators.password,
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            errorText: viewModel!.fieldError('password'),
            suffixIcon: IconButton(
              onPressed: () => setState(() => hidden = !hidden),
              icon: Icon(
                hidden
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: const Key('register-confirmation'),
          controller: confirmationController,
          obscureText: hidden,
          validator: (value) => CustomerValidators.confirmPassword(
            value,
            passwordController.text,
          ),
          decoration: const InputDecoration(
            labelText: 'Confirm password',
            prefixIcon: Icon(Icons.lock_outline_rounded),
          ),
        ),
        AuthErrorBanner(errorMessage: viewModel!.errorMessage),
        const SizedBox(height: 22),
        PrimaryAction(
          label: viewModel!.isSubmitting
              ? 'Creating account…'
              : 'Create account',
          onTap: viewModel!.isSubmitting ? () {} : submit,
        ),
        const SizedBox(height: 12),
        Text(
          'By creating an account, you agree to TalaDelivery’s terms and privacy policy.',
          textAlign: TextAlign.center,
          style: TextStyle(color: appPaletteOf(context).quiet, fontSize: 12),
        ),
      ],
    ),
  );
}

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  bool hasSubmitted = false;

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
    formKey: formKey,
    autovalidateMode: hasSubmitted
        ? AutovalidateMode.onUserInteraction
        : AutovalidateMode.disabled,
    canPop: true,
    title: 'Reset password',
    subtitle: 'We’ll send recovery instructions to your account.',
    children: [
      TextFormField(
        key: const Key('forgot-email'),
        controller: emailController,
        keyboardType: TextInputType.emailAddress,
        validator: CustomerValidators.email,
        decoration: const InputDecoration(
          labelText: 'Email',
          prefixIcon: Icon(Icons.mail_outline_rounded),
        ),
      ),
      const SizedBox(height: 22),
      PrimaryAction(
        label: 'Send reset link',
        onTap: () {
          if (!hasSubmitted) setState(() => hasSubmitted = true);
          if (!(formKey.currentState?.validate() ?? false)) return;
          message(
            context,
            'Password recovery is not available in the API yet.',
          );
        },
      ),
    ],
  );
}

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.canPop = false,
    this.formKey,
    this.autovalidateMode = AutovalidateMode.disabled,
  });
  final String title;
  final String subtitle;
  final List<Widget> children;
  final bool canPop;
  final GlobalKey<FormState>? formKey;
  final AutovalidateMode autovalidateMode;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: canPop
        ? AppBar(backgroundColor: appPaletteOf(context).background)
        : null,
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset('assets/images/tala_rider.png', height: 94),
                const SizedBox(height: 10),
                const Brand(size: 28, centered: true),
                const SizedBox(height: 38),
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 7),
                Text(subtitle),
                const SizedBox(height: 24),
                if (formKey == null)
                  ...children
                else
                  Form(
                    key: formKey,
                    autovalidateMode: autovalidateMode,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: children,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, this.errorMessage});

  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    if (errorMessage == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: InfoBanner(icon: Icons.error_outline_rounded, text: errorMessage!),
    );
  }
}
