import { FormEvent, useEffect, useRef, useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { useApiFetch } from '../lib/useApiFetch';
import { SignInModal } from '../components/SignInModal';
import { AiSparkle } from '../components/AiSparkle';
import { ConfirmDialog } from '../components/ConfirmDialog';
import { ListingCard } from '../components/ListingCard';
import type { ConciergeData, ConciergeEnvelope } from '../types/concierge';

const URL = '/api/v1/concierge';
const POLL_MS = 2500;

const EXAMPLES = [
  'A pet-friendly van for two near Byron Bay',
  'Something that sleeps a family of five in Victoria',
  'A campervan for a two-week road trip up the coast',
];

export function ConciergePage() {
  const { token } = useAuth();
  const apiFetch = useApiFetch();
  const [data, setData] = useState<ConciergeData>({ status: 'none' });
  const [input, setInput] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [showSignIn, setShowSignIn] = useState(false);
  const [confirmingStartOver, setConfirmingStartOver] = useState(false);
  const bottomRef = useRef<HTMLDivElement>(null);

  const authHeaders = { Authorization: `Bearer ${token}` };

  // Load any existing conversation on mount.
  useEffect(() => {
    if (!token) return;
    apiFetch<ConciergeEnvelope>(URL, { headers: authHeaders }).then(({ res, data: body }) => {
      if (res.ok) setData(body.data);
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token]);

  // Poll while a turn is processing; stop once it settles.
  useEffect(() => {
    if (data.status !== 'processing') return;
    const timer = setInterval(() => {
      apiFetch<ConciergeEnvelope>(URL, { headers: authHeaders }).then(({ res, data: body }) => {
        if (res.ok) setData(body.data);
      });
    }, POLL_MS);
    return () => clearInterval(timer);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [data.status, token]);

  // Keep the latest message in view.
  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [data.messages, data.status]);

  async function send(text: string) {
    const message = text.trim();
    if (!message) return;
    setError(null);
    setInput('');

    // Optimistically show the user's message and enter processing.
    const previous = data;
    setData({
      ...data,
      status: 'processing',
      step_status: 'Thinking…',
      messages: [...(data.messages ?? []), { role: 'user', text: message }],
    });

    const { res, data: body } = await apiFetch<ConciergeEnvelope>(`${URL}/messages`, {
      method: 'POST',
      headers: { ...authHeaders, 'Content-Type': 'application/json' },
      body: JSON.stringify({ message }),
    });
    if (res.ok) setData(body.data);
    else {
      setData(previous);
      setError(body.message ?? "Sorry, something went wrong. Please try again.");
    }
  }

  async function startOver() {
    setConfirmingStartOver(false);
    await apiFetch(URL, { method: 'DELETE', headers: authHeaders });
    setData({ status: 'none' });
    setError(null);
    setInput('');
  }

  function onSubmit(event: FormEvent) {
    event.preventDefault();
    send(input);
  }

  if (!token) {
    return (
      <div className="max-w-2xl mx-auto px-4 py-16 text-center">
        <h1 className="text-2xl font-semibold text-gray-900">Trekr Concierge</h1>
        <p className="mt-2 text-gray-500">Sign in to chat with your personal RV concierge.</p>
        <button
          onClick={() => setShowSignIn(true)}
          className="mt-6 px-5 py-2 rounded-full bg-rose-500 text-white font-medium hover:bg-rose-600 transition-colors"
        >
          Sign in
        </button>
        {showSignIn && <SignInModal onClose={() => setShowSignIn(false)} />}
      </div>
    );
  }

  const messages = data.messages ?? [];
  const processing = data.status === 'processing';
  const failed = data.status === 'failed';
  const recommendations = data.recommendations ?? [];
  const hasConversation = messages.length > 0;
  const lastUserText = [...messages].reverse().find((m) => m.role === 'user')?.text;

  return (
    <div className="max-w-2xl mx-auto px-4 py-6 flex flex-col min-h-[calc(100vh-4rem)]">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold text-gray-900">Concierge</h1>
        {hasConversation && (
          <button
            onClick={() => setConfirmingStartOver(true)}
            className="text-sm text-gray-500 hover:text-gray-800 underline underline-offset-2"
          >
            Start over
          </button>
        )}
      </div>

      {confirmingStartOver && (
        <ConfirmDialog
          title="Start over?"
          message="This permanently deletes this conversation, including every message in it. This can't be undone."
          confirmLabel="Start over"
          destructive
          onConfirm={startOver}
          onCancel={() => setConfirmingStartOver(false)}
        />
      )}

      <div className="flex-1 mt-4 space-y-3">
        {!hasConversation && !processing ? (
          <div className="mt-10 text-center">
            <p className="text-gray-600">Tell me about the trip you're planning and I'll find the right RV.</p>
            <div className="mt-4 flex flex-col gap-2 items-center">
              {EXAMPLES.map((example) => (
                <button
                  key={example}
                  onClick={() => send(example)}
                  className="text-sm text-left px-4 py-2 rounded-full border border-gray-200 text-gray-700 hover:border-rose-300 hover:bg-rose-50 transition-colors"
                >
                  {example}
                </button>
              ))}
            </div>
          </div>
        ) : (
          <>
            {messages.map((message, i) => (
              <Bubble key={i} role={message.role} text={message.text} />
            ))}

            {recommendations.length > 0 && (
              <div className="grid grid-cols-2 gap-3 pt-2" data-testid="recommendations">
                {recommendations.map((listing) => (
                  <ListingCard key={listing.id} listing={listing} />
                ))}
              </div>
            )}

            {processing && (
              <p className="flex items-center gap-2 text-sm text-gray-500" role="status">
                <Spinner />
                {data.step_status || 'Thinking…'}
              </p>
            )}

            {failed && (
              <div className="text-sm text-red-600" role="alert">
                Sorry, something went wrong{data.error ? `: ${data.error}` : '.'}
                {lastUserText && (
                  <button
                    onClick={() => send(lastUserText)}
                    className="ml-2 underline underline-offset-2 hover:text-red-700"
                  >
                    Try again
                  </button>
                )}
              </div>
            )}
          </>
        )}
        <div ref={bottomRef} />
      </div>

      {error && <p className="mt-2 text-sm text-red-600">{error}</p>}

      <form onSubmit={onSubmit} className="mt-4 flex gap-2 sticky bottom-4">
        <input
          value={input}
          onChange={(e) => setInput(e.target.value)}
          disabled={processing}
          placeholder="Describe your trip…"
          aria-label="Message"
          className="flex-1 rounded-full border border-gray-300 px-4 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-rose-500 disabled:bg-gray-50"
        />
        <button
          type="submit"
          disabled={processing || input.trim() === ''}
          className="inline-flex items-center gap-2 px-5 py-2 rounded-full bg-rose-500 text-white text-sm font-medium hover:bg-rose-600 transition-colors disabled:opacity-60 disabled:cursor-not-allowed"
        >
          <AiSparkle />
          Send
        </button>
      </form>
    </div>
  );
}

function Bubble({ role, text }: { role: 'user' | 'assistant'; text: string }) {
  const mine = role === 'user';
  return (
    <div className={`flex ${mine ? 'justify-end' : 'justify-start'}`}>
      <div
        className={`max-w-[80%] rounded-2xl px-4 py-2 text-sm whitespace-pre-wrap ${
          mine ? 'bg-rose-500 text-white' : 'bg-gray-100 text-gray-800'
        }`}
      >
        {text}
      </div>
    </div>
  );
}

function Spinner() {
  return (
    <span
      className="inline-block h-4 w-4 animate-spin rounded-full border-2 border-current border-t-transparent"
      aria-hidden="true"
    />
  );
}
