# TalaDelivery API — MVP

**Version:** 1.0  
**Product:** TalaDelivery  
**Backend:** Laravel  
**Database:** PostgreSQL  
**API:** REST `/api/v1`  
**Authentication:** Laravel Sanctum  
**Status:** MVP

---

## 1. Purpose

TalaDelivery is a local delivery platform connecting:

- Customers
- Stores
- Riders
- Platform Administrators

The Laravel API is the central source of truth for:

- Users
- Stores
- Products
- Orders
- Deliveries
- Rider assignment
- Delivery pricing
- Notifications
- Delivery status

The MVP must support this complete flow:

```text
Customer
    ↓
Browse Store
    ↓
Create Order
    ↓
Store Accepts
    ↓
Store Prepares
    ↓
Order Ready
    ↓
Automatic Rider Matching
    ↓
Rider Receives Offer
    ↓
Rider Accepts
    ↓
Pickup
    ↓
Delivery
    ↓
Customer Receives Order
```

---

# 2. Technology

## Backend

- Laravel
- PHP 8.3+
- PostgreSQL
- Laravel Sanctum
- Laravel Notifications
- Laravel Queues
- Laravel Scheduler

## MVP Realtime Strategy

Use polling first.

```text
Flutter
   ↓
GET /orders/{id}
   ↓
Every 5–10 seconds
```

Do not require WebSockets for MVP.

Laravel Reverb can be added later.

---

# 3. User Roles

```text
platform_admin
store_admin
rider
customer
```

## platform_admin

Can manage:

- Stores
- Riders
- Customers
- Orders
- Deliveries
- Delivery zones
- Pricing
- Platform settings

## store_admin

Can manage:

- Store profile
- Products
- Categories
- Incoming orders
- Order preparation
- Store status

## rider

Can:

- Go online/offline
- Receive delivery offers
- Accept/reject offers
- View assigned delivery
- Update pickup status
- Update delivery status

## customer

Can:

- Browse stores
- Browse products
- Create orders
- Track orders
- View order history
- Manage addresses

---

# 4. Core Database

## users

```text
id
name
email
phone
password
role
status
created_at
updated_at
```

Roles:

```text
platform_admin
store_admin
rider
customer
```

---

## stores

```text
id
name
slug
description
phone
email
address
latitude
longitude
status
opening_time
closing_time
created_at
updated_at
```

Statuses:

```text
ACTIVE
INACTIVE
SUSPENDED
```

---

## store_users

```text
id
store_id
user_id
role
created_at
updated_at
```

---

## categories

```text
id
store_id
name
description
status
created_at
updated_at
```

---

## products

```text
id
store_id
category_id
name
description
sku
price
image
stock
is_available
created_at
updated_at
```

---

## addresses

```text
id
user_id
label
recipient_name
phone
address_line
barangay
city
province
postal_code
latitude
longitude
notes
is_default
created_at
updated_at
```

---

# 5. Orders

## orders

```text
id
order_number
customer_id
store_id

subtotal
delivery_fee
discount
total

payment_method
payment_status

status

customer_name
customer_phone

delivery_address
delivery_latitude
delivery_longitude

notes

confirmed_at
prepared_at
ready_at
delivered_at
cancelled_at

created_at
updated_at
```

---

## Order Status

```text
PENDING
CONFIRMED
PREPARING
READY_FOR_PICKUP
RIDER_ASSIGNED
PICKED_UP
OUT_FOR_DELIVERY
DELIVERED
CANCELLED
```

---

## order_items

```text
id
order_id
product_id
product_name
quantity
unit_price
subtotal
created_at
updated_at
```

Store product information must be copied into the order item.

This prevents historical orders from changing when the product price changes.

---

# 6. Deliveries

## deliveries

```text
id
order_id
rider_id

status

pickup_address
pickup_latitude
pickup_longitude

delivery_address
delivery_latitude
delivery_longitude

distance_km
delivery_fee

assigned_at
accepted_at
picked_up_at
started_at
delivered_at
cancelled_at

created_at
updated_at
```

---

# 7. Delivery Status

```text
UNASSIGNED
ASSIGNED
ACCEPTED
PICKED_UP
IN_TRANSIT
DELIVERED
FAILED
CANCELLED
```

---

# 8. Rider

## riders

```text
id
user_id

vehicle_type
vehicle_plate

is_online
status

current_latitude
current_longitude

created_at
updated_at
```

Vehicle types:

```text
MOTORCYCLE
BICYCLE
CAR
```

Rider status:

```text
OFFLINE
ONLINE
BUSY
SUSPENDED
```

---

# 9. Delivery Offers

The rider must accept the delivery.

The admin should NOT manually assign every delivery.

## delivery_offers

```text
id
delivery_id
rider_id

status

offered_at
expires_at
responded_at

created_at
updated_at
```

Statuses:

```text
PENDING
ACCEPTED
REJECTED
EXPIRED
```

---

# 10. Rider Matching

When an order becomes:

```text
READY_FOR_PICKUP
```

Laravel starts rider matching.

### Algorithm

```text
1. Find online riders
2. Exclude BUSY riders
3. Calculate distance to store
4. Sort nearest first
5. Send offer to nearest rider
6. Rider gets 30 seconds
7. Rider accepts
      ↓
   assign rider
8. Rider rejects
      ↓
   next rider
9. Offer expires
      ↓
   next rider
10. No rider available
      ↓
   delivery remains UNASSIGNED
```

MVP does NOT require AI dispatch.

---

# 11. Rider Offer Rules

Only one rider should hold the active offer at a time.

Example:

```text
Delivery #1001

Rider A
↓
Offer 30 seconds
↓
Rejected

Rider B
↓
Offer 30 seconds
↓
Expired

Rider C
↓
Accept
↓
Assigned
```

Use database transactions and locking when accepting an offer.

Only one rider can successfully accept a delivery.

---

# 12. Delivery Pricing

MVP uses distance-based pricing.

Example:

```text
Base Fee: ₱49
Included Distance: 5 km
Extra Distance: ₱10/km
```

Example:

```text
3 km
= ₱49

5 km
= ₱49

7 km
= ₱69
```

The values must come from configurable settings.

---

# 13. Delivery Zones

## delivery_zones

```text
id
name
city
province

base_fee
included_km
extra_fee_per_km

status

created_at
updated_at
```

MVP can use simple distance validation.

Polygon/geofencing can be added later.

---

# 14. Payments

MVP:

```text
COD
```

Payment statuses:

```text
PENDING
PAID
FAILED
REFUNDED
```

Future:

```text
GCash
Maya
Card
Online Payment
```

Do not integrate payment gateways in the first MVP.

---

# 15. Notifications

## notifications

```text
id
user_id
type
title
message
data
read_at
created_at
updated_at
```

Important notifications:

### Customer

```text
Order received
Order confirmed
Order preparing
Order ready
Rider assigned
Rider picked up
Out for delivery
Delivered
Cancelled
```

### Store

```text
New order
Customer cancelled
Rider assigned
Rider arrived
```

### Rider

```text
New delivery offer
Offer expired
Delivery assigned
Pickup reminder
```

FCM can be used for push notifications.

---

# 16. API Routes

Base:

```text
/api/v1
```

---

## Authentication

```http
POST /auth/register
POST /auth/login
POST /auth/logout
GET  /auth/me
```

---

# Stores

```http
GET /stores
GET /stores/{store}
GET /stores/{store}/categories
GET /stores/{store}/products
```

---

# Products

```http
GET /products
GET /products/{product}
```

---

# Addresses

```http
GET    /addresses
POST   /addresses
GET    /addresses/{address}
PUT    /addresses/{address}
DELETE /addresses/{address}
```

---

# Orders

```http
GET  /orders
POST /orders
GET  /orders/{order}
POST /orders/{order}/cancel
```

---

# Store Orders

```http
GET  /store/orders
GET  /store/orders/{order}

POST /store/orders/{order}/confirm
POST /store/orders/{order}/preparing
POST /store/orders/{order}/ready
POST /store/orders/{order}/cancel
```

---

# Rider

```http
POST /rider/online
POST /rider/offline

GET /rider/profile
GET /rider/offers
GET /rider/deliveries

POST /rider/offers/{offer}/accept
POST /rider/offers/{offer}/reject

POST /rider/deliveries/{delivery}/arrived
POST /rider/deliveries/{delivery}/pickup
POST /rider/deliveries/{delivery}/start
POST /rider/deliveries/{delivery}/complete

POST /rider/location
```

---

# Admin

```http
GET /admin/dashboard

GET /admin/orders
GET /admin/orders/{order}

GET /admin/stores
POST /admin/stores
PUT /admin/stores/{store}

GET /admin/riders
GET /admin/riders/{rider}

GET /admin/customers

GET /admin/deliveries
GET /admin/deliveries/{delivery}

POST /admin/deliveries/{delivery}/assign
POST /admin/deliveries/{delivery}/cancel
```

---

# 17. API Response Format

Success:

```json
{
    "success": true,
    "message": "Order created successfully.",
    "data": {}
}
```

Error:

```json
{
    "success": false,
    "message": "Unable to create order.",
    "errors": {}
}
```

---

# 18. Laravel Structure

```text
app/
├── Actions/
│   ├── Orders/
│   ├── Deliveries/
│   └── Riders/
│
├── Http/
│   ├── Controllers/
│   ├── Requests/
│   └── Resources/
│
├── Models/
│
├── Services/
│   ├── OrderService.php
│   ├── DeliveryService.php
│   ├── PricingService.php
│   ├── RiderMatchingService.php
│   └── NotificationService.php
│
├── Notifications/
│
├── Policies/
│
└── Jobs/
    ├── MatchRider.php
    ├── ExpireDeliveryOffer.php
    └── SendNotification.php
```

---

# 19. Important Business Rules

## Order

Customer cannot modify an order after store confirmation.

## Store

Store can only mark an order READY after confirming/preparing it.

## Rider

Rider cannot accept another delivery while BUSY.

## Delivery

Only the assigned rider can update pickup/delivery states.

## Offer

Expired offers cannot be accepted.

## Completion

Delivery can only be completed after pickup.

## Cancellation

Every cancellation must record:

```text
cancelled_by
cancellation_reason
cancelled_at
```

---

# 20. MVP Realtime

Do NOT build WebSockets initially.

Flutter can poll:

```text
GET /orders/{order}
```

every:

```text
5–10 seconds
```

Rider can poll:

```text
GET /rider/offers
```

every:

```text
5 seconds
```

Later:

```text
Laravel Reverb
WebSockets
FCM
```

---

# 21. TalaPOS Integration — Future

TalaDelivery should eventually integrate with TalaPOS.

Future flow:

```text
TalaDelivery
      ↓
Create Order
      ↓
TalaPOS
      ↓
Store receives order
      ↓
Prepare
      ↓
Ready
      ↓
TalaDelivery
      ↓
Find Rider
```

For MVP, TalaDelivery can manage its own products.

Do not make TalaPOS integration a blocker for the first release.

---

# 22. API MVP Completion Criteria

The API MVP is complete when:

- [ ] Authentication works
- [ ] Customer registration works
- [ ] Store CRUD works
- [ ] Product CRUD works
- [ ] Customer can browse stores
- [ ] Customer can browse products
- [ ] Customer can create order
- [ ] Store receives order
- [ ] Store can confirm order
- [ ] Store can mark preparing
- [ ] Store can mark ready
- [ ] Rider can go online
- [ ] System can find riders
- [ ] Rider receives offer
- [ ] Rider can accept
- [ ] Rider can reject
- [ ] Offer expiration works
- [ ] Next rider receives offer
- [ ] Admin can manually assign rider
- [ ] Rider can pickup
- [ ] Rider can start delivery
- [ ] Rider can complete delivery
- [ ] Customer can track order
- [ ] Notifications work
- [ ] COD works
- [ ] Delivery fee calculation works
- [ ] PostgreSQL migrations work
- [ ] API authorization works
- [ ] API validation works
- [ ] API tests cover critical flows

---

# 23. MVP Rule

Do not build:

- Wallet
- Loyalty
- Driver bidding
- AI dispatch
- Multi-stop delivery
- Scheduled delivery
- Surge pricing
- Chat
- Complex promotions
- Payment gateway
- Advanced analytics
- WebSocket infrastructure

The first goal is:

```text
ORDER → STORE → RIDER → CUSTOMER
```

If this works reliably, TalaDelivery has a valid MVP.