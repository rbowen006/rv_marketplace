# RV Marketplace

A two-sided marketplace where Owners list recreational vehicles for hire and Hirers discover and book them.

## Language

**RV (Recreational Vehicle)**:
Umbrella term for any towable or driveable leisure vehicle — caravan, motorhome, camper trailer, or similar. "RV" is the canonical term regardless of vehicle type.
_Avoid_: Vehicle, unit, asset

**Listing**:
A single RV made available for hire by an Owner.
_Avoid_: Ad, post, property

**RV Type**:
The category of a Listing's vehicle (e.g. caravan, motorhome, camper trailer). Hirers may filter search results by one or more RV types.
_Avoid_: Category, vehicle type, kind

**Owner**:
A User responsible for one or more Listings. May be the vehicle's actual owner or a fleet manager acting on their behalf.
_Avoid_: Host, seller, lister

**Hirer**:
A User who searches for and books RVs.
_Avoid_: Renter, guest, traveller, customer

**Booking**:
A hire period (start date to end date) requested by a Hirer for a specific Listing. Statuses: pending → confirmed or rejected; either party may cancel.
_Avoid_: Reservation, order, hire request

**Chat**:
A conversation thread between a Hirer and an Owner. One unbooked Chat may exist per hirer-owner pair at a time — it persists like a phone thread and is reused for future contact with the same Owner. Has a subject (the RV the Hirer is currently enquiring about, changeable pre-booking). When a Booking is made, the Chat is linked to that Booking and is no longer the active thread; new contact starts a fresh Chat. Initiated by the Hirer; the Owner may only respond after first contact.
_Avoid_: Thread, conversation, enquiry, messaging

**Chat subject**:
The RV a Chat is currently about, stored as `rv_listing_id` on Chat. Set when the Chat is created (from the Listing page the Hirer contacted the Owner from). Can be updated if the Hirer switches enquiry to a different RV. Superseded (but retained) once a Booking is made.
_Avoid_: Topic, listing reference

**Message**:
An individual message within a Chat. Records which User sent it and the content.
_Avoid_: Post, reply, comment

**Unread message**:
A Message that has not yet been seen by its recipient. Used to highlight Chats in the Inbox and to display read receipts within the Chat thread.
_Avoid_: New message, unseen message

**Inbox**:
The view where a User sees all their Chats, split by role — Chats where they are the Hirer, and Chats where they are the Owner. Both roles are always shown, even if one has no Chats.
_Avoid_: Messages page, chat list, message centre

**Max guests**:
The maximum number of people a Listing can accommodate. An attribute of a Listing, used by Hirers to filter search results.
_Avoid_: Capacity, occupancy, sleeps

**Pet friendly**:
A boolean attribute of a Listing indicating whether pets are permitted. Displayed as an icon on Listing cards.
_Avoid_: Pets allowed, animals welcome

**Distance from search location**:
The kilometres between a Listing's stored location (the Owner's location where the RV is kept) and the Hirer's desired destination. Used to sort and display search results. Indicates how far the Owner must drive/tow the RV to the destination, or how far the Hirer must travel to collect it. Calculated from geocoded coordinates; lat/lng stored on Listing.
_Avoid_: Distance to destination, proximity
