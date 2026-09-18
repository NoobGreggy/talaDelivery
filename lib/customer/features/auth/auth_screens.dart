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
      if (user.role == 'customer') {
        unawaited(dependencies.realtime.start(user.id));
      }
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
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                          Column(
                            children: [
                              Container(
                                width: 238,
                                height: 238,
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: palette.frosted.withValues(alpha: .72),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: palette.frosted,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: sky.withValues(alpha: .15),
                                      blurRadius: 34,
                                      offset: const Offset(0, 18),
                                    ),
                                  ],
                                ),
                                child: Image.asset(
                                  'assets/images/tala_rider.png',
                                ),
                              ),
                              const SizedBox(height: 24),
                              const Brand(size: 38, centered: true),
                              const SizedBox(height: 9),
                              Text(
                                'Your neighborhood, delivered.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: palette.quiet,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
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
                        ],
                      ),
                    ),
                  ),
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
  bool showReveal = false;
  RouteSettings? pendingDestination;

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
    if (user.role == 'customer') {
      unawaited(CustomerDependencyScope.of(context).realtime.start(user.id));
    }
    final destination = routes.destinationAfterSignIn();
    if (showReveal) return;
    setState(() {
      showReveal = true;
      pendingDestination = destination;
    });
  }

  void _completeRevealNavigation() {
    final destination = pendingDestination;
    if (destination == null || !mounted) return;
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
      builder: (context, _) {
        final submitBusy = viewModel!.isSubmitting || isCheckingAddress;
        final submitLabel = isCheckingAddress
            ? 'Checking saved address…'
            : viewModel!.isSubmitting
            ? 'Signing in…'
            : 'Sign in';
        return Scaffold(
          body: Stack(
            children: [
              SafeArea(
                bottom: false,
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    children: [
                      const _LoginHero(),
                      _LoginSheet(
                        topOffset: 26,
                        child: Form(
                          key: formKey,
                          autovalidateMode: hasSubmitted
                              ? AutovalidateMode.onUserInteraction
                              : AutovalidateMode.disabled,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const _LoginSheetHandle(),
                              const SizedBox(height: 18),
                              Text(
                                'Sign in to your account',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Enter your account details to continue.',
                                style: TextStyle(
                                  color: appPaletteOf(context).quiet,
                                  fontSize: 12.5,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 20),
                              TalaPrimaryField(
                                key: const Key('login-email'),
                                label: 'Email',
                                controller: emailController,
                                prefixIcon: Icons.mail_outline_rounded,
                                keyboardType: TextInputType.emailAddress,
                                validator: CustomerValidators.email,
                                errorText: viewModel!.fieldError('email'),
                                textInputAction: TextInputAction.next,
                              ),
                              const SizedBox(height: 13),
                              TalaPrimaryField(
                                key: const Key('login-password'),
                                label: 'Password',
                                controller: passwordController,
                                prefixIcon: Icons.lock_outline_rounded,
                                obscureText: hidden,
                                onToggleVisibility: () =>
                                    setState(() => hidden = !hidden),
                                validator: CustomerValidators.password,
                                errorText: viewModel!.fieldError('password'),
                                textInputAction: TextInputAction.done,
                                onSubmitted: submitBusy
                                    ? null
                                    : (_) => submit(),
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => Navigator.pushNamed(
                                    context,
                                    CustomerRoutes.forgotPassword,
                                  ),
                                  child: const Text('Forgot password?'),
                                ),
                              ),
                              AuthErrorBanner(
                                errorMessage: viewModel!.errorMessage,
                              ),
                              const SizedBox(height: 14),
                              TalaButton(
                                label: submitLabel,
                                loading: submitBusy,
                                enabled: !submitBusy,
                                onPressed: submit,
                                icon: submitBusy
                                    ? null
                                    : Icons.arrow_forward_rounded,
                              ),
                              const SizedBox(height: 18),
                              if (continueAsRider != null) ...[
                                Row(
                                  children: [
                                    const Expanded(child: Divider()),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      child: Text(
                                        'NOT A CUSTOMER?',
                                        style: TextStyle(
                                          color: appPaletteOf(context).quiet,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
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
                                      borderRadius: BorderRadius.circular(17),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.delivery_dining_rounded,
                                  ),
                                  label: const Text(
                                    'Continue as rider',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
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
                                    onPressed: () => Navigator.pushNamed(
                                      context,
                                      CustomerRoutes.register,
                                    ),
                                    child: const Text('Create account'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'By continuing, you agree to TalaDelivery’s Terms and Privacy Policy.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: appPaletteOf(context).quiet,
                                  fontSize: 9.5,
                                  height: 1.6,
                                ),
                              ),
                              SizedBox(
                                height:
                                    MediaQuery.paddingOf(context).bottom + 14,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              TalaLoginSuccessReveal(
                trigger: showReveal,
                onComplete: _completeRevealNavigation,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LoginHero extends StatelessWidget {
  const _LoginHero();

  static double _textHeight(
    BuildContext context,
    String text,
    TextStyle style,
    double width,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: width);
    return painter.height;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        final contentWidth = constraints.maxWidth - 44;
        final brandWidth = (contentWidth - 60).clamp(1.0, 1000.0);
        final headlineStyle = TextStyle(
          color: Colors.white,
          fontSize: compact ? 24 : 29,
          fontWeight: FontWeight.w600,
          height: 1.14,
          letterSpacing: -1,
        );
        final brandHeight = _textHeight(
          context,
          'TalaDelivery',
          const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          brandWidth,
        );
        final headerHeight = brandHeight.clamp(48.0, 1000.0);
        final greetingHeight = _textHeight(
          context,
          'Welcome back',
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          contentWidth,
        );
        final headlineHeight = _textHeight(
          context,
          'Your deliveries are\none sign-in away.',
          headlineStyle,
          contentWidth,
        );
        final heroHeight =
            (16 +
                    headerHeight +
                    24 +
                    greetingHeight +
                    5 +
                    headlineHeight +
                    18 +
                    78 +
                    70)
                .clamp(360.0, 1000.0);
        return Container(
          height: heroHeight,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [tint(sky, .42), sky, shade(sky, .1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: ClipRect(
            child: Stack(
              children: [
                Positioned(
                  right: -52,
                  top: -42,
                  child: Container(
                    width: 176,
                    height: 176,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: .16),
                    ),
                  ),
                ),
                Positioned(
                  left: -70,
                  top: 128,
                  child: Container(
                    width: 148,
                    height: 148,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: .1),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .95),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: .4),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: Image.asset(
                                'assets/images/tala_rider.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text.rich(
                              const TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Tala',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'Delivery',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                letterSpacing: -0.7,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 26),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Welcome back',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: .78),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  'Your deliveries are\none sign-in away.',
                                  textAlign: TextAlign.center,
                                  style: headlineStyle,
                                ),
                                const SizedBox(height: 18),
                                const _LoginMapPreview(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A decorative map motif, not a live location or tracking view.
class _LoginMapPreview extends StatelessWidget {
  const _LoginMapPreview();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: Container(
        key: const Key('login-map-preview'),
        height: 78,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .13),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: .27)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const CustomPaint(painter: _LoginMapPainter()),
              Align(
                alignment: const Alignment(.38, -.22),
                child: Container(
                  width: 35,
                  height: 35,
                  decoration: BoxDecoration(
                    color: shade(sky, .16),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .7),
                    ),
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: Colors.white,
                    size: 23,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _LoginMapPainter extends CustomPainter {
  const _LoginMapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final streets = Path()
      ..moveTo(-10, h * .26)
      ..lineTo(w * .28, h * .12)
      ..lineTo(w * .55, h * .31)
      ..lineTo(w + 10, h * .14)
      ..moveTo(-10, h * .78)
      ..lineTo(w * .31, h * .57)
      ..lineTo(w * .61, h * .76)
      ..lineTo(w + 10, h * .59)
      ..moveTo(w * .22, -10)
      ..lineTo(w * .37, h + 10)
      ..moveTo(w * .72, -10)
      ..lineTo(w * .88, h + 10);
    canvas.drawPath(
      streets,
      Paint()
        ..color = Colors.white.withValues(alpha: .22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final blocks = Paint()..color = Colors.white.withValues(alpha: .09);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * .04, h * .36, w * .18, h * .22),
        const Radius.circular(5),
      ),
      blocks,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * .42, h * .39, w * .15, h * .2),
        const Radius.circular(5),
      ),
      blocks,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * .77, h * .25, w * .18, h * .2),
        const Radius.circular(5),
      ),
      blocks,
    );

    final route = Path()
      ..moveTo(w * .12, h * .7)
      ..cubicTo(w * .29, h * .63, w * .3, h * .91, w * .47, h * .61)
      ..cubicTo(w * .55, h * .45, w * .62, h * .55, w * .69, h * .54);
    canvas.drawPath(
      route,
      Paint()
        ..color = Colors.white.withValues(alpha: .82)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      Offset(w * .12, h * .7),
      4,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _LoginMapPainter oldDelegate) => false;
}

/// Rounded floating sheet that overlaps the hero art.
class _LoginSheet extends StatelessWidget {
  const _LoginSheet({required this.child, required this.topOffset});

  final Widget child;
  final double topOffset;

  @override
  Widget build(BuildContext context) {
    final palette = appPaletteOf(context);
    return Transform.translate(
      offset: Offset(0, -topOffset),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        decoration: BoxDecoration(
          color: palette.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: .07),
              blurRadius: 40,
              offset: const Offset(0, -12),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class _LoginSheetHandle extends StatelessWidget {
  const _LoginSheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 4,
        decoration: BoxDecoration(
          color: appPaletteOf(context).line,
          borderRadius: BorderRadius.circular(4),
        ),
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
    if (user.role == 'customer') {
      unawaited(CustomerDependencyScope.of(context).realtime.start(user.id));
    }
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
