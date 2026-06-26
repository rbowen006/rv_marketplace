import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { useApiFetch } from '../lib/useApiFetch';

const AU_STATES = ['NSW', 'VIC', 'QLD', 'SA', 'WA', 'TAS', 'ACT', 'NT'];
const RV_TYPES = [
  { value: 'caravan', label: 'Caravan' },
  { value: 'motorhome', label: 'Motorhome' },
  { value: 'camper_trailer', label: 'Camper Trailer' },
];

export function NewListingPage({ onSignInRequired }) {
  const { token, user } = useAuth();
  const apiFetch = useApiFetch();
  const navigate = useNavigate();

  const [form, setForm] = useState({
    title: '', description: '', rv_type: '', town: '', state: '',
    postcode: '', price_per_day: '', max_guests: '', pet_friendly: false,
  });
  const [images, setImages] = useState([]);
  const [previews, setPreviews] = useState([]);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState(null);

  if (!user) {
    return (
      <div className="max-w-lg mx-auto py-20 text-center">
        <p className="text-gray-600 mb-4">You need to sign in to list your RV.</p>
        <button
          onClick={onSignInRequired}
          className="bg-rose-500 hover:bg-rose-600 text-white font-semibold px-6 py-2 rounded-full text-sm"
        >
          Sign in
        </button>
      </div>
    );
  }

  function handleField(e) {
    const { name, value, type, checked } = e.target;
    setForm(prev => ({ ...prev, [name]: type === 'checkbox' ? checked : value }));
  }

  function handleImages(e) {
    const files = Array.from(e.target.files);
    setImages(prev => [...prev, ...files]);
    setPreviews(prev => [...prev, ...files.map(f => URL.createObjectURL(f))]);
  }

  function removeImage(index) {
    setImages(prev => prev.filter((_, i) => i !== index));
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
      const body = new FormData();
      Object.entries(form).forEach(([k, v]) => body.append(`listing[${k}]`, v));
      images.forEach(img => body.append('listing[images][]', img));

      const { res, data } = await apiFetch('/api/v1/listings', {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}` },
        body,
      });
      if (!res.ok) throw new Error(data.errors?.join(', ') ?? 'Failed to create listing');
      navigate(`/listings/${data.id}`);
    } catch (err) {
      setError(err.message);
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div className="max-w-2xl mx-auto py-10 px-6">
      <h1 className="text-2xl font-bold text-gray-900 mb-8">List your RV</h1>

      {error && <p className="mb-4 text-sm text-red-600">{error}</p>}

      <form onSubmit={handleSubmit} className="space-y-6">
        <div>
          <label htmlFor="title" className="block text-sm font-medium text-gray-700 mb-1">Title</label>
          <input id="title" name="title" value={form.title} onChange={handleField} required
            className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-rose-400" />
        </div>

        <div>
          <label htmlFor="description" className="block text-sm font-medium text-gray-700 mb-1">Description</label>
          <textarea id="description" name="description" value={form.description} onChange={handleField} required rows={4}
            className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-rose-400" />
        </div>

        <div>
          <label htmlFor="rv_type" className="block text-sm font-medium text-gray-700 mb-1">RV Type</label>
          <select id="rv_type" name="rv_type" value={form.rv_type} onChange={handleField} required
            className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-rose-400">
            <option value="">Select type…</option>
            {RV_TYPES.map(t => <option key={t.value} value={t.value}>{t.label}</option>)}
          </select>
        </div>

        <div className="grid grid-cols-3 gap-4">
          <div className="col-span-1">
            <label htmlFor="town" className="block text-sm font-medium text-gray-700 mb-1">Town</label>
            <input id="town" name="town" value={form.town} onChange={handleField} required
              className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-rose-400" />
          </div>
          <div>
            <label htmlFor="state" className="block text-sm font-medium text-gray-700 mb-1">State</label>
            <select id="state" name="state" value={form.state} onChange={handleField} required
              className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-rose-400">
              <option value="">Select…</option>
              {AU_STATES.map(s => <option key={s} value={s}>{s}</option>)}
            </select>
          </div>
          <div>
            <label htmlFor="postcode" className="block text-sm font-medium text-gray-700 mb-1">Postcode</label>
            <input id="postcode" name="postcode" value={form.postcode} onChange={handleField} required
              className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-rose-400" />
          </div>
        </div>

        <div className="grid grid-cols-2 gap-4">
          <div>
            <label htmlFor="price_per_day" className="block text-sm font-medium text-gray-700 mb-1">Price per day ($)</label>
            <input id="price_per_day" name="price_per_day" type="number" min="1" value={form.price_per_day} onChange={handleField} required
              className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-rose-400" />
          </div>
          <div>
            <label htmlFor="max_guests" className="block text-sm font-medium text-gray-700 mb-1">Max guests</label>
            <input id="max_guests" name="max_guests" type="number" min="1" value={form.max_guests} onChange={handleField} required
              className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-rose-400" />
          </div>
        </div>

        <div className="flex items-center gap-2">
          <input id="pet_friendly" name="pet_friendly" type="checkbox" checked={form.pet_friendly} onChange={handleField}
            className="rounded border-gray-300 text-rose-500 focus:ring-rose-400" />
          <label htmlFor="pet_friendly" className="text-sm font-medium text-gray-700">Pet friendly</label>
        </div>

        <div>
          <label htmlFor="photos" className="block text-sm font-medium text-gray-700 mb-1">
            Photos <span className="text-gray-400 font-normal">(first photo will be the cover image)</span>
          </label>
          <input id="photos" type="file" multiple accept="image/*" onChange={handleImages}
            className="block w-full text-sm text-gray-500 file:mr-3 file:py-1.5 file:px-4 file:rounded-full file:border-0 file:text-sm file:font-medium file:bg-rose-50 file:text-rose-600 hover:file:bg-rose-100" />
          {previews.length > 0 && (
            <div className="mt-3 flex flex-wrap gap-3">
              {previews.map((src, i) => (
                <div key={i} className="relative">
                  {i === 0 && (
                    <span className="absolute top-1 left-1 bg-rose-500 text-white text-[10px] font-bold px-1.5 py-0.5 rounded z-10">Cover</span>
                  )}
                  <img src={src} alt="" className="h-24 w-24 object-cover rounded-lg border border-gray-200" />
                  <button type="button" onClick={() => removeImage(i)}
                    className="absolute -top-1.5 -right-1.5 bg-gray-800 text-white rounded-full w-5 h-5 flex items-center justify-center text-xs leading-none">
                    ×
                  </button>
                </div>
              ))}
            </div>
          )}
        </div>

        <button type="submit" disabled={submitting}
          className="w-full bg-rose-500 hover:bg-rose-600 disabled:bg-rose-300 text-white font-semibold py-3 rounded-full text-sm transition-colors">
          {submitting ? 'Publishing…' : 'Publish listing'}
        </button>
      </form>
    </div>
  );
}
