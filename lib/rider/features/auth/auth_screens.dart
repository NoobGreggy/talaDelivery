part of '../../app.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? timer;
  @override
  void initState() {
    super.initState();
    timer = Timer(const Duration(milliseconds: 1800), openLogin);
  }

  void openLogin() {
    if (mounted) {
      RiderRouteScope.of(context).finishRestoring();
      Navigator.of(context).pushReplacementNamed(RiderRoutes.login);
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      fit: StackFit.expand,
      children: [
        const SkyBackdrop(),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 72, 28, 30),
            child: Column(
              children: [
                const Spacer(),
                const RiderLogo(size: 178),
                const SizedBox(height: 20),
                const BrandLockup(centered: true),
                const SizedBox(height: 12),
                Text(
                  'Delivering what matters.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const Spacer(flex: 2),
                const Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    FeaturePill(
                      icon: Icons.verified_user_rounded,
                      label: 'Safe',
                    ),
                    FeaturePill(icon: Icons.bolt_rounded, label: 'Fast'),
                    FeaturePill(
                      icon: Icons.favorite_rounded,
                      label: 'Reliable',
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                const Text(
                  'RIDER APP',
                  style: TextStyle(
                    color: blue,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool hidden = true;
  @override
  Widget build(BuildContext context) {
    final continueAsCustomer = CustomerSwitchScope.maybeOf(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: Alignment.center,
                    child: RiderLogo(size: 112),
                  ),
                  const SizedBox(height: 14),
                  const BrandLockup(centered: true, compact: true),
                  const SizedBox(height: 44),
                  Text(
                    'Welcome back, rider',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text('Sign in to start accepting deliveries.'),
                  const SizedBox(height: 28),
                  const TextField(
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email or phone number',
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    obscureText: hidden,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
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
                      onPressed: () => showMessage(
                        context,
                        'Password reset is ready for backend integration.',
                      ),
                      child: const Text('Forgot password?'),
                    ),
                  ),
                  const SizedBox(height: 18),
                  PrimaryButton(
                    label: 'Log in',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: () {
                      showMessage(
                        context,
                        'Rider login successful.',
                        kind: RiderToastKind.success,
                      );
                      final routes = RiderRouteScope.of(context)
                        ..signInAsRider();
                      final destination = routes.destinationAfterSignIn();
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        destination.name!,
                        (_) => false,
                        arguments: destination.arguments,
                      );
                    },
                  ),
                  if (continueAsCustomer != null) ...[
                    const SizedBox(height: 20),
                    const Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'NOT A RIDER?',
                            style: TextStyle(
                              color: muted,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        side: const BorderSide(color: blue),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: continueAsCustomer,
                      icon: const Icon(Icons.shopping_bag_outlined),
                      label: const Text(
                        'Continue as customer',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shield_outlined, color: muted, size: 18),
                      SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          'Credentials are provided by your dispatcher.',
                          style: TextStyle(color: muted, fontSize: 13),
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
    );
  }
}
