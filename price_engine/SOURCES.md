# SOURCES.md — Permanent Source Log for Price Dataset

*This file is the single artifact that answers "is this data real?" in a viva. Every constant used anywhere in `generate_price_dataset.py` must have a row here. Update this file every time a constant is added, changed, or recalibrated — never change a number in the script without updating its row here on the same day.*

---

## Layer 1 — Official Exchange Rates

| Material | Value (as of) | Source | URL | Access/Recalibration Date | Notes |
|---|---|---|---|---|---|
| Copper | *(fetched daily)* | MCX Bhavcopy (official daily settlement file) | https://www.mcxindia.com/market-data/bhavcopy | Daily, automated | Public EOD file, not scraped — exchange-published |
| Aluminium | *(fetched daily)* | MCX Bhavcopy | https://www.mcxindia.com/market-data/bhavcopy | Daily, automated | Same file as Copper |
| Iron/Steel | *(fetched daily)* | MCX Bhavcopy | https://www.mcxindia.com/market-data/bhavcopy | Daily, automated | Check symbol availability — MCX steel contracts vary |
| Lead | *(fetched daily)* | MCX Bhavcopy | https://www.mcxindia.com/market-data/bhavcopy | Daily, automated | **New in this version** — required for Battery/CRT formulas |
| Backup/cross-check | — | metals-api.com or metalpriceapi.com (free tier) | https://metals-api.com | As needed | Used only if MCX file format changes and daily script breaks |

**Terms-of-use note:** Checked MCX's website terms before relying on Bhavcopy beyond personal/academic/hackathon use. *(Fill in date checked: __________)*

---

## Layer 2 — Scrap Conversion Factors (Official Rate → Scrap Rate)

| Material | Factor | Derivation | Evidence Log Location | Last Recalibrated |
|---|---|---|---|---|
| Copper | 0.70 | Avg of N real ScrapRates.in listings (Punjab/Maharashtra) ÷ same-day MCX rate | `/sources/copper_factor_log.csv` — *(create this, log each listing + date + URL/screenshot)* | *(date)* |
| Aluminium | 0.62 | Same method | `/sources/aluminium_factor_log.csv` | *(date)* |
| Iron | 0.65 | Same method | `/sources/iron_factor_log.csv` | *(date)* |
| Lead | *(to derive)* | Same method — pull ScrapRates.in lead-scrap listings once available | `/sources/lead_factor_log.csv` | *(date)* |

**Recalibration cadence:** Quarterly, or immediately if a spot-check (Part A Step 6) shows drift beyond ~10%.

---

## Layer 3 — Composition Fractions & Recovery Efficiencies

| Category | Constant | Value Used | Source (cite specific paper/page) | Range Reported in Literature | Notes |
|---|---|---|---|---|---|
| PCB | Copper fraction | 0.18 | ScienceDirect — WPCB elemental composition studies (2021–2025); PMC — PCB metal recovery studies | 16–20% | Precious metals (Au/Ag/Pd) handled as separate fixed multiplier, not modeled live |
| PCB | Copper recovery efficiency | 0.85 | Same PCB recovery literature | 82–92% | Recalibrate against vendor quotes |
| PCB | Precious-metal multiplier | *(to set)* | Derived from vendor-quote spot-checks (Part A Step 6) | — | Fixed, not live-priced — no practical live gold/PGM feed for this project |
| Cable (light/flex) | Copper fraction | 0.35 | Recycling-industry guides (Okon Recycling, Rockaway Recycling, GLE Scrap) | ~30% | |
| Cable (heavy/armoured) | Copper fraction | 0.70 | Same industry guides | 85%+ (upper range) | Offer both grades as separate sub-categories |
| Cable (mixed/general) | Copper fraction | 0.45 | Same industry guides | 40–50% | Default if grade unknown |
| Motor (small) | Copper winding fraction | 0.11 | Sahd Metal Recycling; nmrecycling.co.uk | 9–13% | |
| Motor (large/industrial) | Copper winding fraction | 0.09 | Same sources | 7–10% (lower end) | |
| Battery (lead-acid) | Lead fraction | 0.60 | ScienceDirect Topics; ScrapMonster; Scrap City | 60–65% | Requires Lead added to Layer 1 (done in this version) |
| CRT | Lead-oxide fraction (funnel glass) | 0.30 | ResearchGate / WEEE Forum / USPTO patent literature on CRT leaded glass | 20–25% (general), up to 35–40% (funnel glass specifically) | **Can legitimately be a negative price** — see formula notes |
| LCD | Aluminium frame fraction | *(to set)* | *(measure/estimate from a disassembled unit or vendor input)* | — | No live indium feed practical; trace-metal value folded into small fixed component |

---

## How to Use This File

1. Before changing any number in the script, add/update its row here **first**, with today's date.
2. When you do a quarterly vendor spot-check (Part A Step 6), log the result in a new row under a "Verification Log" section (add one if you don't have it yet) — date, vendor, quoted price, formula-predicted price, % difference.
3. When presenting to judges: this file — not the code — is what proves the pricing isn't fabricated. Show this file, not just the CSV output.
