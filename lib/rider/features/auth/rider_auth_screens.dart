part of '../../app.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restore());
  }

  Future<void> _restore() async {
    final controller = RiderDependencyScope.of(context).controller;
    final authenticated = await controller.restore();
    if (!mounted) return;
    final routes = RiderRouteScope.of(context)..finishRestoring();
    if (authenticated) {
      routes.signInAsRider();
      routes.sync(controller);
    }
    Navigator.of(context).pushReplacementNamed(
      authenticated ? RiderRoutes.dashboard : RiderRoutes.login,
    );
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
                  'Connecting you to nearby deliveries…',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const Spacer(flex: 2),
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
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
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool hidden = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _required(String? value, String label) =>
      value == null || value.trim().isEmpty ? '$label is required.' : null;

  String? _emailValidator(String? value) {
    final required = _required(value, 'Email');
    if (required != null) return required;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value!.trim())
        ? null
        : 'Enter a valid email address.';
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final controller = RiderDependencyScope.of(context).controller;
    final success = await controller.login(
      email: _email.text,
      password: _password.text,
    );
    if (!mounted) return;
    if (!success) {
      showMessage(context, controller.errorMessage ?? 'Login failed.');
      return;
    }
    final routes = RiderRouteScope.of(context)..signInAsRider();
    routes.sync(controller);
    final destination = routes.destinationAfterSignIn();
    Navigator.of(context).pushNamedAndRemoveUntil(
      destination.name!,
      (_) => false,
      arguments: destination.arguments,
    );
  }

  @override
  Widget build(BuildContext context) {
    final continueAsCustomer = CustomerSwitchScope.maybeOf(context);
    final controller = RiderDependencyScope.of(context).controller;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
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
                    const Text('Sign in to see your live rider workspace.'),
                    if (controller.errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: riderPaletteOf(context).softOrange,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(controller.errorMessage!),
                      ),
                    ],
                    const SizedBox(height: 28),
                    TextFormField(
                      key: const Key('rider-login-email'),
                      controller: _email,
                      validator: _emailValidator,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: const Icon(Icons.mail_outline_rounded),
                        errorText: controller.fieldErrors['email'],
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      key: const Key('rider-login-password'),
                      controller: _password,
                      validator: (value) => _required(value, 'Password'),
                      obscureText: hidden,
                      onFieldSubmitted: (_) => _login(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        errorText: controller.fieldErrors['password'],
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
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: controller.isSubmitting ? 'Signing in…' : 'Log in',
                      icon: controller.isSubmitting
                          ? null
                          : Icons.arrow_forward_rounded,
                      onPressed: controller.isSubmitting ? null : _login,
                    ),
                    if (continueAsCustomer != null) ...[
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: continueAsCustomer,
                        icon: const Icon(Icons.shopping_bag_outlined),
                        label: const Text('Continue as customer'),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Text(
                      'Use the rider account approved by your administrator.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
