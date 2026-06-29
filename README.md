# Microsoft Entra Cleanup Scripts

This repository contains two PowerShell scripts designed to safely identify and optionally clean up stale objects in Microsoft Entra ID:

- ✅ [**Device Cleanup Script**] (stale-device-review.md)
- ✅ [**User Cleanup Script**] (dormant-user-review.md)

Both scripts follow the same design principles:

- Safety-first execution (View / Dry Run / Delete modes)
- Strong validation and confidence scoring
- CSV-based exclusions
- Audit logging
- Staged cleanup (Top 50 batching)

---

# 🧠 How the Scripts Work

## ✅ Common Workflow

1. **Mode selection**
   - View → Read-only
   - Dry Run → Simulates actions
   - Delete → Executes changes

2. **Connect to Microsoft Graph**
   - Read scopes for View/Dry Run
   - Read/Write scopes for Delete

3. **Pull data**
   - Devices → Entra + Intune
   - Users → Entra + Sign-in activity

4. **Apply logic**
   - Determine activity/inactivity
   - Apply exclusions
   - Assign classification

5. **Score confidence**
   - High → Reliable match/activity
   - Medium → Partial data
   - Low → No signals

6. **Generate outputs**
   - Full report
   - Actionable subset (Top 50)
   - Supporting reports

7. **(Optional) Execute changes**
   - Only in Delete mode
   - Requires confirmation
   - Fully logged

---
