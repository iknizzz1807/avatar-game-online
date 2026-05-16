# GDScript Code Style & State Machine Architecture
# avatar-game-online

---

## 1. Naming Conventions

### Variables
- All variables use **camelCase**.
- **No `_` prefix** on any variable.

```gdscript
# ✅ Correct
var player: Player;
var wasOnFloor: bool = false;
var coyoteTimer: float = 0.0;
var jumpBuffer: float = 0.0;

# ❌ Wrong
var _player: Player
var _coyoteTimer: float
var was_on_floor: bool
```

### Functions
- Public functions → **snake_case**
- Private / internal helper functions → **snake_case with `_` prefix**

```gdscript
# ✅ Correct — public lifecycle hooks
func ready_state() -> void: ...
func begin_state() -> void: ...
func fixed_update(delta: float) -> void: ...

# ✅ Correct — private helpers
func _handle_movement(delta: float) -> void: ...
func _apply_gravity(delta: float) -> void: ...

# ❌ Wrong
func HandleMovement() -> void: ...
func handleMovement() -> void: ...
```

### @export Constants (designer-facing tunable properties)
- Always **ALL_CAPS** — signals "treat as a read-only constant; adjust only via the Inspector or scene overrides."
- Grouped in the Inspector with `@export_group(...)`.

```gdscript
@export_group("Movement")
@export var MAX_SPEED: float = 200.0;
@export var ACCELERATION: float = 1200.0;
@export var DECELERATION: float = 1600.0;
```

### Local variables
- Always **explicitly typed** — never use `:=` (type inference). Write the type out explicitly.

```gdscript
# ✅ Correct
var inputDir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down");
var targetVelocity: Vector2 = inputDir.normalized() * player.MAX_SPEED;

# ❌ Wrong
var inputDir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
```

### Semicolons
- **Every statement ends with `;`** — including variable declarations, assignments, function calls, and `pass`.

```gdscript
# ✅ Correct
var player: Player;
player = parent as Player;
player.move_and_slide();
pass;

# ❌ Wrong
var player: Player
player = parent as Player
player.move_and_slide()
```

> Note: `func`, `if`, `elif`, `else`, `for`, `while`, `match` lines (the header lines ending in `:`) do **not** get a semicolon — only the statements inside their bodies do.

---

## 2. File & Class Naming

| What | File name | class_name |
|---|---|---|
| Entity prefab | `{entity}.gd` | `{Entity}` |
| State for an entity | `{entity}_{state_name}_state.gd` | `{Entity}{StateName}State` |

Examples:
- `player.gd` → `class_name Player`
- `player_normal_state.gd` → `class_name PlayerNormalState`
- `enemy_chase_state.gd` → `class_name EnemyChaseState`

State files live **in the same directory as their parent entity** — not in a separate `states/` subfolder.

```
scripts/client/prefabs/
├── player/
│   ├── player.gd
│   └── player_normal_state.gd    ← same folder as player.gd
├── enemy/
│   ├── enemy.gd
│   └── enemy_chase_state.gd      ← same folder as enemy.gd
```

---

## 3. StateMachine Architecture

### Core files (shared, do not modify per-entity)
```
scripts/client/shared/
├── state_machine.gd    # class_name StateMachine
├── state_node.gd       # @abstract class_name StateNode extends Node
└── helper.gd           # class_name Helper (static utilities)
```

### StateMachine API
```gdscript
# Construction — pass the parent Node that owns all states
var stateMachine: StateMachine = StateMachine.new(self);

# Optional: pretty-print state enum keys in logs
stateMachine.state_to_state_name = func(s: int) -> String: return State.keys()[s];

# Register a state node
stateMachine.add_states(State.NORMAL, normalState);

# Set the starting state (calls begin_state immediately)
stateMachine.set_initial_state(State.NORMAL);

# Transition to a new state (deferred; optional data dict passed as read-only)
stateMachine.change_state(State.JUMP, { "fromGround": true });

# Drive from _process / _physics_process
stateMachine.update(delta);
stateMachine.physics_update(delta);
```

### StateNode lifecycle hooks
```gdscript
func ready_state() -> void:             # Called once when registered (use instead of _ready)
func begin_state() -> void:             # Called every time this state becomes active
func end_state() -> void:               # Called every time this state is left
func update(delta: float) -> void:      # Driven by _process
func fixed_update(delta: float) -> void # Driven by _physics_process
```

---

## 4. Scene-Node State Wiring

States are **real Nodes in the scene tree**, not created with `new()`.

### Scene hierarchy convention
```
Player (CharacterBody2D)
└── States (Node)
    └── Normal (PlayerNormalState)   ← script: player_normal_state.gd
```

The node name under `States/` is the **PascalCase** version of the enum key:
- `State.NORMAL` → `$States/Normal`
- `State.JUMP` → `$States/Jump`
- `State.ATTACK` → `$States/Attack`

### Wiring in the entity script
```gdscript
# ✅ Correct — fetched from scene tree
@onready var normalState: PlayerNormalState = $States/Normal;

# ❌ Wrong — do NOT instantiate manually
@onready var normalState: PlayerNormalState = PlayerNormalState.new()
```

---

## 5. Entity Script Template

```gdscript
extends CharacterBody2D
class_name Player

# ════ TUNABLE CONSTANTS ═══════════════════════════════════════════════════════
# Adjust via Inspector only — treat as read-only at runtime
@export_group("Movement")
@export var MAX_SPEED: float = 200.0;
@export var ACCELERATION: float = 1200.0;
@export var DECELERATION: float = 1600.0;
# ... more @export vars in ALL_CAPS

# ════ STATE MACHINE ═══════════════════════════════════════════════════════════
enum State {
    NORMAL,
    # add more states here
}

var stateMachine: StateMachine;

@onready var normalState: PlayerNormalState = $States/Normal;

func _ready() -> void:
    stateMachine = StateMachine.new(self);
    stateMachine.state_to_state_name = func(s: int) -> String: return State.keys()[s];
    stateMachine.add_states(State.NORMAL, normalState);
    stateMachine.set_initial_state(State.NORMAL);

func _process(delta: float) -> void:
    stateMachine.update(delta);

func _physics_process(delta: float) -> void:
    stateMachine.physics_update(delta);
```

---

## 6. State Script Template

```gdscript
extends StateNode
class_name PlayerNormalState

# Typed reference to parent — cast in ready_state()
var player: Player;

# State variables (camelCase, no _ prefix)
var someTimer: float = 0.0;

func ready_state() -> void:
    player = parent as Player;

func begin_state() -> void:
    someTimer = 0.0;

func end_state() -> void:
    pass;

func update(_delta: float) -> void:
    pass;

func fixed_update(delta: float) -> void:
    # Physics logic — always call move_and_slide() at the end
    _handle_movement(delta);
    player.move_and_slide();

# ─── Private helpers ──────────────────────────────────────────────────────────
func _handle_movement(delta: float) -> void:
    var inputDir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down");
    if inputDir != Vector2.ZERO:
        var targetVelocity: Vector2 = inputDir.normalized() * player.MAX_SPEED;
        player.velocity = player.velocity.move_toward(targetVelocity, player.ACCELERATION * delta);
    else:
        player.velocity = player.velocity.move_toward(Vector2.ZERO, player.DECELERATION * delta);
```

---

## 7. Quick Reference

| Rule | ✅ Do | ❌ Don't |
|---|---|---|
| Variables | `camelCase` | `snake_case`, `_prefix` |
| Local var types | `var x: float = ...;` | `var x := ...` |
| Semicolons | Every statement ends with `;` | Omitting `;` |
| Public functions | `snake_case()` | `camelCase()`, `PascalCase()` |
| Private functions | `_snake_case()` | `_camelCase()` |
| Export constants | `ALL_CAPS` | anything else |
| State file location | same dir as entity | separate `states/` folder |
| File name | `player_normal_state.gd` | `NormalState.gd`, `normal_state.gd` |
| Class name | `PlayerNormalState` | `NormalState`, `playerNormalState` |
| State wiring | `$States/Normal` via `@onready` | `NormalState.new()` |
