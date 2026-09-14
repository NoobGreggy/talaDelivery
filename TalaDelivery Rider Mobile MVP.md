# TalaDelivery Rider App — MVP

**Version:** 1.0  
**App:** TalaDelivery Rider  
**Platform:** Flutter  
**Backend:** Laravel REST API  
**Database:** PostgreSQL  
**Authentication:** Laravel Sanctum  
**Target:** Android first  
**App Type:** Rider / Delivery App

---

# 1. Purpose

The TalaDelivery Rider App is a dedicated application for delivery riders.

The Rider App allows riders to:

- Login
- Go online/offline
- Receive delivery offers
- Accept/reject deliveries
- Navigate to stores
- Confirm arrival
- Confirm pickup
- Navigate to customers
- Complete deliveries
- Send location updates
- View delivery history
- View basic earnings

The Rider App must NOT contain customer shopping functionality.

---

# 2. Rider Flow

```text
Open App
    ↓
Login
    ↓
Rider Dashboard
    ↓
Go ONLINE
    ↓
Wait for Delivery
    ↓
Receive Delivery Offer
    ↓
Accept
    ↓
Navigate to Store
    ↓
Arrived
    ↓
Pickup Order
    ↓
Navigate to Customer
    ↓
Start Delivery
    ↓
Deliver Order
    ↓
Complete Delivery
    ↓
Back ONLINE
```

---

# 3. Flutter Project

Recommended project:

```text
tala-delivery-rider/
```

Structure:

```text
lib/
├── core/
│   ├── api/
│   ├── auth/
│   ├── storage/
│   ├── notifications/
│   ├── location/
│   └── config/
│
├── features/
│   ├── auth/
│   ├── dashboard/
│   ├── offers/
│   ├── deliveries/
│   ├── history/
│   ├── earnings/
│   └── profile/
│
├── shared/
│   ├── widgets/
│   ├── models/
│   └── theme/
│
└── main.dart
```

---

# 4. Authentication

Screens:

```text
Splash
Login
Forgot Password
```

Rider registration can initially be controlled by the platform admin.

Recommended MVP:

```text
Admin creates rider
       ↓
Rider receives credentials/invitation
       ↓
Rider logs in
```

Do not allow unrestricted rider self-registration initially.

---

# 5. Rider Dashboard

Route:

```text
/
```

Offline:

```text
--------------------------------
TalaDelivery Rider

Good evening, Juan

You're Offline

[ GO ONLINE ]

Today's Deliveries
8

Completed
6

Today's Earnings
₱540

--------------------------------
Home  History  Profile
--------------------------------
```

Online:

```text
--------------------------------
TalaDelivery Rider

● ONLINE

Waiting for deliveries...

Today's Deliveries
8

Today's Earnings
₱540

--------------------------------
Home  History  Profile
--------------------------------
```

---

# 6. Online / Offline

Button:

```text
GO ONLINE
```

API:

```http
POST /api/v1/rider/online
```

When online:

```text
is_online = true
status = ONLINE
```

Offline:

```http
POST /api/v1/rider/offline
```

Then:

```text
is_online = false
status = OFFLINE
```

A rider cannot receive delivery offers while offline.

---

# 7. Delivery Offer

This is the most important Rider App screen.

When the API matches a rider:

```text
NEW DELIVERY

ABC Mini Mart

Pickup
2.3 km away

Customer
4.8 km away

Estimated Distance
7.1 km

Delivery Fee
₱69

Estimated Earnings
₱69

        00:29

[ REJECT ]    [ ACCEPT ]
```

The rider has:

```text
30 seconds
```

to respond.

---

# 8. Offer Countdown

Countdown:

```text
00:30
00:29
00:28
...
00:01
00:00
```

At zero:

```text
Delivery offer expired.
```

The offer becomes:

```text
EXPIRED
```

The rider cannot accept an expired offer.

---

# 9. Accept Delivery

API:

```http
POST /api/v1/rider/offers/{offer}/accept
```

After success:

```text
Delivery Accepted

Pickup:
ABC Mini Mart

[ View Delivery ]
```

The delivery becomes:

```text
ACCEPTED
```

The rider becomes:

```text
BUSY
```

---

# 10. Reject Delivery

API:

```http
POST /api/v1/rider/offers/{offer}/reject
```

Optional rejection reason:

```text
Too far
Busy
Vehicle problem
Other
```

MVP can make the reason optional.

After rejection:

```text
Offer rejected.
```

The API will offer the delivery to another rider.

---

# 11. Delivery Detail

Route:

```text
/deliveries/:id
```

Display:

```text
DELIVERY #TD-100001

Pickup

ABC Mini Mart
123 Main Street

Distance:
2.3 km

[ NAVIGATE ]
```

---

# 12. Navigate to Store

MVP does not build its own navigation system.

Button:

```text
[ Navigate ]
```

Open:

```text
Google Maps
```

using the store coordinates.

---

# 13. Arrived at Store

Button:

```text
[ ARRIVED AT STORE ]
```

API:

```http
POST /api/v1/rider/deliveries/{delivery}/arrived
```

The API validates that the rider is assigned.

---

# 14. Pickup

After arrival:

```text
Order #TD-100001

ABC Mini Mart

Pickup Code:
8392

[ MARK AS PICKED UP ]
```

MVP pickup verification can use a simple pickup code.

Optional future improvement:

```text
QR Code
Barcode
Store confirmation
```

After pickup:

```text
delivery.status = PICKED_UP
```

---

# 15. Customer Delivery

Display:

```text
CUSTOMER

Juan Dela Cruz

123 Example Street
Cabanatuan City

Phone
09XXXXXXXXX

[ CALL CUSTOMER ]

[ NAVIGATE ]
```

---

# 16. Start Delivery

Button:

```text
[ START DELIVERY ]
```

API:

```http
POST /api/v1/rider/deliveries/{delivery}/start
```

Status:

```text
IN_TRANSIT
```

The customer sees:

```text
OUT FOR DELIVERY
```

---

# 17. COD Collection

For COD:

```text
Order Total

₱399

Payment:
CASH ON DELIVERY
```

Before completing:

```text
Amount to Collect

₱399
```

Rider confirms payment received.

MVP:

```text
Cash received
```

---

# 18. Complete Delivery

Button:

```text
[ MARK AS DELIVERED ]
```

Confirmation:

```text
Complete Delivery?

Order:
#TD-100001

Amount:
₱399

Payment:
COD

[ Cancel ]

[ Confirm ]
```

API:

```http
POST /api/v1/rider/deliveries/{delivery}/complete
```

After success:

```text
Delivery Completed

₱399 Collected

[ DONE ]
```

---

# 19. Rider Status After Delivery

After completion:

```text
delivery.status = DELIVERED
```

Rider:

```text
status = ONLINE
```

if the rider was previously online.

Then:

```text
Waiting for next delivery...
```

---

# 20. Location Tracking

Rider location is important for:

- Rider matching
- Delivery tracking
- Admin operations

API:

```http
POST /api/v1/rider/location
```

Payload:

```json
{
    "latitude": 15.4801,
    "longitude": 120.5902
}
```

When online:

```text
Every 15–30 seconds
```

During active delivery:

```text
Every 5–15 seconds
```

Do not continuously track the rider while completely offline.

---

# 21. Background Location

MVP approach:

```text
Online
  ↓
Location updates

Active delivery
  ↓
More frequent updates

Offline
  ↓
Stop tracking
```

Do not build complex background tracking infrastructure until the basic delivery flow is working.

---

# 22. Rider History

Route:

```text
/history
```

Example:

```text
Today's Deliveries

ABC Mini Mart
Delivered
₱69
10:42 AM

XYZ Grocery
Delivered
₱59
9:30 AM
```

Filters:

```text
Today
This Week
This Month
```

---

# 23. Earnings

MVP screen:

```text
Earnings

Today
₱540

This Week
₱3,240

Completed Deliveries
42
```

Delivery:

```text
Delivery #TD-100001

Delivery Fee
₱69

Status
Delivered
```

Do not build wallet withdrawal yet.

---

# 24. Profile

Route:

```text
/profile
```

Display:

```text
Juan Dela Cruz

Phone
09XXXXXXXXX

Vehicle
Motorcycle

Plate
ABC-1234
```

Options:

```text
Edit Profile
Change Password
Help
Logout
```

---

# 25. Push Notifications

Use Firebase Cloud Messaging.

Important rider notifications:

```text
New Delivery Offer
Offer Expiring
Delivery Cancelled
Customer Updated Address
Store Ready
```

New delivery offers should trigger a high-priority notification where supported.

---

# 26. Rider API Services

Create:

```text
AuthService
RiderService
OfferService
DeliveryService
LocationService
NotificationService
EarningsService
ProfileService
```

Do not put API requests directly inside UI widgets.

---

# 27. State Management

Recommended:

```text
Riverpod
```

Providers:

```text
authProvider
riderProvider
onlineStatusProvider
deliveryOfferProvider
activeDeliveryProvider
locationProvider
historyProvider
earningsProvider
profileProvider
```

---

# 28. Rider Delivery State Machine

The Flutter application must respect the API state.

```text
OFFER
 ↓
ACCEPTED
 ↓
ARRIVED
 ↓
PICKED_UP
 ↓
IN_TRANSIT
 ↓
DELIVERED
```

Invalid actions must not be shown.

Example:

```text
Before pickup:
Do not show "Complete Delivery"

After pickup:
Show "Start Delivery"

After IN_TRANSIT:
Show "Complete Delivery"
```

The API remains the final authority.

---

# 29. Offer Safety

Multiple riders may potentially receive offers.

When rider presses:

```text
ACCEPT
```

the API must verify:

```text
Offer still PENDING
Delivery still available
Offer not expired
Rider is eligible
```

If another rider already accepted:

```text
This delivery is no longer available.
```

The Flutter app must handle this gracefully.

---

# 30. Network Failure

Example:

```text
Unable to accept delivery.

Please check your internet connection.
```

Offer should not automatically be considered accepted unless the API confirms it.

For critical actions:

```text
Accept
Pickup
Start Delivery
Complete Delivery
```

show a loading state:

```text
Accepting...
```

Disable duplicate taps.

---

# 31. Rider Navigation

Bottom navigation:

```text
Home
History
Profile
```

During an active delivery, the delivery screen takes priority.

---

# 32. Rider UI Design

The Rider App should feel more operational than the Customer App.

Design:

```text
Sky Blue
White
Dark Gray
Large buttons
Clear status
Large touch targets
```

Prioritize:

```text
Fast actions
Readable information
Minimal typing
One-handed use
```

For example:

```text
[ ACCEPT DELIVERY ]
```

should be much more prominent than secondary actions.

---

# 33. Rider Safety UX

Do not overload the rider with information while moving.

Important actions should be simple:

```text
Navigate
Arrived
Picked Up
Start Delivery
Delivered
```

Avoid complex forms during active delivery.

---

# 34. Rider MVP Completion

Authentication:

- [ ] Splash
- [ ] Login
- [ ] Logout
- [ ] Session persistence

Availability:

- [ ] Go online
- [ ] Go offline
- [ ] Online status
- [ ] Location updates

Delivery offers:

- [ ] Receive offer
- [ ] Countdown
- [ ] Accept
- [ ] Reject
- [ ] Expire
- [ ] Handle already-accepted delivery

Pickup:

- [ ] Delivery detail
- [ ] Store location
- [ ] Navigate
- [ ] Arrived
- [ ] Pickup confirmation
- [ ] Pickup code

Delivery:

- [ ] Customer information
- [ ] Customer location
- [ ] Navigate
- [ ] Start delivery
- [ ] COD amount
- [ ] Complete delivery

Other:

- [ ] Push notifications
- [ ] Delivery history
- [ ] Basic earnings
- [ ] Profile
- [ ] Network error handling

---

# 35. Rider MVP Goal

The complete rider workflow must work:

```text
Login
 ↓
GO ONLINE
 ↓
Receive Offer
 ↓
Accept
 ↓
Navigate to Store
 ↓
Arrived
 ↓
Pickup
 ↓
Navigate to Customer
 ↓
Start Delivery
 ↓
Collect COD
 ↓
Complete Delivery
 ↓
Back ONLINE
```

The Rider App does NOT contain:

- Store browsing
- Shopping cart
- Customer checkout
- Customer order creation
- Customer addresses
- Product browsing
- Customer profile functionality
- Customer payment screens

It is a dedicated delivery operations app.