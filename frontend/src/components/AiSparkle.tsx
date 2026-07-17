/**
 * Marks a control whose click makes an AI model call.
 *
 * The rule has two halves, and the second is the one that erodes:
 *
 *   - Every button that calls a model carries this. Today: NL search,
 *     Concierge send, Suggest reply, Generate itinerary, Generate description.
 *   - Nothing else does. `ChatPage`'s Send posts the user's own message and gets
 *     no sparkle, even though `ConciergePage`'s Send — one word, same styling —
 *     does. That contrast is the whole point: the mark describes what the click
 *     *does*, not which feature it lives in. Sparkling a non-AI control (or the
 *     panel around an AI one) spends the signal for nothing.
 *
 * Inherits colour via `currentColor`, so one component serves the filled rose
 * buttons and the outline/text ones without a variant. `aria-hidden` because the
 * button's own label already names the action for a screen reader; this is for
 * people who can see it.
 *
 * Where a button shows progress in the same leading slot, the spinner supersedes
 * this (see `TripPlanPanel`): the sparkle is a promise about what clicking will
 * do, and once clicked, that promise is redeemed.
 */
export function AiSparkle() {
  return (
    <svg className="w-4 h-4 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth={2}
        d="M5 3v4M3 5h4M6 17v4m-2-2h4m5-16l2.286 6.857L21 12l-5.714 2.143L13 21l-2.286-6.857L5 12l5.714-2.143L13 3z"
      />
    </svg>
  );
}
