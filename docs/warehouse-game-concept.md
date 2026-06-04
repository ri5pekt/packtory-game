# Warehouse (working title) — Concept Doc & MVP Build Order

*A mobile-first order-fulfillment game. Android first, iOS later. Built in real-time 3D so the same project exports to web (for fast prototyping) and Android from one codebase.*

---

## The pitch

You run a warehouse. Customers line up to collect orders and others need shipping out. You collect items off shelves, pack them, and get them out the door — first by hand, then by hiring a team and turning into the manager who keeps the whole floor running. It's a real-time fulfillment game (the *Good Pizza, Great Pizza* / *Overcooked* line of tactile, timer-pressured service) fused with a layout-optimization tycoon (the Satisfactory factory-brain).

**The hook to protect above everything:** the deep skill isn't packing — it's *where you put the shelves and how you route through the warehouse*. Your pathing per order is the moment-to-moment skill; your floor plan is the meta-skill. Scale should keep breaking your optimal layout so you keep rebuilding it. That's what stays fun at hour 40.

---

## Core loop — the day

A day runs roughly 8am–22pm in game time (target a real session of a few minutes).

- **Morning:** you receive the day's orders. Some are walk-ins (customers come to the warehouse), some are dispatch (shipped by vehicle).
- **Open hours:** serve the walk-in line under patience pressure. When the line clears, prep dispatch orders — these carry deadlines, so there's tension between the customer in front of you and the truck you need to load.
- **End of day:** revenue in, expenses out (wages, restocking, fuel, rent), reinvest. Persistent progression, lean cozy — a bad day means less money, not game-over.

---

## Controls & navigation

- **Tap-to-interact on the floor.** Tap a shelf → the character walks there and grabs the needed item (one tap). Tap a sequence of targets to queue a whole route, executed in order. The queue *order is the walking path*, so reordering the queue is re-routing — a live little traveling-salesman puzzle. Drag-to-reorder / "do next" lets you shove an impatient customer's order to the front.
- **Camera.** Drag anywhere on empty ground to pan; pinch to zoom. Zooming in is encouraged — the iso art is meant to be admired up close.
- **Tap vs drag.** A short tap = queue an action; a drag = pan the camera. Godot distinguishes these natively, so the two never fight.
- **One input scheme** (tap / drag / pinch) works identically on web (mouse + wheel) and Android — no second control scheme to build.

---

## Interaction model — picking & packing

The queue model handles the **warehouse floor**; the **pack desk** gets its own screen. Two tools for two problems, no conflict.

**Picking (floor, tap-queue):**

- Tap a shelf → grab the item into a single shared inventory. No order is assigned at the shelf — you're just *gathering*.
- Every tap is either one obvious option (grab) or a small 1–2 option choice (e.g. a 2-SKU shelf: which product). Never a sprawling menu — that's friction, not depth.
- **Carry capacity** (starts ~2, upgradeable via cart / forklift) caps the inventory. When full, the character returns to the pack desk to deposit. Capacity turns a route into a series of "loads," and clustering nearby shelves into each load is the skill. Match early order sizes to capacity so trips feel like an optimization, never a slog.

**Packing (dedicated screen):**

- Tap the pack desk → "approach desk" is queued; on arrival a button appears to **open the packing interface**. (Prototype both this and a pure-queue version to see which feels better — the real world will tell us.)
- In the packing screen you sort the gathered haul **into orders** (these items → order A, those → order B), pick box sizes, and confirm. **Order assignment happens here, not at the shelf** — this keeps floor taps simple and moves the real planning to where you have time to think and can see your whole inventory at once.
- **Desk slots** (starts ~5, upgradeable) limit how many items you can pre-stage on the desk. More slots = stage your best-sellers in advance = pack incoming orders faster. This makes prep *predictive*: read the incoming queue and pre-position stock. The desk becomes a bottleneck you manage, just like shelves and workers.

---

## Workers & the automation arc

The fantasy bends toward **worker → manager**. Early game you do everything by hand (tactile, frantic). As you scale you hire pickers and packers, add reception tables and packing desks, and upgrade staff speed/efficiency. Your job shifts from picking individual orders to running the floor.

**Engagement model:** the automated baseline *works* but progresses slowly. Playing actively is never forced — it's *rewarded*. Go hands-on for a speed bonus, or go brain-on and optimize layout, assignments, and the fleet. Both are "playing."

**v1 simplification:** every worker runs the same hardcoded loop — gather → pack desk → hand off → repeat. No per-worker queue editing, so no queue UI needed until much later.

**Sci-fi toys** slot in here naturally: a drone isn't "a bigger truck," it's your *first automated picker* — it removes a job you used to do by hand.

---

## The exception system — the real manager game

This is the answer to "what does the player do once workers handle the baseline." **You handle the exceptions the workers can't.** A worker hits a problem, stops, and shows an alert icon over its head (Sims-style). You tap it, read the issue, and decide.

Example: product out of stock → **wait** (worker idles, order delays, patience drains) / **cancel** and move to the next order / **substitute** a similar product (partial happiness, partial refund) / **emergency restock** (costs money + time). Other exceptions: no box the right size, customer dispute, delivery stuck in traffic, two workers blocked in an aisle, payment declined, an impatient VIP.

Two rules that make or break it:

1. **Every choice must be a real dilemma** — context-dependent (how patient is this customer, how big is the order, is a restock already inbound). If the answer is always "cancel," it degrades into mindless tap-to-dismiss.
2. **Reducing interrupts is a progression reward.** Better inventory tracking auto-prevents the out-of-stock pings; trained workers self-resolve minor snags; a bigger box buffer kills packaging alerts. You spend money to *buy back your own attention* — the core tycoon dopamine. It also loops into supply chain: good restock planning is literally what stops these alerts from firing.

---

## Inventory & products

**Shelves:** a shelf occupies **one floor cell but holds N level-slots, one SKU per slot.** Vertical storage = more product variety packed into scarce floor space; "add a level / buy a taller shelf" is a real upgrade. Two tunable dimensions for later: *breadth* (total slots across all shelves) and *depth* (units per slot before restock). Levels are pure capacity in v1 — no pick-speed penalty (a small top-level pick-time cost is an optional later dial).

**New products (push *or* pull, sequenced):** don't force them. Use **unmet demand** — customers ask for things you don't stock, you lose the sale, and the end-of-day screen shows "you turned away N orders for Product X." At level-ups, showcase newly available products. Stocking them stays a player choice with cost/benefit; mid-day restock is allowed if you have the cash.

**Packaging:** boxes are a stocked resource. Keep stock visible and one-tap reorderable so running out is a *planning* failure, not a surprise. Box-size selection (too big wastes money, too small won't fit) is a micro-decision to unlock later, auto-suggested early.

**Restock lead time** (mid-game depth): orders arrive next morning / in N hours, so you must *anticipate* demand. Pair with bulk discounts and minimum order sizes. Keep it instant early for simplicity.

---

## Delivery & dispatch

Two channels with two different feels: walk-ins are real-time pressure; dispatch is a batch/routing puzzle you prep when the line clears, with deadlines.

**Vehicles:** bike → van → truck → bigger truck → drones. The economics are a utilization gamble — e.g. a 50-order truck only beats two 10-order trucks if you actually fill it, because **you pay fuel as a fixed cost whether it's full or empty.** Flexibility vs efficiency, which is authentic to real freight.

---

## World & setting

A large field. The warehouse is the playable space, surrounded by dressing — garden, street, people passing by — to sell the place as a real location and make expansion feel earned. The surroundings are **background only, non-interactive**, so they add atmosphere without cluttering the core puzzle. The big field also means the camera pans/zooms over a space larger than one screen.

---

## Visual & tech

**Look:** real-time 3D through a fixed orthographic camera at an isometric angle — low-poly, flat-shaded, baked-soft-light style (matching the reference). Optional 90° snap-rotation later; no free-flying camera needed.

**Engine: Godot 4** (the 4.6 line is current as of 2026), with **GDScript**. Full built-in editor (scene designer, script editor, play button) like Unity, but lighter and faster to launch. GDScript is interpreted, so iteration is *instant* — save and play, no compile wait. (Unity is the main alternative — bigger ecosystem and asset store, very common for this genre, e.g. Eatventure — but heavier, licensed, and clunkier on web. Godot wins for this simple cross-platform 2.5D game.)

**3D workflow:** Scenes are trees of nodes (a `Node3D` root with children for meshes, lights, camera), saved as `.tscn`. Import models as **glTF 2.0 (`.glb`)** from Blender — skeletal rigging and animations come in natively; drop the `.glb` in, assign it to a mesh node, done. Use **basic `.glb` assets from Phase 1** (floor, shelf, worker) — real low-poly visuals from the start, not primitive placeholders. Models render with flat-shading + baked AO for the cohesive look (custom shader deferred to polish pass).

**Movement & input:** Grid pathfinding via **`AStarGrid2D`** (logic in 2D cells, mapped to 3D world positions). Tap detection uses a camera raycast only — no rigid-body physics engine. Do not use nav meshes; the routing puzzle is defined in cells.

**Worker architecture:** From Phase 2, the worker **executes an ordered action list** (walk, grab, deposit). A single tap enqueues one action (list length 1). Phase 7's multi-tap routing feeds longer lists into the same executor — never build a single-target mover that gets rewritten later.

### The cross-platform 3D detail — the load-bearing decision

Godot 4 has three renderers, and they are *not* equally portable:

- **Forward+** — desktop/console only (Vulkan/Direct3D 12). No web path. Not relevant here.
- **Mobile** — the intended Android/iOS renderer, tuned for tile-based mobile GPUs (Vulkan). Does *not* run on the web in any production-ready way.
- **Compatibility** — OpenGL-based: WebGL 2 on the web, OpenGL ES 3 on Android, OpenGL on desktop. It is the **only** renderer Godot can export to the web, and it also runs on Android and desktop.

**The move: use the Compatibility renderer as the single shared target across web + Android.** Why:

1. It's the only renderer that runs on the web at all — Forward+/Mobile have no WebGL path, and WebGPU (which would unlock them) isn't implemented yet.
2. The art is low-poly, flat-shaded, baked-light — it needs *none* of the advanced lighting that Mobile/Forward+ add. Compatibility is more than enough for this style.
3. One renderer = one visual target = one shader code path. Shaders do **not** port between Compatibility and the Forward+/Mobile family (separate code path), so running Mobile-on-Android + Compatibility-on-web would mean maintaining two looks for zero benefit at this fidelity.

(If a future, graphically heavier project ever needs it, you'd switch Android to the Mobile renderer for richer lighting/perf — but that's not this game.)

### Web export details & gotchas

- **What it compiles to:** WebAssembly (WASM) + JavaScript, rendering to a **WebGL canvas** in the browser. No plugins, runs in any modern browser.
- **Use GDScript, not C#.** Godot 4 cannot export C# projects to the web at all; GDScript exports cleanly. Choosing C# would cost you the browser-prototype half of the plan.
- **Export the web build single-threaded** (default and recommended since Godot 4.3). Multi-threaded web builds require SharedArrayBuffer, which forces cross-origin isolation headers (COOP/COEP) and breaks third-party embeds — a hosting headache. Single-threaded sidesteps all of it and runs cleanly on itch.io, GitHub Pages, Netlify, etc. You won't miss threads at prototype scale.

Matching the *baked* look in real-time takes a little flat-shading + ambient-occlusion setup, but it's well-trodden in the Compatibility renderer.

---

## Project structure

Each scene is a reusable `.tscn` node tree. Full phased build order and exit criteria live in [dev-plan.md](./dev-plan.md).

### Suggested folder layout

```
packtory/
├── docs/
│   ├── warehouse-game-concept.md          # design bible (this file)
│   └── dev-plan.md                        # phases, gates, workflow
│
├── scenes/
│   ├── main/
│   │   └── main.tscn                      # root orchestrator, scene switching
│   │
│   ├── warehouse/
│   │   ├── warehouse.tscn                 # iso grid, floor, camera, object layer
│   │   ├── shelf.tscn                     # instanced shelf unit
│   │   ├── pack_desk.tscn                 # floor trigger → packing UI
│   │   ├── worker.tscn                    # avatar / hired worker
│   │   └── customer.tscn                  # queue line entity
│   │
│   ├── ui/
│   │   ├── hud.tscn                       # money, timer, order list (CanvasLayer)
│   │   ├── packing_screen.tscn            # sort haul into orders
│   │   ├── end_of_day_screen.tscn         # revenue − expenses
│   │   └── exception_popup.tscn           # wait / cancel / substitute (step 8)
│   │
│   └── camera/
│       └── iso_camera_rig.tscn            # ortho cam + pan/zoom input
│
├── scripts/                               # folders in Phase 0; .gd files added per phase (see dev-plan)
│   ├── autoload/
│   ├── warehouse/
│   ├── actors/
│   ├── systems/
│   ├── input/
│   └── ui/
│
├── resources/
│   ├── data/
│   │   ├── products/                      # ProductData .tres (SKU, name, mesh ref)
│   │   ├── orders/                        # OrderTemplate .tres
│   │   └── upgrades/                      # later: cart, desk slots, shelf levels
│   │
│   ├── configs/
│   │   ├── game_balance.tres              # carry cap, patience rates, day length
│   │   └── warehouse_default.tres         # starting grid size, shelf layout seed
│   │
│   └── themes/
│       └── ui_theme.tres
│
├── assets/
│   ├── models/                            # basic .glb from Phase 1 (floor, shelf, worker, desk)
│   ├── textures/
│   └── audio/
│
├── shaders/                               # post art pass only (after step 7 gate)
│
└── export/
    ├── export_presets.cfg                 # web (single-threaded), Android
    └── web/                               # itch.io / GitHub Pages output (gitignored)
```

### Design principles

1. **Scenes = things in the world; scripts/systems = rules** — keeps `main.tscn` thin.
2. **Grid is data, not mesh** — `grid_service` + `grid_floor` own dimensions and cell occupancy from step 1.
3. **Worker is a queue-consumer from Phase 2** — ordered action list in `worker.gd`; Phase 7's `action_queue.gd` only builds longer lists.
4. **Resources for tunables** — carry capacity, patience, day length live in `.tres` so balance can iterate without code changes.
5. **Autoloads stay minimal** — add only when a phase needs them; avoid a "god autoload" that knows everything.
6. **event_bus for cross-cutting signals only** — order fulfilled, day ended; not the default wiring for local flow.
7. **Scripts when needed** — create `.gd` files per phase; empty stubs for systems weeks away become a graveyard.
8. **Validate touch on a real phone from Phase 1** — editor mouse does not catch multitouch or gesture clashes.
9. **Basic assets from Phase 1** — minimal `.glb` meshes early; polish and expand after the step 7 gate.

### Scene build order

**Start with:**

- **Main** — root orchestrator: game state, day cycle, money.
- **Warehouse** — the iso grid, floor, and camera (pan/zoom). The playable space.

For Phase 1 you only need **Main + Warehouse + iso_camera_rig**. Shelf, worker, and pack desk scenes arrive with their gameplay phases. **HUD** waits until Phase 5.

**Warehouse extension (a core progression mechanic):** build the floor as a **data-driven grid** from the start — grid dimensions as a variable, tiles generated from that, objects instanced onto cells. Then "expand warehouse" is just growing the grid and rendering more cells, which become new placement space. Never hardcode the warehouse as one fixed static mesh, or expansion becomes a rewrite.

---

## MVP build order — the fun-test slice

Build in the isometric pipeline from day one with **basic `.glb` assets** (floor, shelf, worker) — real low-poly visuals from the start, refined after the core loop proves fun. Build strictly in this order; each step is a gate.

1. **Iso scene + camera.** Grid floor from tile assets, shelf/worker meshes as dressing, fixed orthographic iso camera. Get **drag-to-pan + pinch-zoom** working first. **Export web and test on a real phone the same day** pan/zoom exist.
2. **Tap-to-move.** One avatar with action-list executor; tap → raycast → enqueue walk action (list length 1) → **`AStarGrid2D` path** → character walks. Short tap = move, drag = pan. Re-test on phone.
3. **Picking with capacity.** Tap shelf → enqueue grab; when full, append return + deposit to the same action list. *Test the routing feel: does clever tap-order reward you?*
4. **Packing screen.** Tap pack desk → approach → button opens the packing interface → sort the haul into orders, confirm, hand off. *Test: is sorting satisfying or tedious?*
5. **A line of customers** with draining patience and money paid per fulfilled order.
6. **The day cycle** — a timer for open hours, then an end-of-day money screen (revenue − expenses).
7. **Tap-to-queue routes.** `action_queue.gd` builds multi-tap routes into the worker's existing action-list executor — no movement rewrite. *This is the key fun test: does routing-as-skill feel good?*
8. **First worker + first exception.** One hired worker on the fixed loop, plus the out-of-stock alert with a wait / cancel choice.

**The kill-or-continue gate:** after steps 3–7, is the gather → pack → serve loop satisfying, and does tap-to-queue routing feel good? If yes, build on. If no, fix the core *before* adding anything below.

**Explicitly post-MVP** (do not build until the core is proven): dispatch & vehicles, drones, the full automation/hiring tree, the new-product/unmet-demand system, restock lead times, box-size selection, desk-slot pre-staging upgrades, the environment/setting dressing, the layout-optimization economy.
