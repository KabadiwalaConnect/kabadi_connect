# Price Dataset Engine — README

*This document explains everything about how `price_dataset.csv` is generated: what's real, what's a formula, why some numbers are floored at zero, and how the daily automation works. Read this before touching `generate_price_dataset.py`.*

---

## 1. What This Module Does

Generates `price_dataset.csv` — a 90-day price history across Punjab and Maharashtra cities, for 10 material categories (Copper, Aluminium, Iron, Lead, PCB, Cable, Motor, Battery, CRT, LCD). This is the data our app's "Today's Rate" feature reads from.

---

## 2. The 3-Layer Pricing Model

### Layer 1 — Official Metal Rates (Real, Live)
Copper, Aluminium, Iron, and Lead prices come from the **Metals.Dev API**, which legally resells official MCX/LME commodity-exchange data. This is a real, verifiable, official source — not scraped, not invented.

### Layer 2 — Scrap Conversion Factor
```
scrap_price = official_rate × conversion_factor
```
The conversion factors (0.70 for Copper, 0.62 for Aluminium, etc.) were derived by comparing real scrap-market listings (ScrapRates.in) against the official rate on the same day. Full derivation evidence, sources, and dates are logged in **`SOURCES.md`** — read that file for the "is this real" proof.

### Layer 3 — Composition-Based E-Waste Pricing (NEW in this version)
This is the biggest change from the old version. Previously, PCB/Battery/CRT/LCD/Cable/Motor were **flat, static numbers** picked once from research and never changing. Now, each one is priced as **"how much recoverable metal does it contain, at today's metal price":**

```
Price(category) = (metal_fraction × today's_metal_price × recovery_efficiency)
                   − processing_cost + other_adjustments
```

For example, a PCB is modeled as **18% copper by weight**, so when Copper's price moves, PCB's price automatically moves too — without anyone doing new field research every day. Every fraction/efficiency number used here has a citation in `SOURCES.md`.

| Category | Driven By | Why |
|---|---|---|
| PCB, Cable, Motor | Copper | These contain a copper fraction (highest in Cable, lowest in Motor windings) |
| Battery, CRT | Lead | Lead-acid batteries and CRT glass both contain significant lead |
| LCD | Aluminium | Priced mainly on its aluminium frame; trace metals folded into a small fixed value |

---

## 3. ⚠️ Important: Why CRT Sometimes Shows ₹0 With a "Handling Fee" Flag

CRT glass contains lead, but that lead is chemically bound in glass and **expensive to extract**. When we actually calculate it honestly, the formula often comes out **negative** — meaning it genuinely costs more to process a CRT than the recovered lead is worth. Real recyclers often charge a disposal/handling fee for CRTs rather than paying for them.

**We cannot show a negative number in the app** (it would look like a bug, and confuse a collector). So:
- If the formula's raw result is negative, the **displayed price is floored at ₹0**
- A column `requires_handling_fee = True` is set for that row
- The **app should use this flag** to show a message like *"This item may involve a small handling fee"* instead of a price — this is more honest than showing a fake positive number, and safer than showing a negative one

The raw (unfloored) value is still printed to the console when the script runs, and should be logged in `SOURCES.md`'s verification section — we're not hiding the real math, just not displaying a negative price to end users.

---

## 4. API Key Setup — Two Different Situations

### Situation A: Running the script manually on your own laptop
Create a file called `config.py` in this folder (copy `config_example.py` and rename it):
```python
API_KEY = "your-real-metals-dev-key"
DEMO_MODE = False
```
This file is listed in `.gitignore` — it will never be pushed to GitHub. Never send this file to anyone or paste it in chat.

### Situation B: Automated daily runs via GitHub Actions
GitHub Actions does **not** use `config.py` at all — it can't, since that file never leaves your computer. Instead, the key is stored in **GitHub Secrets** (Settings → Secrets and variables → Actions → New repository secret, name it `METALS_API_KEY`). The workflow file (`.github/workflows/daily-price-update.yml`) reads it from there automatically as an environment variable. The script checks for `config.py` first, and if that's not found, checks for this environment variable — so the same script works in both situations without any changes.

### If neither is set up
The script safely runs in `DEMO_MODE`, using research-based fallback numbers. Nothing breaks — it just won't be "live."

---

## 5. API Quota — How Long Does One Key Last?

Metals.Dev's free tier gives **100 requests per month**. Our automation calls the API **once per day** (~30 requests/month), which is well within the free limit. **The same key keeps working indefinitely** — you do not need a new key every few days. You would only need to upgrade or get a second key if the app started calling the API more than ~3 times a day on average.

---

## 6. Automation — How the Daily Update Works

File: `.github/workflows/daily-price-update.yml`

1. Runs automatically every day at 6:00 AM IST
2. Checks out the code, installs Python + pandas
3. Runs `generate_price_dataset.py`, passing the API key from GitHub Secrets
4. Commits the newly generated `price_dataset.csv` back to the repository automatically

**Important gotcha:** GitHub only runs *scheduled* (cron) workflows from the **default branch** (`main`). While this is being developed on a feature branch, you can trigger it manually from the "Actions" tab (there's a "Run workflow" button, thanks to `workflow_dispatch` in the file) — but the automatic daily schedule will only start working once this is merged into `main`.

---

## 7. What Changed From the Previous Version (v2 → v3)

| Change | File | Why |
|---|---|---|
| Real Metals.Dev API call implemented (was a placeholder before) | `generate_price_dataset.py` | v2 had `NotImplementedError` here — now it actually fetches live data |
| Added support for reading the API key from an environment variable, not just `config.py` | `generate_price_dataset.py` | Needed so GitHub Actions can run it without a local file |
| Negative prices are floored at ₹0 with a `requires_handling_fee` flag | `generate_price_dataset.py` | CRT (and potentially others) can compute negative — can't show that in the app |
| Added GitHub Actions automation | `.github/workflows/daily-price-update.yml` (new file) | So the dataset updates every day without anyone running the script manually |
| Documented everything | `README.md` (this file, new) | So any teammate can understand the system without re-reading the whole chat history |

Compared to the original (v1) version: Lead was added as a tracked metal (needed for Battery/CRT), and PCB/Battery/CRT/LCD/Cable/Motor moved from flat "field research" numbers to the composition-based formulas described in Section 2 — see `SOURCES.md` for the composition-fraction citations.

---

## 8. Files In This Module

| File | Push to GitHub? | Contains a Secret? |
|---|---|---|
| `generate_price_dataset.py` | ✅ Yes | No |
| `price_dataset.csv` | ✅ Yes | No |
| `config_example.py` | ✅ Yes | No — placeholder text only |
| `.gitignore` | ✅ Yes | No |
| `SOURCES.md` | ✅ Yes | No |
| `README.md` | ✅ Yes | No |
| `.github/workflows/daily-price-update.yml` | ✅ Yes | No — reads secret at runtime, doesn't store it |
| `config.py` | ❌ **NEVER** | ✅ Yes — this is the only file with your real key |

---

## 9. How to Run It Yourself

```bash
pip install pandas requests
python3 generate_price_dataset.py
```
Check the console output — it tells you clearly whether it ran in DEMO_MODE or with a live API call, and shows you the raw (pre-floor) values for any category that hit the handling-fee floor.
