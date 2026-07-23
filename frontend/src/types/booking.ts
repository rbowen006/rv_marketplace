export type BookingStatus = 'pending' | 'confirmed' | 'rejected' | 'cancelled';

export interface BookingUser {
  id?: number;
  name?: string;
}

export interface Booking {
  id: number;
  hirer_id: number;
  listing_title: string;
  start_date: string;
  end_date: string;
  status: BookingStatus;
  hirer?: BookingUser;
  owner?: BookingUser;
}

export interface BookingConfirmation {
  start_date: string;
  end_date: string;
}

// The GET /bookings/:id show payload — a booking plus whether trip planning
// can be offered for it (confirmed && the region has an embedded corpus).
export interface BookingDetail extends Booking {
  trip_planning_available: boolean;
}

// Structured itinerary returned by the trip planner (ADR-0013).
export interface ItinerarySegment {
  part_of_day: string;
  activity: string;
  detail?: string | null; // may be null, not just absent (#76); render guards on truthiness
}

export interface ItineraryDay {
  date: string;
  title: string;
  segments: ItinerarySegment[];
}

export interface Itinerary {
  summary: string;
  disclaimer: string;
  days: ItineraryDay[];
}

export type TripPlanStatus =
  | 'none'
  | 'pending'
  | 'processing'
  | 'completed'
  | 'failed';

export interface TripPlan {
  status: TripPlanStatus;
  interests?: string | null;
  itinerary?: Itinerary | null;
  error?: string | null;
}
