import type { ListingAttachment } from './listing';

export interface ListingFormFields {
  title: string;
  description: string;
  rv_type: string;
  town: string;
  state: string;
  postcode: string;
  price_per_day: string | number;
  max_guests: string | number;
  pet_friendly: boolean;
}

export interface ListingFormInitialValues extends Partial<ListingFormFields> {
  images?: ListingAttachment[];
}

export interface ListingFormProps {
  initialValues?: ListingFormInitialValues;
  onSubmit: (fields: ListingFormFields, newImages: File[]) => Promise<void>;
  submitLabel: string;
  listingId?: number;
}
