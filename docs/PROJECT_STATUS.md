# Packtory — Project Status & Full Description

_Last updated: June 2026. This document describes what the game is today, what is implemented, and what has been built and confirmed working in playtesting and fixes from recent development._

---

## 1. What Packtory Is

**Packtory** is an isometric warehouse / order-fulfilment game built in **Godot 4.6**. You control a single **manager** inside a small warehouse. Customers walk in from the street, queue at the door, and place random product orders. You **take** an order, **collect** items from shelves (or from delivery boxes at the loading dock), **pack** them at a packing table, and **deliver** the package to the waiting customer.

The current build is a **playable vertical slice**: one warehouse, three products, outdoor environment, loading-dock intro, full UI, action queue, and the complete **take → pick → pack → deliver** loop.

---

## 2. Tech Stack & Entry Points

| Item | Detail |
|------|--------|
| Engine | Godot 4.6, GL Compatibility renderer (D3D12 on Windows) |
| Main scene | `res://scenes/main/main_menu.tscn` (warehouse: `scenes/main/main.tscn`) |
| Autoloads | 17 singletons — `GridService`, `AlertMessages`, `GameSession`, `EconomyManager`, `ProgressionManager`, `ReputationManager`, `UnlockManager`, `GameTimeManager`, `IncomingDeliveryManager`, `WorkerHireManager`, `DayEndManager`, `DayStatsTracker`, `DayEndFlow`, `WorkerTaskManager`, `GarbageDropManager`, `SaveManager`, `DevSceneNav` |
| Viewport | 1440×900 default |
| Verification | `godot --headless --path . --script res://scripts/test/run_all_tests.gd` (41 gameplay suites) |

**Asset kits (Kenney / KayKit / Starter Kit):**

- Starter Kit City Builder — ground tiles (grass, pavement, road, trees)
- KayKit City Builder Bits — benches, streetlights, hydrants, bins
- Kenney Building Kit — warehouse shell
- Kenney Mini Market — shelf mesh, fence rails
- Kenney Mini Characters — manager + customers (GLB)
- Kenney Car Kit — road traffic + delivery truck + box prop
- Household Props 001 — packing table

UI icons: `assets/ui/icons/` loaded via `IconRegistry` (see `docs/ai-asset-generation.md`).

---

## 3. World Layout (`GridService` / `WarehouseGrid`)

- **Lot:** 34×34 cells (12×12 warehouse + 11-cell padding on each side).
- **Warehouse interior:** cells x 11–22, z 11–22.
- **Coordinates:** 1 m cells; Z increases south (toward camera / road).
- **South entrance:** 2 m door at columns 15–16; walkway from door to sidewalk.
- **Loading dock:** east of warehouse (cols 24–26, rows 14–17), back door on east wall, truck spur road to main road.
- **Decorative road:** **2 east–west lanes** south of the yard, sidewalks north/south of road, **T-junction** at `DOCK_ROAD_COL` connecting to dock offload spur (not a multi-lane highway).
- **Work zone (north):** shelves at z≈14, packing table at z≈12.
- **Queue zone (south-centre):** single-file lane column 16, rails at 14 & 18, front slot toward work zone.

**Pathfinding:** `Pathfinding` (AStarGrid2D) over warehouse + dock navigable cells; walls/shelves/table block cells; `navigation_changed` triggers repaths.

---

## 4. Environment (Confirmed Working)

| System | Script | Status |
|--------|--------|--------|
| Ground tiling | `grid_floor.gd` | Grass (solid tint + noise), trees scattered yard-wide, pavement, 2-lane road + split junction, warehouse floor |
| Street props | `grass_decorations.gd` | Streetlights, benches, hydrant, trash, dumpster (water tower removed) |
| Building shell | `warehouse_walls.gd`, `kenney_building_layout.gd` | Perimeter walls, windows on far walls, low near walls, doorway |
| Road traffic | `road_traffic.gd`, `road_car.gd` | Random cars on E–W road lanes |
| Sidewalk pedestrians | `sidewalk_pedestrians.gd` | Decorative walkers on sidewalks / walkway |

---

## 5. Characters (Confirmed Working)

| Role | Source | Notes |
|------|--------|-------|
| Manager | `scenes/worker/worker.tscn` → Kenney `character-male-d.glb` (blender path) | Auto-selected; selection ring; walk + pack animations |
| Customers | Random Kenney `character-*.glb` from `customer_queue.gd` | Walk-in path, queue slots, speech bubble, hourglass while waiting |

**Character cleanup (`character_model_cleanup.gd`):**

- Runtime: removes only **accessory-named** nodes (aid, hearing, crutch, etc.) — does **not** strip arm/body meshes (fixes arm “holes”).
- Offline: `tools/strip_hand_aids_from_characters.py` removes baked 16-triangle hearing-aid islands from body meshes in GLB files.

---

## 6. Core Gameplay Loop (Confirmed End-to-End)

```
Customer arrives → queue (PENDING)
    → Take order (front customer, bubble)
    → Collect products (shelves or had stock from dock boxes)
    → Pack at packing table (timed bar)
    → Deliver package to customer
    → Customer departs (east exit lane), queue advances
```

### 6.1 Manager (`Worker`)

- **Movement:** `walk_to_world`, grid pathfinding, `face_world`.
- **Inventory:** Up to **4 product types** (stacks); **no hard unit cap** (`free_capacity` effectively unlimited).
- **Package:** One `package` item after packing; blocks picking other products until delivered.
- **Packing:** ~3.5 s progress bar above character; `consume_order_and_pack` / `restore_packed_order` on failure.
- **Interaction:** Selected by default; tap to reselect; tap floor for “Go Here” when selected.

### 6.2 Products (`ProductCatalog`)

| ID | Display | Orderable |
|----|---------|-----------|
| `headphones` | Headphones | Yes |
| `hair_dryer` | Hair Dryer | Yes |
| `mouse` | Mouse | Yes |
| `package` | Package | No (packed result) |

- Random orders: 1–3 product types, ≤ `ORDER_MAX_UNITS` (4) total units.
- Helpers: `inventory_fulfills_order`, `orders_match`, `random_order`, colours, box sizes for shelf visuals.

### 6.3 Shelves (`ProductShelf`)

- **Three shelves** in north work zone (`warehouse_shelves.gd`); start **empty** (any product when first stocked).
- **Max stock: 6** (3 boxes × 2 rows) — **visual count matches `count`**; label shows e.g. `3/6`.
- **Take / stock:** Context menu with quantity picker; each `take_one()` rebuilds boxes so removed units disappear from shelf.
- Kenney `shelf-end.glb`; baked carton meshes stripped; product boxes + product icon on front face.
- **3D label:** `ProductLabel3D` above shelf (icon + count).

### 6.4 Packing table (`PackingTable`)

- Household Props table, 3-cell footprint, blocked for pathfinding.
- **Pack the order** when inventory fulfills active order and queue allows it.
- Approach / face helpers for manager walk + pack animation.

### 6.5 Customers & queue (`CustomerQueue`, `Customer`)

- Spawns up to **4** customers on timer (continues during gameplay).
- States: `ARRIVING → PENDING → TAKEN → WAITING_PICKUP → DEPARTING`.
- Front customer shows **order bubble** when order can be taken.
- **Hourglass** bubble while order is taken but not yet delivered.
- Exit via **east lane** (cell 17) to avoid blocking queue.
- Single **active order** on queue; `active_order_changed` signal drives UI.

### 6.6 Loading dock (`LoadingDock`, `DeliveryBox`)

- Truck animates in from main road → junction → spur → dock parking.
- Three **delivery boxes** on dock apron (headphones ×10, hair dryer ×8, mouse ×6 labels).
- **Pick up box:** manager walks to box; contents go to inventory (box despawns).
- Customer queue can start after delivery cleared or **120 s fallback** timer.

---

## 7. Input & Interaction (Confirmed Working)

**Pipeline:** `TouchInput` (tap) → `GameplayInput` (raycast layer 1) → context menu or floor move.

| Target | Actions |
|--------|---------|
| Worker | Select |
| Product shelf | Take (qty), Stock (qty) — projected queue validation |
| Customer | Take order, Fulfill order |
| Packing table | Pack the order |
| Delivery box | Pick up box |
| Floor (worker selected) | Go Here |

**Fixes confirmed in this area:**

- Tapping packing table / world works while **inventory panel** is open (overlay ignores mouse; tap outside closes bag).
- **Pack order** enqueues correctly (projected-state validation after simulated pack fixed).
- **Alert toasts** when no actions available or queue rejects action.

---

## 8. Action Queue (Confirmed Working)

**Purpose:** Plan multiple steps ahead; worker executes **one action at a time**.

| Component | Role |
|-----------|------|
| `QueuedAction` | Types: Go Here, Take Order, Collect, Stock, Pack, Deliver, Pickup Box |
| `ProjectedState` | Simulates inventory + order after queued steps; validates enqueue |
| `ActionQueue` | Enqueue, run via `GameplayInput.execute_queued_action`, clear on failure |
| `ActionQueueBar` | Compact icon chips under HUD (no dark strip); tooltips with step labels |

**Behaviour:**

- Collect/stock/take order/pack/deliver validated against projected + real world (shelf stock, customer front of queue, etc.).
- Worker must finish move/pack before next queued step runs.
- Failed mid-run clears queue and shows alert.

---

## 9. UI (Confirmed Working)

| UI | Location | Behaviour |
|----|----------|-----------|
| **HUD** | Top bar | Coins (live economy), Day, clock, XP ring, reputation bar, avatar + **bag** button |
| **Inventory panel** | Dropdown from bag | 8 slots (4×2), product icons + counts; badge = total units |
| **Active order** | Top-right chip | Tap → panel with order lines + **Cancel order** |
| **Context menu** | Tap interactable | Styled buttons; quantity +/- for take/stock |
| **Action queue bar** | Below HUD | Queued step icons |
| **AlertMessages** | Bottom toast | Warnings (orange) / info (blue); ~3.4 s fade |
| **Shelf labels** | 3D above shelves | Product icon + `count/max` |
| **Speech bubbles** | 3D on customers | Order list / waiting icons |

Inventory is handled by the **HUD** bag dropdown (`hud.gd`); legacy `inventory_ui.gd` was removed.

---

## 10. Camera & Controls (Confirmed Working)

- Isometric rig: pitch −30°, yaw 45°, orthographic.
- Pan (drag), zoom (wheel/pinch), Home reset.
- Tap / click for all interactions (touch-friendly).

---

## 11. Scene & Script Map

```
scenes/main/main.tscn
├── Warehouse (warehouse.tscn)
│   ├── Grid floor, walls, decorations, traffic, pedestrians
│   ├── WarehouseShelves, PackingTable spawn, Queue area
│   ├── CustomerQueue, LoadingDock, ManagerSpawn, Navigation
├── IsoCameraRig
├── TouchInput
├── UI (CanvasLayer)
│   ├── HUD
│   ├── ActionQueueBar
│   ├── ActiveOrderUI
│   └── ContextMenu
└── GameplayInput
    └── ActionQueue

scripts/autoload/grid_service.gd     → GridService
scripts/ui/alert_messages.gd         → AlertMessages
scripts/input/                       → camera, touch, gameplay
scripts/worker/worker.gd
scripts/gameplay/                    → catalog, customer, queue, delivery, queue actions
scripts/warehouse/                   → building, shelves, dock, pathing helpers
scripts/pathfinding/pathfinding.gd
scripts/character_model_cleanup.gd
tools/strip_hand_aids_from_characters.py
scripts/test/order_flow_test.gd
```

---

## 12. Confirmed Working — Checklist

Use this as a smoke-test list in the editor:

- [ ] Game starts at main scene; manager visible in warehouse.
- [ ] Pan/zoom camera; Home resets view.
- [ ] Truck delivery plays (or wait); pick up dock boxes into inventory.
- [ ] Customers spawn and queue; front bubble → **Take order**.
- [ ] Active order UI shows required products.
- [ ] Stock shelves from inventory; shelf shows **N/6** boxes matching count.
- [ ] Take from shelf removes boxes visually as count drops.
- [ ] Packing table → **Pack the order** (progress bar); inventory becomes package.
- [ ] Customer → **Fulfill order**; customer leaves; queue advances.
- [ ] Queue multiple actions (e.g. collect → walk → pack); chips appear; run in order.
- [ ] Tap shelf/customer/table with no valid action → **toast warning**.
- [ ] Open bag inventory; tap packing table still works.
- [ ] Characters: no cyan hearing aids on wrists; no missing arm meshes.
- [ ] Road: 2 lanes + junction to dock (not stacked parallel roads).

---

## 13. Not Built Yet / Known Limits

| Area | Status |
|------|--------|
| Fulfillment workers | Hire + task UI exist; **fulfillment automation not implemented** (storage + cleaning only) |
| Reputation impact | Penalties apply; reputation does not yet affect traffic or revenue |
| Product COGS | Reorder uses flat logistics fee; per-unit catalog cost disabled |
| Win/lose / scoring | None |
| Hands/visual carry | Products shown in UI only, not in character hands |
| Action queue | No reorder/cancel individual steps (queue clears on failure) |
| Mobile layout | Touch input works; no dedicated phone HUD / stretch policy |
| Hearing aids | Some GLB variants may need re-run of strip script after Kenney updates |

**Implemented since earlier docs:** economy (rewards, payroll, dispatch fees), save/load v2, worker hire, online orders, day-end summary, garbage/reputation pressure, progression XP.

---

## 14. Related Docs

- `docs/project-overview.md` — earlier architecture overview (partially superseded by this file for shelf capacity, HUD, queue, alerts, roads).
- `docs/warehouse-game-concept.md` — long-term design vision.
- `docs/dev-plan.md` — phased development plan.
- `docs/ai-asset-generation.md` — UI icon pipeline.

---

## 15. Recent Fixes Summary (Why This Doc Exists)

These items were implemented or repaired in recent sessions and are reflected above:

1. **Shelf visuals** — Max 6; box count = real stock; take removes boxes.
2. **Pack order** — Queue validation no longer rejects valid packs after simulation.
3. **Packing table + inventory UI** — Clicks reach world while bag panel open.
4. **Action queue UI** — Small icon chips, no full-width dark bar.
5. **AlertMessages** — Toasts for empty interactions and queue failures.
6. **Road layout** — 2 E–W lanes + dock T-junction (removed erroneous multi-row “highway”).
7. **Characters** — Safe accessory stripping + GLB wrist-geometry strip; worker uses same Kenney path as customers.
8. **Inventory** — Removed old 20-unit cap; 4 product-type stacks remain.
9. **`VISUAL_SLOTS` parser error** — Replaced with `SHELF_ROWS` constant for Godot `const` rules.

---

_If you extend the game, update this file alongside `project-overview.md` or merge them when the older overview is fully retired._
