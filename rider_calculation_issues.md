# Rider fee and calculation audit

> Implementation status: executed on September 23, 2026. This file preserves
> the pre-implementation findings and requirements. See
> `rider_calculation_implementation_summary.md` for the resulting behavior,
> verification, deployment steps, and remaining limitations.

Updated September 23, 2026 after reviewing:

- rider branch `rider` at `db39812`
- API branch `feature/tala-api` at `7d474f0`
- admin branch `features/admin` at `470238c`

This document records the original code audit and implementation plan. The
local PostgreSQL service was unavailable during the audit, so the findings were
based on source code rather than a comparison with live records.

## What the admin application confirms

Delivery pricing is owned by the platform admin. The admin's **Delivery Zones**
screen creates, edits, activates, deactivates, and deletes zone records through
`/api/v1/admin/delivery-zones`.

Each zone contains:

- `name`
- `city`
- `province`
- `base_fee`
- `included_km`
- `extra_fee_per_km`
- `status`

The API calculates the customer delivery charge when an order is created:

```text
delivery_distance_km = straight-line distance from store to customer
extra_km = max(0, delivery_distance_km - included_km)
delivery_fee = base_fee + (extra_fee_per_km * extra_km)
order_total = product_subtotal + delivery_fee - discount
```

The calculated `delivery_fee` and `distance_km` are copied to the order and
delivery records. This snapshot is good: editing an admin zone later does not
recalculate old orders.

The current system then uses the same `delivery.delivery_fee` as the rider's
earnings:

```text
rider_earnings = sum(delivery.delivery_fee for DELIVERED deliveries)
```

This does not match the confirmed business rule. A rider earns a commission for
each successfully delivered order, not 100% of the delivery fee. The commission
becomes payable only after the delivery reaches `DELIVERED`. An order becoming
`READY_FOR_PICKUP` makes it eligible for rider handling but does not create
earnings by itself. Travel from the rider's current location to the pickup is
not part of customer pricing or rider commission distance.

## Confirmed calculation and admin-pricing defects

| Priority | Problem | Evidence | User impact | Required correction |
| --- | --- | --- | --- | --- |
| Critical | Missing delivery coordinates are converted to `(0, 0)` instead of remaining `null`. | `OrderController` permits nullable latitude/longitude, but `OrderService` casts a missing value to `float` before calling `PricingService`. PHP converts it to `0.0`, bypassing the pricing service's missing-coordinate guard. | An address without coordinates can produce a distance of thousands of kilometres, an extreme customer fee, and an extreme rider earning. | Pass nullable coordinates without converting missing values to zero. Prefer requiring a complete coordinate pair during checkout. Add tests for both missing and partially missing coordinates. |
| High | The admin's province field does not affect pricing. | The admin form saves `province`, but `PricingService.resolveZone(city, province)` only filters by exact `city`; the `province` argument is unused. | Admin can configure two same-named cities in different provinces, but pricing can select the wrong zone. A province-only zone is not deliberately matched. | Normalize and match both city and province. Define whether a city-only, province-only, or platform-default zone may be used as a fallback. |
| High | Multiple active zones can be ambiguous. | The delivery-zone migration has no unique constraint, the admin controller has no duplicate validation, and pricing selects the first matching active row without an explicit priority. | Two active zones for the same coverage can exist, and the selected fee depends on database row order rather than an admin-visible rule. | Enforce a unique active coverage rule or add explicit priority/specificity. Reject overlapping active zones unless the selection order is defined. |
| High | Disabling or deleting all admin zones silently enables hard-coded pricing. | If no active zone matches, `PricingService` uses the first arbitrary active zone; if none exists, it constructs an unsaved zone with `49` base fee, `5` included km, and `10` per extra km. These values are not visible in the admin UI. | Admin may believe pricing is disabled or fully configured while checkout charges an undisclosed fallback rate. | Create an explicit admin-managed default zone, or reject checkout with a clear “delivery unavailable for this area” response. Remove hidden production pricing constants. |
| High | Rider profile totals are not loaded by rider profile/status endpoints. | `RiderResource` reads `completed_deliveries` and `total_earnings`, but rider `profile`, `online`, `offline`, and `location` responses do not load the count or sum. Only the admin rider-detail endpoint currently loads them. | A rider with completed work can see zero deliveries and zero earnings. Going online/offline can replace previously loaded profile data with zeros. | Centralize rider profile loading so every relevant rider response includes the user, current delivery, delivered count, and delivered earnings sum. |
| High | Rider earnings incorrectly use 100% of the customer delivery fee. | Both rider Flutter totals and the admin rider-detail aggregate sum `delivery.delivery_fee`. There is no commission configuration, commission snapshot, or settlement field. | Rider earnings and platform financial totals cannot follow the confirmed commission-based policy. | Define the commission formula, configure it in admin, snapshot the calculated `rider_commission` on the delivery, and recognize it only when status becomes `DELIVERED`. Never recalculate historical commission after the rate changes. |
| High | The rider offer calls pickup-to-drop-off straight-line distance the “total” distance. | The stored value is Haversine distance from store/pickup coordinates to customer/drop-off coordinates. Rider-to-pickup travel is used for matching but is not part of the stored pricing distance. | The label is inaccurate. The confirmed pricing scope starts at pickup and excludes the rider's travel to pickup. It is still unclear whether billable kilometres must follow roads or straight-line geometry. | Rename the current value to “Delivery distance.” Keep rider-to-pickup distance separate and non-billable. Confirm whether the pickup-to-drop-off kilometres must come from a road-routing service before changing the calculation method. |
| Medium | The admin delivery detail reads the wrong distance field. | Laravel returns `distance_km`; the admin `Delivery` interface and detail template use `distance`. There is no service mapper converting it. | Admin delivery detail displays `0 km` even when the API calculated and stored a non-zero distance, making fee investigation misleading. | Rename the admin model/template field to `distance_km`, or map the API response explicitly. Add a frontend contract test. |
| Medium | The admin's “Base Fee” summary is not a platform default. | The zone screen displays `zones()[0]?.base_fee`. The API returns the latest paginated zone first, regardless of status or coverage. | The summary can display an inactive or location-specific rate as though it were the general base fee. | Remove the summary or label it with the selected zone. If a default zone is introduced, show that explicit record instead. |
| Medium | The admin zone screen only loads the first API page but presents its counts as totals. | `ZoneService.load()` does not request subsequent pages; the API defaults to 15 rows. `Total Zones`, `Active`, filtering, and the first-zone base-fee summary use only that page. | With more than 15 zones, admin sees incomplete counts and cannot manage older zones from this screen. | Add server-backed pagination/filtering or deliberately request and handle all zones. Use pagination metadata for total counts. |
| Medium | The rider history “Week” filter accepts future timestamps. | Its condition checks that `now.difference(date).inDays < 7` without ensuring the difference is non-negative. | A future timestamp caused by bad data or clock drift is counted in this week's deliveries and earnings. | Require the timestamp to be between the start and end of the selected period, or calculate the period on the server. |
| Medium | Period totals are calculated independently on the phone. | Dashboard and history download deliveries and sum `delivery_fee` using device time. | Totals depend on device timezone/clock, pagination completeness, and local filtering. Different clients can disagree. | Add an API earnings-summary endpoint with explicit timezone and date boundaries. Keep history as the itemized view. |
| Medium | `createdAt` sometimes contains `delivered_at`. | `RiderDelivery.fromJson` assigns `delivered_at ?? created_at` to `createdAt`. | The model hides which timestamp drives an earnings period and can be misused by later features. | Model `createdAt` and `deliveredAt` separately. Use `deliveredAt` for completed-delivery earnings. |
| Low | The rider offer progress fallback uses two minutes while backend offers use five minutes. | Flutter's fallback countdown window is `120` seconds; the API creates offers with a five-minute expiry. | If `offered_at` is absent, the progress ring can disagree with the actual `expires_at` countdown. | Derive the window from server timestamps or return an offer-duration field. Do not hard-code a second duration in Flutter. |

## Confirmed business rules

1. **Rider earnings:** a rider receives a commission for every delivery that
   reaches `DELIVERED`; the rider does not receive the full customer delivery
   fee.
2. **Eligibility:** rider handling begins when the merchant marks the order
   `READY_FOR_PICKUP`. No commission is earned for merely receiving, accepting,
   or picking up an order.
3. **Distance scope:** billable distance starts at the merchant/pickup location
   and ends at the customer/drop-off location. Rider-to-pickup travel is not
   included.
4. **Invalid coordinates:** checkout must decline the order and clearly notify
   the customer when a valid pickup/drop-off coordinate pair is unavailable.
5. **Zone fallback:** delivery pricing is city-wide. A checkout must select the
   active zone assigned to that city; it must not use the first unrelated
   active zone or hidden hard-coded rates.
6. **Earnings window:** only delivered orders belong in rider earnings totals.

Flutter must display the server-provided commission value. It must not infer
rider earnings from the customer delivery fee.

## Details still requiring an exact rule

These answers provide the intended direction but still need precise values or
definitions before financial code can be implemented safely:

1. **Commission formula:** percentage of delivery fee, fixed amount, tiered
   amount, or another formula; also specify rounding and who can edit it.
2. **Distance method:** pickup-to-drop-off scope is confirmed, but specify
   whether kilometres come from straight-line Haversine distance or a road
   routing service.
3. **Week definition:** “yes” does not choose between a rolling seven-day
   period and a calendar week. Specify one and, for a calendar week, its first
   day.
4. **Timezone:** `12:00–24:00` is a clock range, not a timezone. Specify a named
   timezone such as `Asia/Manila` and clarify whether the daily window is
   `00:00–23:59:59`, `12:00–24:00`, or another settlement schedule.
5. **City identity:** specify whether a city is uniquely identified by
   `city + province`, which avoids collisions between same-named cities.

## Missing automated coverage

`AdminDeliveryZoneTest::test_admin_created_zone_is_used_by_pricing` currently
checks only that the zone row was saved. It does not call `PricingService` or
create an order, so it does not prove that admin-entered city/province/rates are
selected during checkout.

Add tests for:

1. exact city-and-province selection;
2. the same city name in two provinces;
3. case and whitespace normalization;
4. inactive and overlapping zones;
5. no matching/default zone;
6. no active zones;
7. missing and partial coordinate pairs;
8. exact fee at, below, and above `included_km`;
9. admin rate edits affecting new orders but not historical snapshots;
10. non-zero rider totals from profile, online, offline, and location responses;
11. commission created only when a delivery reaches `DELIVERED`;
12. cancelled, failed, and incomplete deliveries producing no commission;
13. commission-rate edits not changing historical delivered commissions;
14. invalid coordinates declining checkout with a customer-readable message.

## Recommended implementation order

1. **Protect checkout totals.** Preserve nullable coordinates, require a valid
   pair, and test the boundary cases.
2. **Make admin pricing deterministic.** Match normalized city and province,
   prevent ambiguous active zones, and replace the hard-coded fallback with an
   explicit default or unavailable-area response.
3. **Implement rider commission.** After the exact formula is supplied, add an
   admin-managed commission rule and an immutable `rider_commission` snapshot.
   Accrue it only when a delivery reaches `DELIVERED`.
4. **Return authoritative rider totals.** Load aggregates on every rider
   profile/status response, then add a server-side earnings summary by period.
5. **Correct admin visibility.** Use `distance_km`, fix the misleading base-fee
   card, and paginate the zone management screen.
6. **Clarify distance in Flutter.** Separate pickup, drop-off, and total-route
   distance, and label unavailable values honestly.
7. **Simplify rider date calculations.** Parse creation and delivery timestamps
   separately and use server-defined period totals.

## Acceptance criteria

- An incomplete coordinate pair declines checkout and notifies the customer; it
  cannot become `(0, 0)` or produce an extreme delivery fee.
- A checkout address selects exactly the intended admin zone using the agreed
  city/province rules.
- Overlapping zones cannot cause nondeterministic pricing.
- Checkout uses the one active city-wide zone. An unmatched city is declined;
  no unrelated or hidden default fee is charged.
- Rates edited in admin affect new orders only; existing order and delivery fee
  snapshots remain unchanged.
- Admin and rider surfaces display the same stored `distance_km` and delivery
  fee for a delivery.
- The rider profile returns correct non-zero completed count and earnings after
  completed deliveries.
- Customer delivery charge and rider commission are separate stored values.
- Commission is earned only for `DELIVERED` work; ready, assigned, picked-up,
  cancelled, and failed deliveries do not count as earnings.
- Today/week/month totals use `delivered_at`, an agreed timezone, and complete
  server-side data.
- Offers distinguish pickup distance, delivery distance, and total route where
  those values exist.

## Files involved

### Admin

- `../tala_delivery_admin/src/app/features/zones/zone-list/zone-list.ts`
- `../tala_delivery_admin/src/app/features/zones/zone-list/zone-list.html`
- `../tala_delivery_admin/src/app/core/services/zone.service.ts`
- `../tala_delivery_admin/src/app/core/models/index.ts`
- `../tala_delivery_admin/src/app/features/deliveries/delivery-detail/delivery-detail.html`

### API

- `../tala_delivery_api/app/Http/Controllers/Admin/AdminDeliveryZoneController.php`
- `../tala_delivery_api/app/Http/Controllers/Admin/AdminRiderController.php`
- `../tala_delivery_api/app/Http/Controllers/Rider/RiderController.php`
- `../tala_delivery_api/app/Http/Resources/DeliveryResource.php`
- `../tala_delivery_api/app/Http/Resources/RiderResource.php`
- `../tala_delivery_api/app/Services/OrderService.php`
- `../tala_delivery_api/app/Services/PricingService.php`
- `../tala_delivery_api/database/migrations/2026_09_11_141857_create_delivery_zones_table.php`
- `../tala_delivery_api/tests/Feature/AdminDeliveryZoneTest.php`

### Rider

- `lib/rider/features/dashboard/rider_dashboard_screen.dart`
- `lib/rider/features/history/rider_history_screen.dart`
- `lib/rider/features/offers/rider_offer_screen.dart`
- `lib/rider/shared/models/rider_models.dart`

WebSocket delivery is not the source of these calculation defects. Realtime
events can make a value appear sooner, but fee selection, distance meaning, and
rider accounting must be authoritative in the API and data model.
