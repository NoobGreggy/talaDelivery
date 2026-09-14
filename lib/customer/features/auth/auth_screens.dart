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
    timer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(fade(const LoginPage()));
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFE4F3FF),
    body: SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white, Color(0xFFEAF6FF), Color(0xFFD8EDFF)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          const CustomPaint(painter: _CustomerSplashPainter()),
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
                        color: Colors.white.withValues(alpha: .76),
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
                      color: Colors.white.withValues(alpha: .72),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
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
                  const Text(
                    'Your neighborhood, delivered.',
                    style: TextStyle(color: quiet, fontSize: 16),
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
                            backgroundColor: Colors.white,
                          ),
                    ),
                  ),
                  const SizedBox(height: 11),
                  const Text(
                    'Preparing stores near you…',
                    style: TextStyle(
                      color: quiet,
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

class _SplashFeature extends StatelessWidget {
  const _SplashFeature({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .76),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: sky, size: 15),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: text,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ],
    ),
  );
}

class _CustomerSplashPainter extends CustomPainter {
  const _CustomerSplashPainter();

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
      Paint()..color = Colors.white.withValues(alpha: .32),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool hidden = true;
  @override
  Widget build(BuildContext context) {
    final continueAsRider = RiderSwitchScope.maybeOf(context);
    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Log in to order from stores near you.',
      children: [
        const TextField(
          decoration: InputDecoration(
            labelText: 'Email or phone',
            prefixIcon: Icon(Icons.mail_outline_rounded),
          ),
        ),
        const SizedBox(height: 13),
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
            onPressed: () =>
                Navigator.push(context, slide(const ForgotPasswordPage())),
            child: const Text('Forgot password?'),
          ),
        ),
        const SizedBox(height: 14),
        PrimaryAction(
          label: 'Log in',
          onTap: () {
            message(context, 'Login successful.', kind: ToastKind.success);
            Navigator.of(context)
                .pushReplacement(slide(const AddressSetupPage(firstRun: true)));
          },
        ),
        const SizedBox(height: 18),
        if (continueAsRider != null) ...[
          const Row(
            children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'NOT A CUSTOMER?',
                  style: TextStyle(
                    color: quiet,
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
                  Navigator.push(context, slide(const RegisterPage())),
              child: const Text('Create account'),
            ),
          ],
        ),
      ],
    );
  }
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  bool hidden = true;
  @override
  Widget build(BuildContext context) => AuthScaffold(
    canPop: true,
    title: 'Create your account',
    subtitle: 'A few details and you’re ready to order.',
    children: [
      const TextField(
        decoration: InputDecoration(
          labelText: 'Full name',
          prefixIcon: Icon(Icons.person_outline_rounded),
        ),
      ),
      const SizedBox(height: 12),
      const TextField(
        keyboardType: TextInputType.phone,
        decoration: InputDecoration(
          labelText: 'Phone number',
          prefixIcon: Icon(Icons.phone_outlined),
        ),
      ),
      const SizedBox(height: 12),
      const TextField(
        keyboardType: TextInputType.emailAddress,
        decoration: InputDecoration(
          labelText: 'Email',
          prefixIcon: Icon(Icons.mail_outline_rounded),
        ),
      ),
      const SizedBox(height: 12),
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
      const SizedBox(height: 12),
      TextField(
        obscureText: hidden,
        decoration: const InputDecoration(
          labelText: 'Confirm password',
          prefixIcon: Icon(Icons.lock_outline_rounded),
        ),
      ),
      const SizedBox(height: 22),
      PrimaryAction(
        label: 'Create account',
        onTap: () {
          message(
            context,
            'Account created successfully.',
            kind: ToastKind.success,
          );
          Navigator.of(context)
              .pushReplacement(slide(const AddressSetupPage(firstRun: true)));
        },
      ),
      const SizedBox(height: 12),
      const Text(
        'By creating an account, you agree to TalaDelivery’s terms and privacy policy.',
        textAlign: TextAlign.center,
        style: TextStyle(color: quiet, fontSize: 12),
      ),
    ],
  );
}

class ForgotPasswordPage extends StatelessWidget {
  const ForgotPasswordPage({super.key});
  @override
  Widget build(BuildContext context) => AuthScaffold(
    canPop: true,
    title: 'Reset password',
    subtitle: 'We’ll send recovery instructions to your account.',
    children: [
      const TextField(
        decoration: InputDecoration(
          labelText: 'Email or phone',
          prefixIcon: Icon(Icons.mail_outline_rounded),
        ),
      ),
      const SizedBox(height: 22),
      PrimaryAction(
        label: 'Send reset link',
        onTap: () => message(context, 'Reset instructions sent.'),
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
  });
  final String title;
  final String subtitle;
  final List<Widget> children;
  final bool canPop;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: canPop ? AppBar(backgroundColor: background) : null,
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
                ...children,
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
