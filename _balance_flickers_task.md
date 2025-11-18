You are an expert backend + frontend engineer with full read access to the codebase.

We have a **critical UX bug**: **wallet balance flickers up and down** (e.g. 10 → 15 → 10 → 15) for a while and then eventually stabilizes.

Your task: **investigate the root cause in the code and propose concrete fixes.**

---

## 1. User-facing symptoms

What users report / what we’ve observed:

* Balance for a token (e.g. USDT) changes repeatedly in short intervals:

  * Example sequence: 10 → 15 → 10 → 15, then eventually stabilizes.
* This happens **multiple times per session**, and for **multiple users**.
* Eventually the balance becomes correct, but the interim behavior looks broken and unsafe.

We also know:

* We fetch on-chain data from **multiple providers / nodes**.
* We have a **cache layer** in the WD-gap node around balance endpoints.
* The **frontend sometimes bypasses cache**, sometimes **uses cache**, depending on query params.

---

## 2. Suspected technical causes (to confirm or refute)

We currently suspect **two main contributors**:

### (A) Cache inconsistencies + multiple providers

* The backend (WD-gap / indexers) talks to **multiple RPC providers / nodes**.
* These nodes can be at **different block heights** at any given moment.
* Our cache layer has a TTL of ~30 seconds (we believe this is implemented in a `cacheRoute` or similarly named function in the WD-gap node).
* If some responses are **cached** (from provider A at block N–1) and others are **live** (from provider B at block N), the client will see balances oscillate as different requests hit different paths.

### (B) Frontend’s inconsistent use of cache query params

* The balance endpoints accept **query parameters** that control whether the cache is used or bypassed.

  * e.g. something like `?cache=true` / `?cache=false` / omitted.
* The app **does not use these consistently**:

  * Some screens or flows **force live data** (bypass cache).
  * Other screens or flows **use cached data**.
* This produces 3 possible behaviors:

  1. Always cached.
  2. Always live.
  3. Mixed (sometimes cached, sometimes live) → this is the **problem**.

We think the flicker comes from (A) + (B) combined.

---

## 3. What to do in the codebase

Please:

1. **Locate the backend balance-related endpoints and cache layer**

   * Find the WD-gap node (or similarly named service) that:

     * Exposes balance endpoints (e.g. `/balance`, `/wallet/balance`, or similar).
     * Implements the cache logic (likely a method or middleware like `cacheRoute`, or something equivalent).
   * Confirm:

     * The exact cache TTL (expected ~30 seconds).
     * The exact conditions under which cache is used (which query params, default behavior if omitted).
     * Whether there’s any provider-specific logic or randomization that might select different nodes per request.

2. **Trace the frontend usage of these balance endpoints**

   * Find all frontend calls that fetch balances (wallet screen, home, refresh, transaction details, etc.).
   * For each call, determine:

     * Which endpoint they hit.
     * Which query params they pass (especially anything related to cache, freshness, or “live”).
   * Identify places where:

     * The same wallet’s balance is sometimes requested with cache enabled and sometimes with cache disabled in short succession.
     * There are polling intervals or repeated fetches with differing params.

3. **Confirm or reject the hypothesis**

   * Use the code and any tests/logs (if available) to answer:

     * Do we indeed sometimes hit **cached** balance and sometimes **live** balance for the same wallet in a short period?
     * Are different providers / nodes involved with different block heights?
     * Can this, in practice, produce the flicker pattern (10 → 15 → 10 → 15)?

4. **Propose and/or implement fixes**

   * Backend:

     * Ensure cache behavior is **predictable and documented**:

       * Explicitly define: “If param X is set, we do Y; if omitted, we do Z.”
       * Optionally standardize default behavior (e.g. default to cached or default to live).
     * Consider logging:

       * Provider used.
       * Block height.
       * Cache hit vs miss.
       * This will make future debugging easier.
   * Frontend:

     * Choose **one consistent policy** per UX context:

       * Either **always use cache** when showing balances in the main UI and only bypass cache on explicit “pull to refresh”.
       * Or **always bypass cache** for some critical views, but do so consistently.
     * The main rule: **do not mix cached and live requests for the same balance in a rapid sequence**.

5. **Deliverables**

   * A short, concrete written summary including:

     * Where in the codebase the balance endpoint is implemented.
     * Where and how the caching logic is implemented (file paths and function names).
     * Where in the frontend the inconsistent query param usage happens (components/hooks/file paths).
     * Whether the original hypothesis was correct (and if not, what the *real* cause is).
   * A proposed fix plan:

     * Backend changes (if needed) – pseudo-code or diffs.
     * Frontend changes – specific API usage changes, hooks or components to update.
   * Optional but helpful:

     * Suggestions for tests to add:

       * Backend tests around cache behavior with different params.
       * Frontend/integration tests to ensure balances don’t flicker when multiple fetches are triggered.

---

## 4. Constraints / priorities

* Priority: **User trust and perceived correctness** of balances is more important than perfect real-time freshness.
* It is acceptable to:

  * Show a balance that lags by up to 30 seconds if it is **stable**.
  * Or to **always** show live data if RPC capacity allows.
* It is **not acceptable** for balances to visibly jump back and forth.

---

Please now:

1. Inspect the codebase following the steps above.
2. Explain what you found (with concrete references to files/functions).
3. Suggest precise code-level changes to eliminate the balance flicker.

Note: do NOT do any coding for now. 