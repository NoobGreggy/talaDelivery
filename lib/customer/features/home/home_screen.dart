part of '../../app.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 17, 20, 28),
      children: [
        Row(
          children: [
            const CircleAvatar(
              radius: 22,
              backgroundColor: Color(0xFFE1F0FD),
              child: Text(
                'GG',
                style: TextStyle(color: sky, fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Good evening,',
                    style: TextStyle(color: quiet, fontSize: 12),
                  ),
                  Text('Gregg', style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
            ),
            IconButton.filledTonal(
              onPressed: () =>
                  Navigator.pushNamed(context, CustomerRoutes.notifications),
              icon: const Badge(
                smallSize: 8,
                child: Icon(Icons.notifications_none_rounded),
              ),
            ),
            const SizedBox(width: 3),
            IconButton.filledTonal(
              onPressed: () =>
                  Navigator.pushNamed(context, CustomerRoutes.cart),
              icon: Badge.count(
                count: 3,
                child: Icon(Icons.shopping_cart_outlined),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Material(
          color: const Color(0xFFE7F4FF),
          borderRadius: BorderRadius.circular(17),
          child: InkWell(
            borderRadius: BorderRadius.circular(17),
            onTap: () => Navigator.pushNamed(context, CustomerRoutes.addresses),
            child: const Padding(
              padding: EdgeInsets.all(15),
              child: Row(
                children: [
                  Icon(Icons.location_on_rounded, color: sky),
                  SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DELIVER TO',
                          style: TextStyle(
                            color: sky,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                        Text(
                          'Home • Cabanatuan City',
                          style: TextStyle(
                            color: text,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.keyboard_arrow_down_rounded, color: sky),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          readOnly: true,
          onTap: () => Navigator.pushNamed(context, CustomerRoutes.stores),
          decoration: const InputDecoration(
            hintText: 'Search stores or products',
            prefixIcon: Icon(Icons.search_rounded),
            suffixIcon: Icon(Icons.tune_rounded),
          ),
        ),
        const SizedBox(height: 26),
        const SectionHeading(title: 'Categories'),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: CategoryButton(
                label: 'Food',
                icon: Icons.restaurant_rounded,
                color: Color(0xFFFF8749),
                onTap: () => openStores(context, 1),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: CategoryButton(
                label: 'Grocery',
                icon: Icons.local_grocery_store_rounded,
                color: sky,
                onTap: () => openStores(context, 2),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: CategoryButton(
                label: 'Pharmacy',
                icon: Icons.medication_rounded,
                color: Color(0xFF18AF78),
                onTap: () => openStores(context, 3),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: CategoryButton(
                label: 'Other',
                icon: Icons.grid_view_rounded,
                color: Color(0xFF7659E9),
                onTap: () => openStores(context, 4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 27),
        SectionHeading(
          title: 'Nearby stores',
          action: 'See all',
          onTap: () => openStores(context, 0),
        ),
        const SizedBox(height: 13),
        StoreCard(
          store: stores[0],
          onTap: () => Navigator.pushNamed(
            context,
            CustomerRoutes.storeDetails,
            arguments: stores[0],
          ),
        ),
        const SizedBox(height: 13),
        StoreCard(
          store: stores[1],
          onTap: () => Navigator.pushNamed(
            context,
            CustomerRoutes.storeDetails,
            arguments: stores[1],
          ),
        ),
        const SizedBox(height: 13),
        StoreCard(
          store: stores[2],
          onTap: () => Navigator.pushNamed(
            context,
            CustomerRoutes.storeDetails,
            arguments: stores[2],
          ),
        ),
      ],
    ),
  );
}

void openStores(BuildContext context, int filter) =>
    Navigator.pushNamed(context, CustomerRoutes.stores, arguments: filter);
