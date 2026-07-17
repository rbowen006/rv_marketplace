# Trekr

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

**Suggested reply**:
An AI-drafted reply proposed to an Owner within a Chat, generated from the recent Messages and the Listing. It is a draft only — placed into the Owner's compose field to review and edit, never sent automatically and never persisted as a Message unless the Owner sends it.
_Avoid_: Auto-reply, smart reply, AI message, canned response

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

**Region**:
A sub-state geographic area (e.g. "Great Ocean Road") that has an authored knowledge corpus for trip planning. A Listing resolves to at most one Region, derived from its town/postcode by a canonical resolver and stored as a `region` slug on the Listing. The Region vocabulary (slug, name, state, match rules, corpus file) is a fixed config manifest, not a database table. A Region either has a corpus or it does not — the latter is what gates trip planning off.
_Avoid_: Area, location, zone, locale

**Knowledge chunk**:
One `##` section of a Region's markdown corpus, embedded (Ollama, pgvector) for retrieval. The retrievable unit of local knowledge — attractions, campground FAQs, area policies — that grounds a Trip plan. The corpus is LLM-generated and treated as synthetic, hence the Trip plan's verify-locally disclaimer.
_Avoid_: Document, doc, article, source, passage

**Trip plan**:
An AI-generated, day-by-day Itinerary for a confirmed Booking, produced only for the Hirer and grounded in the Booking Region's Knowledge chunks. Exactly one per Booking, regenerable in place (a durable record with status pending → processing → completed/failed). Offered only when the Booking is confirmed and its Region has a corpus.
_Avoid_: Trip, travel plan, guide, tour

**Itinerary**:
The structured day-by-day content of a Trip plan: a summary, a verify-locally disclaimer, and one entry per planned day (keyed to real Booking dates) broken into morning/afternoon/evening segments. Capped at a fixed number of planned days regardless of Booking length.
_Avoid_: Schedule, plan, agenda

**Interests**:
Optional free text the Hirer supplies to steer a Trip plan (e.g. "surfing and quiet beaches, travelling with a dog"). Blended with the Region and season into the retrieval query and the prompt; blank Interests still yield a grounded default plan.
_Avoid_: Preferences, query, prompt, tags

**Concierge**:
A conversational discovery assistant that guides a logged-in User toward a Booking through multi-turn chat. It runs an agent loop — Claude decides which read-only tools to call (semantic search, listing detail, availability, price), then surfaces Recommended listings the User can click through to the existing booking flow. A primary discovery surface alongside the browse grid and Natural language search, not a stuck-user helper. Available to any authenticated User (there is no owner/hirer account distinction).
_Avoid_: Assistant, bot, chatbot, agent, helper

**Concierge conversation**:
The durable per-User record of a Concierge session. Exactly one active conversation per User, resettable via "Start over". Holds the full agent transcript (User messages, assistant messages, and the tool-call/tool-result blocks the loop re-sends to Claude) as a jsonb column; the visible chat is derived from it. Carries a per-turn status that cycles idle → processing → idle on success, or → failed on a turn error.
_Avoid_: Session, thread, Chat, history

**Recommended listings**:
The Listings the Concierge chooses to surface within a turn, recorded when the agent calls its `recommend_listings` tool and rendered as inline Listing cards in the chat. Distinct from what the agent merely searched — a deliberate, structured recommendation. Read-only: surfacing a Recommended listing takes no booking or payment action; the User clicking through does.
_Avoid_: Results, matches, suggestions, picks

**AI spend log**:
The record of what the app's AI features cost. One entry per call to a model, capturing tokens, estimated cost, latency, and which feature made the call. An entry outlives whatever produced it: resetting a Concierge conversation does not erase the spend that conversation incurred, and an entry whose conversation is gone still counts — the money was spent either way. Estimated rather than billed — it is the app's own reckoning of cost, not an invoice.
_Avoid_: AI log, request log, usage log, ledger, audit log
