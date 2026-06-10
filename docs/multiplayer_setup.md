# Multiplayer — How to Run

## 1. Start the Go REST server
```powershell
cd server
go run .
# Listens on :8080
```

## 2. Start the Godot Dedicated Server
In the Godot editor, go to **Debug → Run in editor with custom arguments** and set:
```
--server --headless
```

Or run from the command line (after exporting a dedicated-server build):
```bash
./avatar-game-online.x86_64 --headless --server
# Listens on UDP :7777
```

To run directly from the editor during development, you can also just **play the game** — `game_server.gd` checks for `--server` in args, so in the editor it won't start the server. Run two separate editor instances or use the export method above.

> **Tip for local dev**: Use `--server` as a custom editor argument for a second Godot editor window (Editor → Project → Project Settings → Debug → Customise Run Arguments).

## 3. Connect clients
Run the game normally. The auth screen logs in via Go REST, then calls `MultiplayerManager.connect_to_server()` which connects to `127.0.0.1:7777` (the Godot dedicated server).

## Architecture Summary

```
Client (Godot)
  │
  ├──► HTTP REST ─────► Go Server :8080    (auth, farm, inventory, shop)
  │
  └──► ENet UDP  ─────► Godot Server :7777 (positions, presence, real-time)
                              │
                              └─── broadcasts to all peers on same map
```

## Files Added / Modified

### New
| File | Purpose |
|---|---|
| `scripts/server/game_server.gd` | Dedicated server: ENet listen, player registry, join/leave RPCs |
| `scenes/server.tscn` | Server scene (autoloaded as `ServerScene`) |
| `scripts/client/shared/multiplayer_manager.gd` | Client autoload: connect, register, signals |
| `scripts/client/shared/player_registry.gd` | Scene node: spawns/despawns RemotePlayer nodes |
| `scripts/client/prefabs/player/remote_player.gd` | Remote player: lerp position, apply synced animation |
| `prefabs/characters/remote_player.tscn` | Remote player scene (Sprite2D + AnimTree + name label) |
| `scripts/client/prefabs/ui/auth.gd` | Auth screen: REST login → multiplayer connect → game scene |

### Modified
| File | Change |
|---|---|
| `prefabs/characters/player.tscn` | Added `MultiplayerSynchronizer` syncing 4 vars |
| `scripts/client/prefabs/player/player.gd` | Exposed sync vars; guarded state machine behind `is_multiplayer_authority()` |
| `scripts/client/prefabs/player/player_normal_state.gd` | Writes sync vars after each physics tick |
| `scenes/game.tscn` | Added `PlayerRegistry` node |
| `scenes/auth.tscn` | Attached `auth.gd` script + `HTTPRequest` node |
| `project.godot` | Registered `MultiplayerManager` and `ServerScene` autoloads |
