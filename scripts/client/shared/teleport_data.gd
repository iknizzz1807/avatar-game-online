extends Node

# ═════════════════════════════════════════════════════════════════════════════
# TELEPORT DATA — Autoload Singleton
#
# A lightweight "postbox" for passing the desired spawn position across
# scene transitions.  TeleportZone writes to it; the new scene's Player
# (or Game controller) reads it in _ready().
#
# Add to Project → Project Settings → Autoload as "TeleportData".
# ═════════════════════════════════════════════════════════════════════════════

## Set by TeleportZone before the scene changes.
## Read and consumed by the new scene to position the local player.
## Vector2.ZERO means "use the map's default spawn".
var spawn_position: Vector2 = Vector2.ZERO
