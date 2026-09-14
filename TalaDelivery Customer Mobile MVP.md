# TalaDelivery Customer App — MVP

**Version:** 1.0  
**App:** TalaDelivery  
**Platform:** Flutter  
**Backend:** Laravel REST API  
**Database:** PostgreSQL  
**Authentication:** Laravel Sanctum  
**Target:** Android first  
**App Type:** Customer Delivery App

---

# 1. Purpose

The TalaDelivery Customer App allows customers to:

- Discover nearby stores
- Browse products
- Add products to cart
- Place delivery orders
- Select delivery addresses
- Pay through COD
- Track orders
- Receive delivery notifications
- View order history

The Customer App must NOT contain rider functionality.

---

# 2. Customer Flow

```text
Open App
    ↓
Login / Register
    ↓
Set Delivery Address
    ↓
Browse Stores
    ↓
Select Store
    ↓
Browse Products
    ↓
Add to Cart
    ↓
Checkout
    ↓
Place Order
    ↓
Store Confirms
    ↓
Store Prepares
    ↓
Finding Rider
    ↓
Rider Assigned
    ↓
Rider Picks Up
    ↓
Out for Delivery
    ↓
Delivered
```

---

# 3. Flutter Project

Recommended project:

```text
tala-delivery-customer/
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
│   ├── home/
│   ├── stores/
│   ├── products/
│   ├── cart/
│   ├── checkout/
│   ├── orders/
│   ├── addresses/
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
Register
Forgot Password
```

Login:

```text
TalaDelivery

Email / Phone
Password

[ Login ]

Forgot Password
```

Register:

```text
Full Name
Phone
Email
Password
Confirm Password

[ Create Account ]
```

After authentication:

```text
Login
  ↓
Customer Home
```

Only customers can authenticate through this application.

---

# 5. Customer Home

Route:

```text
/
```

Layout:

```text
--------------------------------
Good evening, Gregg

📍 Deliver to
Cabanatuan City

[ Search stores or products ]

Categories

[ Food ]
[ Grocery ]
[ Pharmacy ]
[ Convenience ]

Nearby Stores

┌─────────────────────┐
│ Store Image         │
│ ABC Mini Mart       │
│ ⭐ 4.8              │
│ ₱49 delivery        │
└─────────────────────┘

┌─────────────────────┐
│ Store Image         │
│ XYZ Food House      │
│ ⭐ 4.7              │
│ ₱49 delivery        │
└─────────────────────┘

--------------------------------
Home    Orders    Profile
--------------------------------
```

---

# 6. Location

Customer must have a delivery address.

The app should support:

```text
Current Location
Saved Address
Manual Address
```

MVP does not require advanced map drawing.

Address:

```text
Recipient Name
Phone
Address
Barangay
City
Province
Latitude
Longitude
Notes
```

---

# 7. Store Listing

Route:

```text
/stores
```

Display:

```text
Store
Store Image
Store Name
Category
Rating
Delivery Fee
Estimated Delivery
Open / Closed
```

Filters:

```text
All
Food
Grocery
Pharmacy
Other
```

---

# 8. Store Detail

Route:

```text
/stores/:id
```

Display:

```text
Store Image
Store Name
Description
Rating
Delivery Fee
Estimated Delivery

Categories

Products
```

Product:

```text
Image
Name
Description
Price
Availability

[ Add ]
```

---

# 9. Product Detail

Route:

```text
/products/:id
```

Display:

```text
Product Image

Product Name

Description

₱199

Quantity

[-] 1 [+]

[ Add to Cart ]
```

If unavailable:

```text
OUT OF STOCK
```

Disable the add button.

---

# 10. Cart

Route:

```text
/cart
```

Example:

```text
Your Cart

ABC Mini Mart

Product A
₱100 × 2
₱200

Product B
₱50 × 1
₱50

----------------

Subtotal
₱250

Delivery Fee
₱49

Total
₱299

[ Checkout ]
```

Cart rules:

- Cart belongs to one store.
- Customer cannot mix products from different stores.
- Product availability must be validated by API.
- Prices must be validated by API during checkout.

---

# 11. Checkout

Route:

```text
/checkout
```

Sections:

## Delivery Address

```text
Juan Dela Cruz
123 Example Street
Cabanatuan City
```

Button:

```text
Change Address
```

## Contact

```text
Recipient
Phone
```

## Notes

```text
Leave at the gate...
```

## Payment

MVP:

```text
● Cash on Delivery
```

## Summary

```text
Subtotal       ₱250
Delivery       ₱49
Total          ₱299
```

Button:

```text
[ Place Order ]
```

---

# 12. Order Creation

API:

```http
POST /api/v1/orders
```

Customer sends:

```json
{
    "store_id": 1,
    "address_id": 3,
    "payment_method": "COD",
    "items": [
        {
            "product_id": 10,
            "quantity": 2
        }
    ],
    "notes": "Please call when outside."
}
```

The API must calculate:

- Product prices
- Subtotal
- Delivery fee
- Total

Never trust totals calculated only by Flutter.

---

# 13. Order Success

After successful order:

```text
Order Placed!

Order #TD-100001

ABC Mini Mart

Total
₱299

Payment
Cash on Delivery

[ Track Order ]
```

---

# 14. Order Tracking

Route:

```text
/orders/:id
```

Primary screen:

```text
Order #TD-100001

ABC Mini Mart

✓ Order Placed
✓ Store Confirmed
✓ Preparing
✓ Ready

● Finding Rider
○ Rider Assigned
○ Picked Up
○ Out for Delivery
○ Delivered
```

When rider accepts:

```text
Rider Assigned

Juan Dela Cruz

Motorcycle

[ Call Rider ]
```

---

# 15. Finding Rider State

This is important.

Display:

```text
Finding your rider...

We're looking for a nearby rider
to deliver your order.

Please wait...
```

Possible API status:

```text
READY_FOR_PICKUP
```

Delivery:

```text
UNASSIGNED
```

The customer should NOT see internal rider matching details.

Do not show:

```text
Rider A rejected
Rider B expired
Rider C rejected
```

Instead show:

```text
Finding your rider...
```

---

# 16. Rider Assigned

Display:

```text
Your Rider

Juan Dela Cruz

🏍 Motorcycle

Rider is heading to the store.

[ Call Rider ]
```

---

# 17. Out for Delivery

Display:

```text
Your order is on the way!

Juan Dela Cruz

🏍 Motorcycle

Delivering to:

123 Example Street
Cabanatuan City

[ Call Rider ]
```

MVP can use polling.

```text
GET /api/v1/orders/{order}
```

Every:

```text
5–10 seconds
```

---

# 18. Delivery Completed

Display:

```text
Delivered!

Order #TD-100001

Total
₱299

Payment
Cash on Delivery

Thank you for ordering with
TalaDelivery.

[ View Order ]
```

---

# 19. Order History

Route:

```text
/orders
```

Tabs:

```text
Active
Completed
Cancelled
```

Order card:

```text
ABC Mini Mart

Order #TD-100001

₱299

DELIVERED

September 11, 2026

[ View ]
```

---

# 20. Cancel Order

Customer may cancel only when allowed.

Example:

```text
PENDING
```

may be cancelled.

After store preparation begins:

```text
PREPARING
```

cancellation may be disabled.

The API remains the final authority.

---

# 21. Addresses

Route:

```text
/addresses
```

Features:

```text
View addresses
Add address
Edit address
Delete address
Set default
```

Example:

```text
Home
123 Example Street
Cabanatuan City

[ Default ]
```

---

# 22. Profile

Route:

```text
/profile
```

Options:

```text
My Profile
My Addresses
My Orders
Notifications
Help
Logout
```

---

# 23. Notifications

Use Firebase Cloud Messaging.

Customer notifications:

```text
Order received
Order confirmed
Store preparing order
Order ready
Rider assigned
Rider picked up order
Order out for delivery
Order delivered
Order cancelled
```

Notification tap should open the relevant order.

---

# 24. Customer API Services

Create:

```text
AuthService
StoreService
ProductService
CartService
OrderService
AddressService
NotificationService
ProfileService
```

HTTP calls must not be placed directly inside UI widgets.

---

# 25. State Management

Recommended:

```text
Riverpod
```

Providers:

```text
authProvider
storesProvider
storeProvider
cartProvider
checkoutProvider
ordersProvider
orderTrackingProvider
addressesProvider
profileProvider
```

Use reactive state for:

- Cart quantity
- Authentication
- Order status
- Selected address
- Loading state

---

# 26. Local Storage

Store locally:

```text
Auth token
User session
Selected address
Cart
Basic preferences
```

Do not store:

```text
Password
Sensitive payment information
```

---

# 27. Error Handling

Every screen needs:

```text
Loading
Success
Empty
Error
Retry
```

Example:

```text
Unable to load stores.

[ Try Again ]
```

Network failure:

```text
No internet connection.
Please check your connection.
```

---

# 28. Customer Navigation

Bottom navigation:

```text
Home
Orders
Profile
```

Cart should be accessible from Home/Store screens.

---

# 29. Customer UI Design

TalaDelivery style:

```text
Primary: Sky Blue
Background: White
Text: Dark Gray
Cards: White
```

Characteristics:

```text
Simple
Friendly
Fast
Mobile-first
Minimal
```

Avoid excessive gradients.

---

# 30. Customer MVP Completion

Authentication:

- [ ] Splash
- [ ] Register
- [ ] Login
- [ ] Logout
- [ ] Session persistence

Stores:

- [ ] Store list
- [ ] Search
- [ ] Categories
- [ ] Store detail
- [ ] Product list
- [ ] Product detail

Ordering:

- [ ] Cart
- [ ] Address
- [ ] Checkout
- [ ] COD
- [ ] Create order
- [ ] Order success

Tracking:

- [ ] Order status
- [ ] Finding rider
- [ ] Rider assigned
- [ ] Picked up
- [ ] Out for delivery
- [ ] Delivered

Other:

- [ ] Order history
- [ ] Notifications
- [ ] Profile
- [ ] Network error handling

---

# 31. Customer MVP Goal

The complete customer experience must work:

```text
Login
 ↓
Choose Store
 ↓
Choose Products
 ↓
Cart
 ↓
Checkout
 ↓
Place Order
 ↓
Track Order
 ↓
Rider Assigned
 ↓
Delivery
 ↓
Delivered
```

Do not build rider functionality in this application.