# 💻 Device Cleanup Script

## ✅ Purpose

Identify and safely remove **stale Entra devices** that:

- Haven’t signed in for X days
- Are not active in Intune
- Have low confidence match

---

## 🔍 Key Logic

| Signal | Source |
|------|--------|
| Last Sign-In | Entra |
| Device Presence | Intune |
| Activity | Intune sync |

### Classification
- `KEEP_IntuneActive`
- `KEEP_RecentActivity`
- `DELETE_Stale`

---

## 📁 Output Files

| File | Description |
|-----|------------|
| `FULL` | All devices |
| `DELETE` | Safe delete candidates |
| `DELETE_TOP50` | Batched delete set |
| `KEEP` | Retained devices |
| `MISMATCH_IntuneOnly` | Intune-only devices |
| `MISMATCH_EntraOnly` | Entra-only devices |
| `MissingDeviceId` | Intune devices with no Entra link |
| `Log` | Execution log |

---

## 🛡️ Safe Delete Criteria

A device is marked safe if:

- Stale in Entra ✅  
- Not active in Intune ✅  
- Match confidence = Low ✅  

---

---

