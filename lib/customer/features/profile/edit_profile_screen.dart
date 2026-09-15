part of '../../app.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  CustomerProfileViewModel? _viewModel;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_viewModel != null) return;
    final user = CustomerRouteScope.of(context).session.user;
    _name.text = user?.name ?? '';
    _email.text = user?.email ?? '';
    _phone.text = user?.phone ?? '';
    _viewModel = CustomerProfileViewModel(
      CustomerDependencyScope.of(context).authRepository,
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _viewModel?.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;
    final user = await _viewModel!.update(
      name: _name.text,
      email: _email.text,
      phone: _phone.text,
    );
    if (!mounted) return;
    if (user == null) {
      message(
        context,
        _viewModel!.errorMessage ?? 'Your profile could not be updated.',
        kind: ToastKind.error,
      );
      return;
    }
    CustomerRouteScope.of(context).session.user = user;
    message(context, 'Profile updated successfully.', kind: ToastKind.success);
    Navigator.pop(context, user);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Edit profile')),
    body: SafeArea(
      top: false,
      child: ListenableBuilder(
        listenable: _viewModel!,
        builder: (context, _) => Form(
          key: _formKey,
          autovalidateMode: _submitted
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
            children: [
              Text(
                'Account details',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              const Text(
                'Keep your contact details accurate for orders and delivery updates.',
              ),
              const SizedBox(height: 24),
              TextFormField(
                key: const Key('profile-name'),
                controller: _name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                validator: CustomerValidators.name,
                decoration: InputDecoration(
                  labelText: 'Full name',
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                  errorText: _viewModel!.fieldError('name'),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const Key('profile-email'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: CustomerValidators.email,
                decoration: InputDecoration(
                  labelText: 'Email address',
                  prefixIcon: const Icon(Icons.mail_outline_rounded),
                  errorText: _viewModel!.fieldError('email'),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const Key('profile-phone'),
                controller: _phone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                validator: (value) => CustomerValidators.phone(value),
                onFieldSubmitted: (_) => _save(),
                decoration: InputDecoration(
                  labelText: 'Phone number (optional)',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  errorText: _viewModel!.fieldError('phone'),
                ),
              ),
              if (_viewModel!.errorMessage != null) ...[
                const SizedBox(height: 14),
                Text(
                  _viewModel!.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 28),
              PrimaryAction(
                label: _viewModel!.isSubmitting ? 'Saving…' : 'Save changes',
                icon: _viewModel!.isSubmitting ? null : Icons.check_rounded,
                onTap: _viewModel!.isSubmitting ? null : _save,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
