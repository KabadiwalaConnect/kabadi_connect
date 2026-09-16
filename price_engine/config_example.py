"""
CONFIG TEMPLATE
================
This file (config_example.py) is a TEMPLATE ONLY - the script never reads
this file directly. It exists purely so you know what your own config.py
should look like once you have a real API key, IF you ever run this
script manually on your own laptop.

Steps to activate the live API for a MANUAL/local run (NOT needed for
GitHub Actions - that uses GitHub Secrets instead, see README.md):
1. Copy this file and rename the copy to: config.py
2. Replace the placeholder below with your real Metals.Dev API key
3. Change DEMO_MODE to False
4. config.py is listed in .gitignore, so it will NEVER be pushed to GitHub

Until you do this, the main script automatically runs in DEMO MODE by
itself (it does NOT need this file to be present at all) - so there is
nothing broken or missing right now. This file just shows what to do
LATER, for a local run, if ever needed.

Steps to get a free API key:
- Go to https://metals.dev
- Sign up for a free account
- Copy the API key from your dashboard
- Paste it below in your own config.py (not in this example file)
"""

API_KEY = "paste-your-real-metals-dev-api-key-here"
DEMO_MODE = True   # <-- Keep this True until you actually have a real key above.
                    #     Only change to False after replacing the placeholder key.
