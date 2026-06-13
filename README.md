<div align="center">

# tb-mdt

**Premium SaaS-style Police MDT for FiveM**

[![Version](https://img.shields.io/badge/version-1.1.0-blue?style=flat-square)](#)
[![Vue 3](https://img.shields.io/badge/Vue%203-NUI-42B883?style=flat-square&logo=vue.js&logoColor=white)](#)
[![Lua 5.4](https://img.shields.io/badge/Lua-5.4-2C2D72?style=flat-square&logo=lua&logoColor=white)](#)
[![Qbox](https://img.shields.io/badge/Qbox-supported-FF6B35?style=flat-square)](#)
[![QBCore](https://img.shields.io/badge/QBCore-supported-E44D26?style=flat-square)](#)

</div>

---

## Overview

A modern police Mobile Data Terminal with a dark SaaS-style dashboard (Vue 3 + Tailwind 4 + Pinia). Real-time dispatch, full records workflow (citizen → charges → fine/jail → rap sheet), weapons registry, department roster, announcements, and a panic button. Auto-detects Qbox or QBCore at runtime.

12 database tables, auto-created on first boot.

---

## Quick Start

```cfg
# server.cfg
ensure oxmysql
ensure ox_lib
ensure tb-lib
ensure qbx_core   # or qb-core
ensure tb-mdt
```

Open with **F5** (configurable) while on duty as an allowed job, or walk to a physical MDT terminal (Mission Row / Sandy / Paleto by default).

---

## Modules

| Module | Features |
|--------|----------|
| **Dashboard** | Live stats, recent calls/incidents, officers on duty, department announcements |
| **Dispatch** | Calls with priority 1–5, assign/unassign units, status workflow, real-time broadcast |
| **Citizens** | Search, full profile, mugshot, officer notes, flags (violent/armed/gang/…), rap sheet, license management |
| **Charges** | Penal code with **min–max fine & sentence sliders**, server-validated, auto fine collection + jail handoff, license points with auto-revoke |
| **Vehicles** | Plate lookup, owner info, linked BOLOs/incidents, **stolen flag** with banner |
| **Incidents** | Case reports with suspects, charges, evidence, auto-warrant creation |
| **Warrants** | Issue / execute with grade gating, real-time alerts |
| **BOLOs** | Person & vehicle BOLOs, plate-linked |
| **Evidence** | Typed evidence (photo/note/weapon/drug) attached to cases |
| **Weapons Registry** | Serial registration, owner linkage, stolen/seized/destroyed status |
| **Roster** | Full department roster, online status, callsign management (grade-gated) |
| **Panic Button** | `/panic` or F9 — flashing GPS blip, sound, sticky red overlay for all officers |

---

## Charge Processing Workflow

1. Open a citizen profile → **Process Charges**
2. Pick charges from the penal code (traffic / misdemeanor / felony tabs)
3. Slide fine and sentence within the configured min–max per charge
4. **Process** — the server then:
   - Validates and clamps every value against `Config.PenalCode` (server-authoritative)
   - Records convictions on the rap sheet (`mdt_charges`)
   - Deducts the fine from the citizen's bank if online (`tb-lib` bridge), otherwise stores an unpaid fine (`mdt_fines`)
   - Sends the citizen to jail via `Config.Jail` (event or export mode — qb-prison compatible by default)
   - Accumulates license points and auto-revokes the driver's license at `Config.LicensePoints.limit`
   - Notifies the charged citizen and writes a Discord audit log

---

## Configuration

All in `config.lua`:

| Section | Purpose |
|---------|---------|
| `Config.AllowedJobs` | Jobs that can open the MDT |
| `Config.Permissions` | Per-job, per-feature, per-grade action gating (mirrored client + server) |
| `Config.PenalCode` | Charges with `fineMin/fineMax`, `jailMin/jailMax`, `points` |
| `Config.Fines` | `bank_then_record` or `record_only` |
| `Config.Jail` | `event` / `export` / `none` — point at your prison resource |
| `Config.LicensePoints` | Point limit + which license to auto-revoke |
| `Config.Panic` | Keybind, cooldown, blip styling |
| `Config.MDTStations` | Physical terminal coordinates |
| `Config.WebhookURL` | Discord audit logging via tb-lib |

---

## Database

12 tables, auto-created on boot (or run `sql/setup.sql` manually):

`mdt_officers` · `mdt_calls` · `mdt_incidents` · `mdt_warrants` · `mdt_bolos` · `mdt_evidence` · `mdt_charges` · `mdt_fines` · `mdt_weapons` · `mdt_profiles` · `mdt_announcements` · `mdt_vehicle_flags`

---

## Server Security

- Every callback re-validates job + grade server-side (`HasPermission`)
- Charge fines/sentences clamped to penal-code ranges on the server
- Rate limiting on search/create actions
- Parameterized SQL throughout
- Panic position read from the server-side ped, not client input
- Webhook audit trail for charges, warrants, weapons, licenses, panic

---

## Dependencies

| Resource | Required |
|----------|----------|
| [oxmysql](https://github.com/overextended/oxmysql) | ✅ |
| [ox_lib](https://github.com/overextended/ox_lib) | ✅ |
| tb-lib | ✅ (framework bridge + webhooks) |
| [qbx_core](https://github.com/Qbox-project/qbx_core) or [qb-core](https://github.com/qbcore-framework/qb-core) | ✅ (one of) |
| A prison resource (qb-prison compatible event, or wire `Config.Jail.export`) | Optional |

---

## Development

```bash
cd web
npm install
npm run dev        # browser dev server
npm run build      # → web/dist (required before in-game testing)
npm run type-check
```

---

## Changelog

**v1.1.0** — Charge calculator with min–max sliders, rap sheet, fines (bank deduction + unpaid records), jail handoff, license management with points auto-revoke, weapons registry, department roster + callsign management, announcements, mugshots/notes/flags on citizen profiles, stolen vehicle flags, panic button with GPS blip + overlay
**v1.0.0** — Initial release: dashboard, dispatch, citizens, vehicles, incidents, warrants, BOLOs, evidence

---

<div align="center">

**tb-mdt v1.1.0** — Toybox Development

</div>
