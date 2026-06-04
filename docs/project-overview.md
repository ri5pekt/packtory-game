# Packtory — Project Overview

_A snapshot of everything built so far: the world, the warehouse, and the
order‑fulfilment gameplay loop._

---

## 1. Concept

Packtory is an isometric warehouse / order‑fulfilment game. You play a single
**manager** character inside a small warehouse. Shoppers walk in off the street,
queue up, and place **orders** (a random set of products). You take an order, pick
the matching products off the shelves, **pack** them into a package at a packing
table, and **deliver** the package to the waiting customer, who then leaves.

The current build is a **vertical slice of the core loop** — one warehouse, three
products, and the full take → pick → pack → deliver cycle working end to end.

---

## 2. Tech & project setup

- **Engine:** Godot 4.6 (`.stable`), GL Compatibility renderer (D3D12 on Windows).
- **Main scene:** `res://scenes/main/main.tscn`.
- **Autoload:** `GridService` (`scripts/autoload/grid_service.gd`) — the single
  source of truth for the grid, cell types, blocked cells, and pathfinding.
- **Headless verification:** the project is routinely run/checked with the
  console Godot build (`--headless --quit-after N`, or `-s` SceneTree tools for
  screenshots/probes). Adding a new `class_name` requires an `--import` pass so it
  registers in the global script class cache.
- **AI-generated 2D assets:** UI icons via Replicate — see
  **[ai-asset-generation.md](./ai-asset-generation.md)**. Icons live in
  `assets/ui/icons/` and load through `IconRegistry`.

---

## 3. World & grid

Everything lives on a 1 m **cell grid** owned by `WarehouseGrid`:

- **Lot size:** `WAREHOUSE_SIZE` (12×12) + `GROUND_PADDING` (11) on every side →
  a 34×34 cell lot. The warehouse interior is cells **x 11–22, z 11–22**.
- **Coordinates:** `cell_to_world` / `world_to_cell`. Z increases toward the south
  (toward the camera / road). The iso camera looks **SE → NW**, so north & west
  walls are the far backdrop and south & east are the near/open sides.
- **Cell classification helpers:** warehouse / border (apron) / road / sidewalk /
  walkway / grass, plus `is_paved_cell`, `is_grass_cell`.
- **Entrance:** a 2 m door module on the south wall at columns 15–16; a walkway
  (x ≈ 16) runs south from the door across the yard to the road.

### Zones inside the warehouse
- **Work zone (north, z 12–15):** product shelves and the packing table.
- **Customer queue zone (south‑centre, z 17–21):** the queue lane, lined up with
  the door, flanked by decorative rails.

---

## 4. Environment (outside the building)

Built from three asset kits (see `memory/environment-asset-kits.md`):

- **Starter Kit City Builder** — 1 m, origin‑centred tiles used for the ground:
  `grass`, `grass-trees` / `grass-trees-tall`, `pavement`, `road-straight`. Lives
  in `blender/assets/starter_kit_city/` (a clean copy; the original ships as a
  nested Godot project that the importer skips).
- **KayKit City Builder Bits** — street props (bush, bench, streetlight, hydrant,
  trash, dumpster, water tower).
- **Kenney** — building kit (warehouse shell), mini‑market (shelves/fences),
  car kit (traffic), mini‑characters (manager + shoppers).

Relevant scripts:
- `grid_floor.gd` — single consolidated **ground tiler**. One MultiMesh per tile
  type. Plain grass is drawn as a clean **solid warm‑green** with smooth
  low‑frequency colour variation (no texture speckle); tree tiles are clustered
  via noise, sunk slightly so their own grass base hides under the lawn, and
  tinted warm to match. Also lays the Kenney interior floor.
- `grass_decorations.gd` — scatters the KayKit street furniture (streetlights
  along the road, etc.).
- `decorative road` is a single E–W road along the south, built from Starter Kit
  road tiles; `road_traffic.gd` / `road_car.gd` drive Kenney cars along it.
- `sidewalk_pedestrians.gd` / `sidewalk_pedestrian.gd` — decorative passers‑by on
  the sidewalks/walkway, walking in multiple directions.

---

## 5. The warehouse building

`warehouse_walls.gd` + `kenney_building_layout.gd` build the shell on the
building‑kit’s 2 m module:

- **Full perimeter** with corner columns.
- **Far walls (north/west):** full‑height 2.4 m, carrying a mix of **square and
  round windows** as a backdrop.
- **Near walls (south/east):** low, so the iso camera sees into the interior.
- **Door:** a doorway module on the south wall facing the road.
- Walls register their cells as blocked for pathfinding.

---

## 6. Camera & controls

`scripts/input/` — `camera_controller.gd`, `touch_input.gd`, `gameplay_input.gd`.

- **Camera:** orthographic isometric rig (`iso_camera_rig`), pitch −30°, yaw 45°.
  Default framing fits the warehouse (not the whole lot). Pan = drag, zoom =
  wheel/pinch, Home = reset.
- **Selection:** the manager is **auto‑selected** on start and shows a glowing
  **selection ring**. Tapping the manager (re)selects; tapping the floor with the
  manager selected offers **Go Here**.
- **Interaction model:** a raycast (physics **layer 1**, areas) hits the nearest
  interactable — `Worker`, `ProductShelf`, `Customer`, or `PackingTable` — and
  opens a contextual menu. Choosing an action walks the manager to the target and
  runs the action on arrival (via a `walk_to_world(target, on_arrive)` callback).

---

## 7. Gameplay systems

### 7.1 Manager (`scripts/worker/worker.gd`, `class_name Worker`)
- Grid pathfinding movement (`walk_to_world(target, on_arrive)`), `face_world`.
- **Inventory:** holds up to `MAX_INVENTORY` (4) **units**, stored as stacks
  (`get_inventory_stacks`, `get_total_units`); `add_product` / `remove_product` /
  `has_product`. Emits `inventory_changed`.
- **Package:** after packing, the manager carries a single **package** item
  (`has_package`); it occupies inventory and cannot be put back on a shelf.
- **Packing:** `start_packing` runs a timed progress bar (billboarded above the
  manager) then a completion callback; `consume_order_and_pack` swaps the held
  products for a package, `restore_packed_order` reverts on failure.
- **Selection ring** + **packing progress bar** are built in code.

### 7.2 Products (`scripts/gameplay/product_catalog.gd`, `ProductCatalog`)
Static catalog of products (model, scale, UI colour, shelf layout):
- `book`, `hair_dryer`, `mouse` — the starting orderable products (Household
  Props 001 models).
- `package` — the packed‑order box (Empty Box.glb), flagged `is_package`.
- Helpers: `random_order` (≤ `ORDER_MAX_UNITS` = 4 units total),
  `inventory_fulfills_order`, `order_lines`, `inventory_label`, `orders_match`,
  colour/name lookups.

### 7.3 Shelves (`scripts/warehouse/product_shelf.gd`, `ProductShelf`)
- Uses the Kenney mini‑market **`shelf-boxes` gondola, emptied** — the kit bakes
  its cartons as child meshes, which are stripped so the shelf starts empty; our
  product models are laid out on the two shelf boards (front face).
- Per shelf: one `product_id`, `count` (start 10, `MAX_STOCK`), `take_one` /
  `add_one` rebuild the visible products.
- An **Area3D** click target (layer 1) and a billboard **Label3D** debug counter
  (`Book 10/10`) above each shelf.
- Three shelves spawned by `warehouse_shelves.gd` (book / hair dryer / mouse) in
  the north work zone; their cells are registered as blocked.

### 7.4 Packing table (`scripts/warehouse/packing_table.gd`, `PackingTable`)
- A Household Props `Table` in the north work zone (spawned by
  `packing_table_spawn.gd`), 3‑cell footprint blocked for pathfinding.
- Click target + approach/face helpers. The manager packs here when carrying every
  product the active order needs.

### 7.5 Customers & queue
`scripts/gameplay/customer.gd` (`Customer`) + `customer_queue.gd`
(`CustomerQueue`, in the warehouse scene, group `customer_queue`) +
`queue_area_layout.gd` (`QueueAreaLayout`) + `queue_area_spawn.gd` (rails).

- **Spawning:** `CustomerQueue` spawns shoppers on a timer up to `MAX_QUEUE` (4).
- **Walk‑in:** each customer follows a waypoint path (walkway → door → lane), with
  **grid pathfinding per segment**, separation from other customers
  (`CUSTOMER_BODY_LAYER` = 4), and stuck‑repath recovery. They react to
  `navigation_changed` (re‑path when the grid changes).
- **Queue layout:** a single‑file lane in **cell column 16** (lined up with the
  door). The **front slot is at the north end** (toward the work zone, where the
  manager serves). Shoppers fill **front → back toward the door**, so entering
  never crosses an occupied slot. Decorative **rails** sit one cell out (cells 14
  & 18), leaving a free cell on each side (15 & 17).
- **States:** `ARRIVING → PENDING → TAKEN → WAITING_PICKUP → DEPARTING`
  (+`REPOSITIONING` when the line advances).
- **Note bubble:** the front customer shows a clickable procedural speech‑bubble
  note icon while `PENDING` and nothing else is active.
- **Departure:** after delivery the served customer steps into the **east side
  lane** (cell 17) to slip past the queue, then walks out the door, and the queue
  advances.

### 7.6 Orders & the loop
The `CustomerQueue` owns the single **active order** and emits
`active_order_changed`. The full loop, driven by `gameplay_input.gd`:

1. **Take order** — click the front customer’s bubble → manager walks over →
   `take_order` (order becomes active; bubble hidden).
2. **Pick** — click a shelf → **Take product** (with a **quantity +/- picker**, up
   to remaining carry space) → manager walks over and collects.
3. **Pack** — once the manager holds everything the order needs, click the packing
   table → **Pack the order** → timed packing → products become a **package**;
   the customer moves to `WAITING_PICKUP`.
4. **Deliver** — click the customer → **Fulfill order** → manager walks over and
   hands off the package; the customer departs.
- **Cancel:** the active‑order modal can cancel a taken order, returning it to the
  customer (their bubble reappears).

### 7.7 UI (`scripts/ui/`)
- **Inventory bar** (`inventory_ui.gd`) — 4 slots, bottom‑centre, bound to the
  manager’s `inventory_changed`; shows stacked products (and a 📦 for a package).
- **Active‑order icon + modal** (`active_order_ui.gd`) — top‑right icon when an
  order is active; opens a centred modal (dim backdrop) listing products to fulfil,
  with **Cancel Order** / **Close**.
- **Context menu** (`context_menu.gd`) — floating action menu; supports plain
  buttons and an optional **quantity picker** row (used by “Take product”). Emits
  `action_selected(id, quantity)`.

---

## 8. Pathfinding & obstacles

- `scripts/pathfinding/pathfinding.gd` (`Pathfinding`) — `AStarGrid2D` over the
  warehouse cells with diagonal movement and string‑pulling for smooth paths.
  `path_as_world_array`, `is_segment_walkable`, nearest‑walkable goal resolution.
- **Blocked cells** are tracked in `GridService` (`block_cell` / `unblock_cell`,
  `register_blocked_cell`) and mirrored into the A\* grid; changes emit
  `navigation_changed` so movers re‑path.
- `warehouse_obstacle.gd` (`WarehouseObstacle`) — a reusable component that
  occupies/releases grid cells (used by fences/props), `static_collision.gd` adds
  physics boxes for static obstacles.

---

## 9. Code & scene map

```
scenes/
  main/main.tscn            Root: warehouse + camera + input + UI
  warehouse/warehouse.tscn  Building, ground, shelves, queue, packing, spawns
  worker/worker.tscn        Manager character
  camera/iso_camera_rig.tscn
  ui/context_menu.tscn

scripts/
  autoload/grid_service.gd          WarehouseGrid (grid, cells, blocked, nav signal)
  pathfinding/pathfinding.gd        AStarGrid2D wrapper
  input/   camera_controller, touch_input, gameplay_input
  worker/  worker.gd                Manager: movement, inventory, packing
  gameplay/
    product_catalog.gd              Products, orders, helpers
    customer.gd / customer_queue.gd Shoppers + queue + active order
  warehouse/
    grid_floor, grass_decorations            Ground + props
    warehouse_walls, kenney_building_layout  Building shell
    warehouse_shelves, product_shelf         Shelves
    packing_table, packing_table_spawn       Packing
    queue_area_layout, queue_area_spawn      Queue lane + rails
    warehouse_obstacle, static_collision     Obstacles
    warehouse_navigation, manager_spawn      Setup
    road_traffic, road_car, sidewalk_*       Outdoor life
  ui/  inventory_ui, active_order_ui, context_menu, icon_registry
```

---

## 10. Status & known rough edges

**Working:** the complete take → pick → pack → deliver loop, customer queue with
spawning/lineup/exit, inventory + order UI, shelves with stock & debug counts,
quantity picking, grid pathfinding with dynamic obstacles, the full environment.

**Rough edges / not yet built:**
- Single warehouse, three products, one manager — no economy (money, restocking
  deliveries, upgrades) yet.
- No save/load, no win/lose or scoring.
- Customer exit can look slightly busy when the line advances as someone leaves
  (mitigated by the dedicated east exit lane).
- The held product is only shown in the screen inventory, not modelled in the
  manager’s hands.
- Balancing (spawn rates, stock, packing time) is placeholder.

---

_Last updated to reflect: door‑aligned queue lane with side exit, north work zone
(shelves + packing table), and the full order‑fulfilment loop._
