part of '../../app.dart';

class AddressSetupPage extends StatefulWidget {
  const AddressSetupPage({
    super.key,
    this.firstRun = false,
    this.editing = false,
  });
  final bool firstRun;
  final bool editing;
  @override
  State<AddressSetupPage> createState() => _AddressSetupPageState();
}

class _AddressSetupPageState extends State<AddressSetupPage> {
  int mode = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: widget.firstRun
        ? null
        : simpleBar(widget.editing ? 'Edit address' : 'Add address'),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              children: [
                if (widget.firstRun) ...[
                  const Brand(size: 24),
                  const SizedBox(height: 28),
                ],
                Text(
                  widget.editing
                      ? 'Update delivery address'
                      : 'Where should we deliver?',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'A delivery address is required before you can browse stores.',
                ),
                const SizedBox(height: 22),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(
                      value: 0,
                      icon: Icon(Icons.my_location_rounded),
                      label: Text('Current'),
                    ),
                    ButtonSegment(
                      value: 1,
                      icon: Icon(Icons.bookmark_outline_rounded),
                      label: Text('Saved'),
                    ),
                    ButtonSegment(
                      value: 2,
                      icon: Icon(Icons.edit_location_alt_outlined),
                      label: Text('Manual'),
                    ),
                  ],
                  selected: {mode},
                  showSelectedIcon: false,
                  onSelectionChanged: (value) =>
                      setState(() => mode = value.first),
                ),
                const SizedBox(height: 18),
                if (mode == 0)
                  InfoCard(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.my_location_rounded,
                          color: sky,
                          size: 36,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Use your current location',
                          style: TextStyle(
                            color: text,
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'We’ll position the address pin for you.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: () => message(
                            context,
                            'Location found near Cabanatuan City.',
                          ),
                          icon: const Icon(Icons.gps_fixed_rounded),
                          label: const Text('Find my location'),
                        ),
                      ],
                    ),
                  )
                else if (mode == 1)
                  const SavedAddressPicker()
                else
                  const SizedBox.shrink(),
                const SizedBox(height: 18),
                const TextField(
                  decoration: InputDecoration(
                    labelText: 'Recipient name',
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
                  decoration: InputDecoration(
                    labelText: 'Street address',
                    prefixIcon: Icon(Icons.home_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                const Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(labelText: 'Barangay'),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(labelText: 'City'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const TextField(
                  decoration: InputDecoration(labelText: 'Province'),
                ),
                const SizedBox(height: 12),
                const Row(
                  children: [
                    Expanded(
                      child: TextField(
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Latitude',
                          hintText: '15.486',
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Longitude',
                          hintText: '120.967',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const TextField(
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Delivery notes',
                    hintText: 'Landmark, gate color, or instructions',
                  ),
                ),
              ],
            ),
          ),
          BottomAction(
            label: widget.editing ? 'Save changes' : 'Save delivery address',
            onTap: () {
              message(
                context,
                widget.editing
                    ? 'Address changes saved.'
                    : 'Delivery address saved.',
                kind: ToastKind.success,
              );
              if (widget.firstRun) {
                Navigator.of(
                  context,
                ).pushAndRemoveUntil(fade(const CustomerShell()), (_) => false);
              } else {
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    ),
  );
}

class AddressesPage extends StatefulWidget {
  const AddressesPage({super.key});
  @override
  State<AddressesPage> createState() => _AddressesPageState();
}

class _AddressesPageState extends State<AddressesPage> {
  int selected = 0;
  bool showWork = true;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: simpleBar('My addresses'),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        AddressCard(
          label: 'Home',
          address: '123 Example Street\nCabanatuan City, Nueva Ecija',
          selected: selected == 0,
          onDefault: () => setState(() => selected = 0),
          onEdit: () => Navigator.push(
            context,
            slide(const AddressSetupPage(editing: true)),
          ),
          onDelete: null,
        ),
        if (showWork) ...[
          const SizedBox(height: 12),
          AddressCard(
            label: 'Work',
            address: 'Maharlika Highway\nCabanatuan City, Nueva Ecija',
            selected: selected == 1,
            onDefault: () {
              setState(() => selected = 1);
              message(
                context,
                'Work is now your default address.',
                kind: ToastKind.success,
              );
            },
            onEdit: () => Navigator.push(
              context,
              slide(const AddressSetupPage(editing: true)),
            ),
            onDelete: () async {
              final confirmed = await confirmAction(
                context,
                title: 'Delete Work address?',
                body: 'This saved address will be removed from your account.',
                confirmLabel: 'Delete address',
                destructive: true,
              );
              if (context.mounted && confirmed) {
                setState(() => showWork = false);
                message(
                  context,
                  'Work address deleted.',
                  kind: ToastKind.success,
                );
              }
            },
          ),
        ],
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: () =>
              Navigator.push(context, slide(const AddressSetupPage())),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
            side: const BorderSide(color: sky),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add new address'),
        ),
      ],
    ),
  );
}
