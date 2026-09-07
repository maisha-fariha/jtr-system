# JTR Mobile — API Feasibility Analysis

> Which features can be built with **existing backend APIs**, and which need **new endpoints**.  
> Sources: `lib/core/network/api_endpoints.dart`, `docs/JTR POS Backend API.postman_collection.json`, current Flutter wiring.

---

## Legend

| Status | Meaning |
|--------|---------|
| ✅ **Ready** | API exists **and** is already used in the Flutter app |
| 🔌 **Wire only** | API exists in backend (Postman) — Flutter integration + response mapping needed |
| ⚠️ **Partial** | Approximate UX possible, but incomplete, heavy, or active-day-only |
| 🆕 **New API** | No suitable endpoint in Postman — backend must add or extend |

---

## Summary

| Category | Count |
|----------|------:|
| ✅ Ready | 4 |
| 🔌 Wire only | 8 |
| ⚠️ Partial | 6 |
| 🆕 New API | 10 |

**Bottom line:** Roughly **40–50%** of JTR Mobile can be delivered by wiring existing dashboard/day APIs. Écart, movements, zone breakdown, period comparison, export, and AI need backend work (or accept degraded UX).

---

## APIs already in the Flutter app

| Endpoint | Used for |
|----------|----------|
| `GET /api/dashboard/active-day-statistics` | Day stats (partial fields) |
| `GET /api/days/:id/statistics` | Fallback day stats |
| `GET /api/days/active` | Active day id + date |
| `GET /api/orders` | Open + paid orders (session/statistics) |
| `GET /api/days/open-orders` | Open orders fallback |
| `GET /api/sales-zones/shortlist` | Sales zone list (session) |
| `GET /api/payments/summary/:orderId` | Per-order payment (checkout only) |
| `GET /api/payment-modes/active` | Payment mode labels |

`DayStatisticsInfo` currently maps only: `total_revenue`, `open_tables`, `printed_tickets`, `average_per_table`.  
The full JSON is kept in `raw` — **extra fields may already exist** but are not parsed yet.

---

## Dashboard APIs in Postman — NOT wired in Flutter yet

These are the biggest quick wins for JTR Mobile:

| Endpoint | Likely JTR Mobile use |
|----------|----------------------|
| `GET /api/dashboard/revenue-by-hour` | CA par heure bar chart |
| `GET /api/dashboard/payment-methods-summary` | Payment mix tiles |
| `GET /api/dashboard/revenue-by-category` | CA par catégorie |
| `GET /api/dashboard/product-family-summary` | Famille / article drill-down |
| `GET /api/dashboard/order-summary` | Tickets, couverts, averages |
| `GET /api/dashboard/day-status` | Live / day state header |
| `GET /api/dashboard/recent-orders` | Optional activity feed |
| `GET /api/dashboard/top-products` | Optional top articles |
| `GET /api/dashboard/occupied-tables` | Optional table occupancy |
| `GET /api/dashboard/table-status` | Optional table status |
| `GET /api/days/:id/recap` | Possible day recap / écart source (schema unknown) |
| `GET /api/days` | List past days (period picker helper) |
| `GET /api/enterprise` | Restaurant name / branding in header |

> Postman sample responses are empty — **confirm field names with one live API call** before UI work.

---

## Feature-by-feature breakdown

### 1. Shell & header

| Feature | Status | API / notes |
|---------|--------|-------------|
| Restaurant name + logo | 🔌 | `GET /api/enterprise` (`company_name`, logo if returned) |
| Date (“Aujourd’hui”) | ✅ | `GET /api/days/active` |
| Live indicator (“en direct”) | ⚠️ | `GET /api/dashboard/day-status` or poll stats; Reverb exists for POS, not dashboard |
| Dark / light theme | ✅ | Client-only — no API |
| Footer contact | ✅ | Static / from enterprise profile |

---

### 2. KPIs

| Feature | Status | API / notes |
|---------|--------|-------------|
| **Chiffre d'affaires** | ✅ / ⚠️ | `active-day-statistics` → `total_revenue` (wired). Verify day-wide vs zone scope |
| **Encaissé** (+ % CA) | 🔌 / ⚠️ | Likely in `active-day-statistics` or `order-summary` / `payment-methods-summary` — **not parsed today**. May compute from payment summary totals |
| **Trend** (+6% vs juillet) | 🆕 | Needs comparison endpoint or two calls: `GET /api/days/:id/statistics` for current + previous period + server-side % |

---

### 3. Payment mix (Espèces / TPE / Chèque)

| Feature | Status | API / notes |
|---------|--------|-------------|
| Amount + % per mode | 🔌 | `GET /api/dashboard/payment-methods-summary` |
| Mode labels | 🔌 | Join with `GET /api/payment-modes/active` if summary returns ids only |

---

### 4. Écart (gap donut)

| Feature | Status | API / notes |
|---------|--------|-------------|
| Donut: Annulations, Remises, Offerts, Pertes | 🆕 | No `gap` / `variance` dashboard endpoint in Postman |
| Total “DH non encaissé” | 🆕 | Same — or derive CA − Encaissé if both KPIs exist |
| Drill-down transactions | 🆕 | No list endpoint for cancelled / discounted / offered / loss lines |
| Export full list | 🆕 | No export endpoint |

**Possible shortcut:** Inspect `GET /api/days/:id/recap` — if backend already returns gap breakdown, map it. Otherwise **new API required**.

Order line items contain `cancel_reason`, `is_loss`, `is_offer`, etc. in order payloads — but aggregating from all orders client-side is **not production-viable**.

---

### 5. CA par catégorie

| Feature | Status | API / notes |
|---------|--------|-------------|
| Nourriture / Boisson / Divers bars | 🔌 | `GET /api/dashboard/revenue-by-category` |

---

### 6. CA par zone (Sur place, Emporter, Livraison, Glovo)

| Feature | Status | API / notes |
|---------|--------|-------------|
| Revenue by sales zone | 🆕 | No `revenue-by-sales-zone` in Postman |
| Workaround | ⚠️ | Loop `GET /api/orders?sales_zone_id=X` per zone + sum totals — slow, pagination-heavy, active day only |

**Recommended:** `GET /api/dashboard/revenue-by-sales-zone` (or add `sales_zone_id` filter to dashboard summary).

---

### 7. Ventes par famille / article

| Feature | Status | API / notes |
|---------|--------|-------------|
| Family accordion + totals | 🔌 | `GET /api/dashboard/product-family-summary` |
| Article lines (qty, amount) | 🔌 | Same endpoint or `GET /api/dashboard/top-products` — confirm nested articles in response |

---

### 8. Activity — Tickets & couverts

| Feature | Status | API / notes |
|---------|--------|-------------|
| Ticket count + avg ticket | 🔌 | `GET /api/dashboard/order-summary` |
| Couverts + avg per cover | 🔌 | Same, or fields in `active-day-statistics` raw JSON |
| Fallback (degraded) | ⚠️ | Count paid orders via `GET /api/orders?status=completed`; sum `number_of_guests` client-side |

---

### 9. Notes et mouvements

| Feature | Status | API / notes |
|---------|--------|-------------|
| Notes soldées | ⚠️ | Count completed paid orders (`GET /api/orders`) |
| Notes ouvertes (+ amount) | ⚠️ | `GET /api/days/open-orders` or open `GET /api/orders` |
| Transferts table | 🆕 | Transfer actions exist (`POST /api/orders/transfer-items`, `/api/tables/transfer-items`) but **no audit/count API** |
| Transferts article | 🆕 | Same |
| Annulations paiement | 🆕 | Payment cancel/sync exists at order level; **no day-level count/list API** |

---

### 10. CA par heure

| Feature | Status | API / notes |
|---------|--------|-------------|
| Hourly bar chart + peak | 🔌 | `GET /api/dashboard/revenue-by-hour` |

---

### 11. Period picker (Du / Au)

| Feature | Status | API / notes |
|---------|--------|-------------|
| Pick date range | ⚠️ | `GET /api/days` lists days — map range to day ids |
| Reload dashboard for range | 🆕 | Dashboard routes in Postman have **no `from`/`to` query params** — likely **active day only** today |
| Apply across all widgets | 🆕 | Need either historical dashboard params or `GET /api/days/:id/statistics` + new aggregated endpoints per day |

**Recommended:** Extend all `/api/dashboard/*` routes with `from`, `to`, or `day_id`.

---

### 12. AI assistant

| Feature | Status | API / notes |
|---------|--------|-------------|
| Chat UI (mock) | ✅ | Client-only |
| Real answers (sales, écart, compare periods) | 🆕 | LLM + secured analytics query API |

---

## Recommended backend additions (priority)

### P0 — blocks core mockup

| New / extended API | Purpose |
|--------------------|---------|
| `GET /api/dashboard/gap-summary` | Écart donut totals |
| `GET /api/dashboard/gap-details?type=annulations\|remises\|offerts\|pertes` | Écart drill-down + export source |
| `GET /api/dashboard/revenue-by-sales-zone` | CA par zone |
| Dashboard date filters (`from`, `to`, `day_id`) on all `/api/dashboard/*` | Period picker |

### P1 — polish & manager UX

| New / extended API | Purpose |
|--------------------|---------|
| `GET /api/dashboard/movements-summary` | Notes soldées/ouvertes, transfers, payment cancellations |
| `GET /api/dashboard/kpi-summary` | CA + Encaissé + trend in one call |
| `GET /api/dashboard/gap-details/export?format=csv` | Export |

### P2 — optional

| New / extended API | Purpose |
|--------------------|---------|
| `POST /api/assistant/query` | AI assistant |
| WebSocket / SSE dashboard refresh | True “en direct” without polling |

---

## Suggested Flutter integration order (no new backend)

Wire existing dashboard endpoints first — delivers ~**MVP dashboard** without backend sprint:

1. `payment-methods-summary`
2. `revenue-by-hour`
3. `revenue-by-category`
4. `order-summary`
5. `product-family-summary`
6. Extend `DayStatisticsInfo` parser using `raw` + `enterprise` profile
7. `days` list for basic day selection (single day at a time until dashboard supports ranges)

---

## Risk notes

1. **Empty Postman bodies** — field contracts are undocumented in repo; validate against staging before UI binding.
2. **Active day scope** — current app stats mix session open orders with day-wide API; JTR Mobile expects **restaurant-wide day** numbers.
3. **Permissions** — dashboard endpoints may require manager role; confirm auth on mobile login profiles.
4. **`/api/days/:id/recap`** — could reduce P0 backend work if it already exposes gap data; verify before building new gap APIs.

---

*See also: `docs/JTR-Mobile-Features.md`*
