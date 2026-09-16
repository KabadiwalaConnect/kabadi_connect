"""
Price Dataset Generator — v3
================================
Changes from v2 (see README.md for full explanation):

1. REAL API IMPLEMENTATION: fetch_official_rates() now actually calls the
   Metals.Dev API (v2 left this as a placeholder). Copper, Aluminium,
   Iron, and Lead are fetched live when a key is available.

2. DUAL KEY-SOURCE SUPPORT: The script now accepts the API key from
   EITHER:
     (a) a local config.py file (for manual runs on your own computer), OR
     (b) an environment variable METALS_API_KEY (for automated GitHub
         Actions runs, where the key lives in GitHub Secrets, never in
         a file at all)
   You do not need to choose one — the script tries config.py first,
   then falls back to the environment variable, then to DEMO_MODE.

3. NEGATIVE-PRICE FIX: CRT (and any other category) can genuinely compute
   to a negative value in the formula — meaning "this costs money to
   dispose of" rather than "this earns money." That is economically
   honest, but an app cannot show a customer a negative price. So:
     - The RAW computed value is still calculated and kept (for
       transparency / SOURCES.md / research purposes).
     - The DISPLAYED price shown to the app/collector is floored at 0.
     - A new column `requires_handling_fee` (True/False) flags any
       category where this floor was applied, so the app can show a
       message like "small handling fee may apply" instead of a
       negative number or a misleadingly cheerful price.
"""

import os
import pandas as pd
import random
from datetime import datetime, timedelta

# ---------------------------------------------------------------------
# API KEY — tries config.py first (local/manual runs), then the
# METALS_API_KEY environment variable (GitHub Actions runs), then
# safely falls back to DEMO_MODE.
# ---------------------------------------------------------------------
try:
    from config import API_KEY, DEMO_MODE
    print("[INFO] Using API key from local config.py")
except ImportError:
    API_KEY = os.environ.get("METALS_API_KEY")
    if API_KEY:
        DEMO_MODE = False
        print("[INFO] Using API key from environment variable (GitHub Actions mode).")
    else:
        API_KEY = None
        DEMO_MODE = True
        print("[INFO] No config.py and no METALS_API_KEY env var found - running in DEMO MODE.")

# ---------------------------------------------------------------------
# LAYER 1 — Fallback values (used only if DEMO_MODE or the API call fails)
# ---------------------------------------------------------------------
FALLBACK_OFFICIAL_RATES_INR_PER_KG = {
    "Copper": 900.0,
    "Aluminium": 240.0,
    "Iron": 55.0,
    "Lead": 180.0,
}

# LAYER 2 — see SOURCES.md for derivation evidence of every factor below
SCRAP_CONVERSION_FACTORS = {
    "Copper": 0.70,
    "Aluminium": 0.62,
    "Iron": 0.65,
    "Lead": 0.55,
}

# ---------------------------------------------------------------------
# LAYER 3 — Composition-based model. Every fraction/efficiency here MUST
# have a matching row in SOURCES.md with its citation.
# ---------------------------------------------------------------------
COMPOSITION_MODEL = {
    "PCB": {
        "driver_metal": "Copper",
        "fraction": 0.18,
        "recovery_efficiency": 0.85,
        "precious_metal_multiplier": 1.35,
        "processing_cost": 15,
    },
    "Cable": {
        "driver_metal": "Copper",
        "fraction": 0.45,
        "recovery_efficiency": 0.90,
        "processing_cost": 8,
    },
    "Motor": {
        "driver_metal": "Copper",
        "fraction": 0.11,
        "recovery_efficiency": 0.80,
        "processing_cost": 20,
        "housing_value_flat": 12,
    },
    "Battery": {
        "driver_metal": "Lead",
        "fraction": 0.60,
        "recovery_efficiency": 0.88,
        "processing_cost": 10,
    },
    "CRT": {
        "driver_metal": "Lead",
        "fraction": 0.30,
        "recovery_efficiency": 0.40,
        "processing_cost": 120,
        "hazardous_handling_cost": 60,
    },
    "LCD": {
        "driver_metal": "Aluminium",
        "fraction": 0.20,
        "recovery_efficiency": 0.75,
        "processing_cost": 10,
        "small_fixed_component_value": 8,
    },
}

LOCATIONS = {
    "Punjab": ["Ludhiana", "Amritsar", "Jalandhar"],
    "Maharashtra": ["Mumbai", "Pune"],
}
LOCATION_MULTIPLIER = {
    "Ludhiana": 1.00, "Amritsar": 1.02, "Jalandhar": 0.96,
    "Mumbai": 1.05, "Pune": 1.02,
}
NUM_HISTORICAL_DAYS = 90


def fetch_official_rates():
    """Fetches Copper/Aluminium/Iron/Lead from the Metals.Dev API."""
    if DEMO_MODE or not API_KEY:
        print("[DEMO MODE] Using research-based fallback rates (no live fetch).")
        return FALLBACK_OFFICIAL_RATES_INR_PER_KG

    import requests
    try:
        url = f"https://api.metals.dev/v1/latest?api_key={API_KEY}&currency=INR&unit=kg"
        resp = requests.get(url, timeout=10)
        resp.raise_for_status()
        data = resp.json()
        metals = data["metals"]
        return {
            "Copper": metals["copper"],
            "Aluminium": metals.get("aluminum", metals.get("aluminium")),
            "Iron": metals.get("steel", FALLBACK_OFFICIAL_RATES_INR_PER_KG["Iron"]),
            "Lead": metals["lead"],
        }
    except Exception as e:
        print(f"[WARNING] API call failed ({e}) - using fallback rates.")
        return FALLBACK_OFFICIAL_RATES_INR_PER_KG


def compute_scrap_prices(official_rates):
    return {
        material: round(official_rates[material] * factor, 2)
        for material, factor in SCRAP_CONVERSION_FACTORS.items()
        if material in official_rates and official_rates[material] is not None
    }


def compute_ewaste_prices(scrap_prices):
    """
    Layer 3 — composition-based. Returns TWO dicts:
      - display_prices: floored at 0, safe to show in the app
      - handling_fee_flags: True where the raw computation was negative
        (i.e. this item costs money to process, not earns money)
    Also returns raw_prices (unfloored) for transparency/logging.
    """
    display_prices = {}
    handling_fee_flags = {}
    raw_prices = {}

    for category, m in COMPOSITION_MODEL.items():
        driver_price = scrap_prices.get(m["driver_metal"], 0)
        recovered_value = m["fraction"] * driver_price * m["recovery_efficiency"]

        raw_price = recovered_value - m.get("processing_cost", 0)
        raw_price += m.get("housing_value_flat", 0)
        raw_price += m.get("small_fixed_component_value", 0)
        raw_price -= m.get("hazardous_handling_cost", 0)

        if "precious_metal_multiplier" in m:
            raw_price *= m["precious_metal_multiplier"]

        raw_prices[category] = round(raw_price, 2)

        if raw_price < 0:
            display_prices[category] = 0.0
            handling_fee_flags[category] = True
        else:
            display_prices[category] = round(raw_price, 2)
            handling_fee_flags[category] = False

    return display_prices, handling_fee_flags, raw_prices


def generate_historical_dataset():
    official_rates = fetch_official_rates()
    is_live_call = (not DEMO_MODE) and bool(API_KEY)

    today_scrap_prices = compute_scrap_prices(official_rates)
    today_ewaste_prices, handling_fee_flags, raw_prices = compute_ewaste_prices(today_scrap_prices)
    all_today_prices = {**today_scrap_prices, **today_ewaste_prices}

    source_type_map = {
        "Copper": "Derived (Formula from Metals.Dev API - MCX/LME-linked)",
        "Aluminium": "Derived (Formula from Metals.Dev API - MCX/LME-linked)",
        "Iron": "Derived (Formula from Metals.Dev API - MCX/LME-linked)",
        "Lead": "Derived (Formula from Metals.Dev API - MCX/LME-linked)",
        "PCB": "Derived (Composition Model - Copper-driven)",
        "Cable": "Derived (Composition Model - Copper-driven)",
        "Motor": "Derived (Composition Model - Copper-driven)",
        "Battery": "Derived (Composition Model - Lead-driven)",
        "CRT": "Derived (Composition Model - Lead-driven, hazard-adjusted)",
        "LCD": "Derived (Composition Model - Aluminium-driven)",
    }

    rows = []
    today = datetime.now()

    for day_offset in range(NUM_HISTORICAL_DAYS):
        date = today - timedelta(days=day_offset)
        is_today = (day_offset == 0)

        for state, cities in LOCATIONS.items():
            for city in cities:
                loc_mult = LOCATION_MULTIPLIER.get(city, 1.0)
                for category, base_price in all_today_prices.items():
                    if is_today:
                        daily_price = max(0.0, round(base_price * loc_mult, 2))
                        source = ("Metals.Dev API - LIVE fetch" if is_live_call
                                  else "DEMO MODE - Fallback Estimate (NOT live)")
                    else:
                        fluctuation = random.uniform(0.90, 1.10)
                        daily_price = max(0.0, round(base_price * loc_mult * fluctuation, 2))
                        source = "Simulated historical trend (see SOURCES.md for base-value citations)"

                    requires_fee = handling_fee_flags.get(category, False)

                    rows.append({
                        "date": date.strftime("%d-%m-%Y"),
                        "material_category": category,
                        "state": state,
                        "location": city,
                        "buying_price": daily_price,
                        "unit": "per kg",
                        "market_range_low": round(daily_price * 0.92, 2),
                        "market_range_high": round(daily_price * 1.08, 2),
                        "requires_handling_fee": requires_fee,
                        "source_type": source_type_map.get(category, "Unknown"),
                        "source": source,
                    })

    return pd.DataFrame(rows), raw_prices


if __name__ == "__main__":
    df, raw_prices = generate_historical_dataset()
    df.to_csv("price_dataset.csv", index=False)
    print(f"\nDone! {len(df)} rows saved to price_dataset.csv")

    print("\nToday's computed prices (Ludhiana) - DISPLAY value (never negative):")
    today_str = datetime.now().strftime("%d-%m-%Y")
    print(df[(df["date"] == today_str) & (df["location"] == "Ludhiana")]
          [["material_category", "buying_price", "requires_handling_fee", "source_type"]].to_string(index=False))

    print("\nRaw (unfloored) computed values, for transparency/SOURCES.md logging:")
    for cat, val in raw_prices.items():
        flag = " <-- floored to 0 for display, this is a disposal-cost item" if val < 0 else ""
        print(f"  {cat}: Rs.{val}/kg{flag}")
