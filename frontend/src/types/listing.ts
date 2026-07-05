/** Card/grid summary shape — full API types come in a later migration step. */
export interface ListingOwner {
  id?: number;
  name?: string;
  avatar_url?: string;
}

export interface ListingImage {
  url?: string;
}

export interface ListingAttachment extends ListingImage {
  id: number;
  url: string;
}

export interface ListingSummary {
  id: number;
  title: string;
  town?: string;
  state?: string;
  postcode?: string;
  price_per_day: number;
  max_guests: number;
  pet_friendly?: boolean;
  images?: ListingImage[];
  owner?: ListingOwner;
  /** Present on NL-search results only (dev score badge). */
  score?: number;
}

/** Full listing detail from GET /api/v1/listings/:id */
export interface ListingDetail extends ListingSummary {
  description?: string;
  images?: ListingAttachment[];
  rv_type?: string;
}
