import { useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { useApiFetch } from '../lib/useApiFetch';

const AU_STATES = ['NSW', 'VIC', 'QLD', 'SA', 'WA', 'TAS', 'ACT', 'NT'];
const RV_TYPES = [
  { value: 'caravan', label: 'Caravan' },
  { value: 'motorhome', label: 'Motorhome' },
  { value: 'camper_trailer', label: 'Camper Trailer' },
];
// Kept in sync by hand with Ai::DescriptionGenerator::REQUIRED_FIELDS
// (app/services/ai/description_generator.rb) — no shared schema between
// frontend and backend, so a mismatch here won't fail loudly.
const GENERATE_REQUIRED_FIELDS = ['rv_type', 'town', 'state', 'max_guests'];

export function ListingForm({ initialValues = {}, onSubmit, submitLabel, listingId }) {
  const { token } = useAuth();
  const apiFetch = useApiFetch();

  const [fields, setFields] = useState({
    title: initialValues.title ?? '',
    description: initialValues.description ?? '',
    rv_type: initialValues.rv_type ?? '',
    town: initialValues.town ?? '',
    state: initialValues.state ?? '',
    postcode: initialValues.postcode ?? '',
    price_per_day: initialValues.price_per_day ?? '',
    max_guests: initialValues.max_guests ?? '',
    pet_friendly: initialValues.pet_friendly ?? false,
  });
  const [existingImages, setExistingImages] = useState(initialValues.images ?? []);
  const [newImages, setNewImages] = useState([]);
  const [previews, setPreviews] = useState([]);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState(null);
  const [generating, setGenerating] = useState(false);
  const [generateError, setGenerateError] = useState(null);

  const canGenerate = GENERATE_REQUIRED_FIELDS.every(f => String(fields[f]).trim() !== '');

  async function handleGenerateDescription() {
    if (fields.description.trim() !== '' && !window.confirm('This will replace the current description. Continue?')) {
      return;
    }

    setGenerating(true);
    setGenerateError(null);
    try {
      const { res, data } = await apiFetch('/api/v1/listings/generate_description', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
        body: JSON.stringify({
          rv_type: fields.rv_type,
          town: fields.town,
          state: fields.state,
          max_guests: fields.max_guests,
          pet_friendly: fields.pet_friendly,
          price_per_day: fields.price_per_day,
        }),
      });

      if (!res.ok) {
        setGenerateError(data.message ?? 'Failed to generate description');
        return;
      }

      setFields(prev => ({ ...prev, description: data.data.description }));
    } catch {
      setGenerateError('Failed to generate description');
    } finally {
      setGenerating(false);
    }
  }

  function handleField(e) {
    const { name, value, type, checked } = e.target;
    setFields(prev => ({ ...prev, [name]: type === 'checkbox' ? checked : value }));
  }

  async function handleImageFiles(e) {
    const files = Array.from(e.target.files);
    if (!files.length) return;

    if (listingId) {
      const body = new FormData();
      files.forEach(f => body.append('images[]', f));
      await apiFetch(`/api/v1/listings/${listingId}/images`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}` },
        body,
      });
      // Re-fetch handled by parent; for now show local previews
    } else {
      setNewImages(prev => [...prev, ...files]);
      setPreviews(prev => [...prev, ...files.map(f => URL.createObjectURL(f))]);
    }
    e.target.value = '';
  }

  async function handleDeleteImage(attachmentId) {
    await apiFetch(`/api/v1/listings/${listingId}/images/${attachmentId}`, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${token}` },
    });
    setExistingImages(prev => prev.filter(img => img.id !== attachmentId));
  }

  function removeNewImage(index) {
    setNewImages(prev => prev.filter((_, i) => i !== index));
    setPreviews(prev => {
      URL.revokeObjectURL(prev[index]);
      return prev.filter((_, i) => i !== index);
    });
  }

  async function handleSubmit(e) {
    e.preventDefault();
    setSubmitting(true);
    setError(null);
    try {
      await onSubmit(fields, newImages);
    } catch (err) {
      setError(err.message);
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <form onSubmit={handleSubmit} noValidate className="space-y-6">
      {error && <p className="text-sm text-red-600">{error}</p>}

      <div>
        <label htmlFor="title" className="block text-sm font-medium text-gray-700 mb-1">Title</label>
        <input id="title" name="title" value={fields.title} onChange={handleField} required
          className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-rose-400" />
      </div>

      <div>
        <label htmlFor="description" className="block text-sm font-medium text-gray-700 mb-1">Description</label>
        <textarea id="description" name="description" value={fields.description} onChange={handleField} required rows={4}
          disabled={generating}
          className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-rose-400" />
        <button type="button" disabled={!canGenerate || generating || submitting} onClick={handleGenerateDescription}
          className="mt-2 text-sm px-3 py-1.5 rounded-lg border border-gray-300 text-gray-700 font-medium hover:bg-gray-50 disabled:opacity-50 transition-colors">
          {generating ? 'Generating…' : 'Generate description'}
        </button>
        {generateError && <p className="mt-1 text-sm text-red-600">{generateError}</p>}
      </div>

      <div>
        <label htmlFor="rv_type" className="block text-sm font-medium text-gray-700 mb-1">RV Type</label>
        <select id="rv_type" name="rv_type" value={fields.rv_type} onChange={handleField} required
          className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-rose-400">
          <option value="">Select type…</option>
          {RV_TYPES.map(t => <option key={t.value} value={t.value}>{t.label}</option>)}
        </select>
      </div>

      <div className="grid grid-cols-3 gap-4">
        <div className="col-span-1">
          <label htmlFor="town" className="block text-sm font-medium text-gray-700 mb-1">Town</label>
          <input id="town" name="town" value={fields.town} onChange={handleField} required
            className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-rose-400" />
        </div>
        <div>
          <label htmlFor="state" className="block text-sm font-medium text-gray-700 mb-1">State</label>
          <select id="state" name="state" value={fields.state} onChange={handleField} required
            className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-rose-400">
            <option value="">Select…</option>
            {AU_STATES.map(s => <option key={s} value={s}>{s}</option>)}
          </select>
        </div>
        <div>
          <label htmlFor="postcode" className="block text-sm font-medium text-gray-700 mb-1">Postcode</label>
          <input id="postcode" name="postcode" value={fields.postcode} onChange={handleField} required
            className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-rose-400" />
        </div>
      </div>

      <div className="grid grid-cols-2 gap-4">
        <div>
          <label htmlFor="price_per_day" className="block text-sm font-medium text-gray-700 mb-1">Price per day ($)</label>
          <input id="price_per_day" name="price_per_day" type="number" min="1" value={fields.price_per_day} onChange={handleField} required
            className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-rose-400" />
        </div>
        <div>
          <label htmlFor="max_guests" className="block text-sm font-medium text-gray-700 mb-1">Max guests</label>
          <input id="max_guests" name="max_guests" type="number" min="1" value={fields.max_guests} onChange={handleField} required
            className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-rose-400" />
        </div>
      </div>

      <div className="flex items-center gap-2">
        <input id="pet_friendly" name="pet_friendly" type="checkbox" checked={fields.pet_friendly} onChange={handleField}
          className="rounded border-gray-300 text-rose-500 focus:ring-rose-400" />
        <label htmlFor="pet_friendly" className="text-sm font-medium text-gray-700">Pet friendly</label>
      </div>

      <div>
        <label htmlFor="photos" className="block text-sm font-medium text-gray-700 mb-1">
          Photos <span className="text-gray-400 font-normal">(first photo will be the cover image)</span>
        </label>

        {existingImages.length > 0 && (
          <div className="mb-3 flex flex-wrap gap-3">
            {existingImages.map((img, i) => (
              <div key={img.id} className="relative">
                {i === 0 && (
                  <span className="absolute top-1 left-1 bg-rose-500 text-white text-[10px] font-bold px-1.5 py-0.5 rounded z-10">Cover</span>
                )}
                <img src={img.url} alt={`Photo ${i + 1}`} className="h-24 w-24 object-cover rounded-lg border border-gray-200" />
                {listingId && (
                  <button type="button" onClick={() => handleDeleteImage(img.id)}
                    aria-label="Delete image"
                    className="absolute -top-1.5 -right-1.5 bg-gray-800 text-white rounded-full w-5 h-5 flex items-center justify-center text-xs leading-none">
                    ×
                  </button>
                )}
              </div>
            ))}
          </div>
        )}

        <input id="photos" type="file" multiple accept="image/*" onChange={handleImageFiles}
          className="block w-full text-sm text-gray-500 file:mr-3 file:py-1.5 file:px-4 file:rounded-full file:border-0 file:text-sm file:font-medium file:bg-rose-50 file:text-rose-600 hover:file:bg-rose-100" />

        {previews.length > 0 && (
          <div className="mt-3 flex flex-wrap gap-3">
            {previews.map((src, i) => (
              <div key={i} className="relative">
                {existingImages.length === 0 && i === 0 && (
                  <span className="absolute top-1 left-1 bg-rose-500 text-white text-[10px] font-bold px-1.5 py-0.5 rounded z-10">Cover</span>
                )}
                <img src={src} alt="" className="h-24 w-24 object-cover rounded-lg border border-gray-200" />
                <button type="button" onClick={() => removeNewImage(i)}
                  className="absolute -top-1.5 -right-1.5 bg-gray-800 text-white rounded-full w-5 h-5 flex items-center justify-center text-xs leading-none">
                  ×
                </button>
              </div>
            ))}
          </div>
        )}
      </div>

      <button type="submit" disabled={submitting || generating}
        className="w-full bg-rose-500 hover:bg-rose-600 disabled:bg-rose-300 text-white font-semibold py-3 rounded-full text-sm transition-colors">
        {submitting ? 'Saving…' : submitLabel}
      </button>
    </form>
  );
}
