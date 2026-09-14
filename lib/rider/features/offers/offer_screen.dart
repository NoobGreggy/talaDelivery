part of '../../app.dart';

class OfferScreen extends StatefulWidget {
  const OfferScreen({super.key});
  @override
  State<OfferScreen> createState() => _OfferScreenState();
}

class _OfferScreenState extends State<OfferScreen> {
  int seconds = 30;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && seconds > 0) setState(() => seconds--);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expired = seconds == 0;
    return Scaffold(
      backgroundColor: navy,
      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        title: const Text(
          'New delivery',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: canvas,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 28),
            child: Column(
              children: [
                SizedBox(
                  width: 106,
                  height: 106,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: seconds / 30,
                        strokeWidth: 8,
                        color: expired ? muted : blue,
                        backgroundColor: const Color(0xFFDCE7F1),
                      ),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '00:${seconds.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.w900,
                                color: ink,
                              ),
                            ),
                            const Text(
                              'TO RESPOND',
                              style: TextStyle(
                                fontSize: 9,
                                color: muted,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  expired ? 'Offer expired' : '₱69 estimated earnings',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                const Text('7.1 km total  •  About 28 min'),
                const SizedBox(height: 22),
                const RouteCard(),
                const SizedBox(height: 14),
                const Row(
                  children: [
                    Expanded(
                      child: MiniInfo(
                        icon: Icons.route_rounded,
                        label: 'Distance',
                        value: '7.1 km',
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: MiniInfo(
                        icon: Icons.payments_outlined,
                        label: 'Payment',
                        value: 'COD ₱399',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                if (!expired) ...[
                  PrimaryButton(
                    label: 'Accept delivery',
                    icon: Icons.check_rounded,
                    onPressed: () {
                      showMessage(
                        context,
                        'Delivery accepted. Head to the pickup location.',
                        kind: RiderToastKind.success,
                      );
                      Navigator.of(context).pushReplacement(
                        slideRoute(const ActiveDeliveryScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      side: const BorderSide(color: Color(0xFFD3DEE9)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () async {
                      final confirmed = await confirmRiderAction(
                        context,
                        title: 'Reject this offer?',
                        body: 'The delivery will be offered to another nearby rider.',
                        confirmLabel: 'Reject offer',
                        destructive: true,
                      );
                      if (context.mounted && confirmed) {
                        showMessage(
                          context,
                          'Delivery offer rejected.',
                          kind: RiderToastKind.warning,
                        );
                        Navigator.pop(context);
                      }
                    },
                    child: const Text(
                      'Reject',
                      style: TextStyle(color: ink, fontWeight: FontWeight.w700),
                    ),
                  ),
                ] else
                  PrimaryButton(
                    label: 'Back to dashboard',
                    onPressed: () => Navigator.pop(context),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
