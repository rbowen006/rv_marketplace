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
