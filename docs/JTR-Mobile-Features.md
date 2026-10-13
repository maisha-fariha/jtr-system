# JTR Mobile — Feature Breakdown

> Management & analytics dashboard for restaurant owners/managers.  
> Source: `docs/JTR Mobile.html`  
> **Not** the waiter POS app.

---

## Overview

| Item | Detail |
|------|--------|
| **Purpose** | Live sales dashboard, payment mix, gap analysis, category/zone breakdowns |
| **Screens** | 3 views: Dashboard, Ventes par famille, Détail de l'écart |
| **Current app** | Basic `statistics_page.dart` (~15–20% overlap) |
| **Backend** | Most features need new/extended APIs |

---

## 1. Shell & Global UI

| Feature | What it does |
|---------|--------------|
| Header | Restaurant logo, name, date, live dot (“en direct”) |
| Theme toggle | Dark / light mode |
| AI icon | Opens assistant chat panel |
| Footer | JTR branding, phone, email |
| Navigation | Dashboard ↔ 2 drill-down screens with back button |

---

## 2. Dashboard — KPIs

| Feature | Data shown |
|---------|------------|
| **Chiffre d'affaires** | Total revenue + trend vs previous period (e.g. +6% vs juillet) |
| **Encaissé** | Collected amount + % of CA |

---

## 3. Dashboard — Payment Mix

| Feature | Data shown |
|---------|------------|
| Payment tiles | Espèces, TPE, Chèque — amount + % each |

---

## 4. Dashboard — Écart (Gap)

| Feature | Data shown |
|---------|------------|
| Donut chart | Annulations, Remises, Offerts, Pertes |
| Center label | Total “DH non encaissé” |
| Drill-down CTA | → **Détail de l'écart** screen |

**Écart categories:**

- Annulations (red)
- Remises (orange)
- Offerts (purple)
- Pertes (blue)

---

## 5. Dashboard — Revenue Breakdowns

| Feature | Data shown |
|---------|------------|
| **CA par catégorie** | Nourriture, Boisson, Divers — bar + amount + % |
| **CA par zone** | Sur place, Emporter, Livraison, Glovo — bar + amount + % |
| **Famille drill-down** | → **Ventes par famille** screen |

---

## 6. Dashboard — Activity

| Feature | Data shown |
|---------|------------|
| **Tickets** | Count + average ticket (DH) |
| **Couverts** | Count + average per cover (DH) |

---

## 7. Dashboard — Notes & Movements

| Row | Data |
|-----|------|
| Notes soldées | Count |
| Notes ouvertes | Count + open amount (DH) |
| Transferts table | Count |
| Transferts article | Count |
| Annulations paiement | Count (highlighted) |

---

## 8. Dashboard — Hourly Chart

| Feature | Data shown |
|---------|------------|
| Bar chart | CA per hour (today) |
| Labels | Time axis (10h–22h) |
| Peak caption | e.g. “Pic à 20h · 12 400 DH” |

---

## 9. Period Picker

| Feature | Detail |
|---------|--------|
| Date range | **Du** / **Au** inputs |
| Apply | Reloads all dashboard data for selected period |
| Default | Today / current month in mockup |

---

## 10. Drill-down — Ventes par famille

| Feature | Detail |
|---------|--------|
| Header | Back + period subtitle (e.g. “Août 2026”) |
| Family accordion | Name, total qty (pcs), total DH |
| Articles | Per family: name, qty (×N), revenue |

**Example families:** Tajines, Grillades, Boissons froides/chaudes, Desserts

---

## 11. Drill-down — Détail de l'écart

| Category | Transaction fields |
|----------|-------------------|
| **Annulations** | Date, time, table, article, qty, reason tag, amount |
| **Remises** | Date, time, table, label, discount %, amount |
| **Offerts** | Date, time, table, article, qty, amount |
| **Pertes** | Date, time, location, reason tag, amount |
| **Export note** | Preview of latest ops; full list exportable |

---

## 12. AI Assistant

| Feature | Detail |
|---------|--------|
| Chat panel | Greeting bubble + text input + send |
| Mock capabilities | Summarize sales, explain écart, compare periods |
| Production | Needs LLM backend + data access API |

---

## Current App vs JTR Mobile

| JTR Mobile feature | In app today? |
|--------------------|---------------|
| CA / revenue KPI | Partial (session orders, not full day dashboard) |
| Encaissé | No |
| Payment mix | No |
| Écart donut + drill-down | No |
| CA par catégorie / zone | No |
| Famille / article drill-down | No |
| Tickets / couverts | Partial (open tables, printed tickets) |
| Notes & mouvements | No |
| CA par heure | No |
| Period picker | No |
| Dark mode | No (app has its own theme) |
| AI assistant | No |

---

## Suggested Phases

### MVP

- Dashboard shell + header
- CA + Encaissé + trend
- Payment mix tiles
- CA par heure
- Period picker (Du/Au)
- Pull-to-refresh / loading states

### Phase 2

- CA par catégorie
- CA par zone
- Tickets + couverts
- Notes et mouvements

### Phase 3

- Écart donut chart
- Détail de l'écart (all 4 categories)
- Ventes par famille / article
- Export (CSV / share)

### Phase 4

- Dark / light theme
- AI assistant (UI → real LLM)
- Live “en direct” refresh

---

## Backend APIs Needed (summary)

| Endpoint area | Used by |
|---------------|---------|
| Dashboard summary | CA, Encaissé, trend |
| Payment breakdown | Payment tiles |
| Gap / écart | Donut + drill-down |
| Sales by category | Category bars |
| Sales by zone | Zone bars |
| Sales by family/article | Detail view |
| Activity stats | Tickets, couverts |
| Movements | Notes, transfers, cancellations |
| Hourly revenue | Bar chart |
| Period filter | All endpoints (`from` / `to`) |
| Export | Écart transaction lists |
| AI (optional) | Chat assistant |

---

## Effort (agent-assisted, incl. testing)

| Scope | Hours | Calendar |
|-------|------:|----------|
| MVP | ~45–55 h | ~1.5–2 weeks |
| Full (no AI) | ~150–180 h | ~4–5 weeks |
| Full + real AI | ~170–205 h | ~5–6 weeks |
| Backend APIs | ~70–120 h | parallel track |

---

*JTR Innovation — contact: +212 8 08 58 51 28 / +212 6 66 44 43 30*
