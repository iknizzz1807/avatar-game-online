@abstract
extends Node
class_name StateNode

var parent : Node;
var stateMachine: StateMachine;

# Getter Setter for parent Node
# As StateNode is just there for organization
var global_position : Vector2:
	get:
		return parent.global_position;
	set(value):
		parent.global_position = value;
var global_rotation : float:
	get:
		return parent.global_rotation;
	set(value):
		parent.global_rotation = value;

var position : Vector2:
	get:
		return parent.position;
	set(value):
		parent.position = value;
var rotation : float:
	get:
		return parent.rotation;
	set(value):
		parent.rotation = value;
var rotation_degrees : float:
	get:
		return parent.rotation_degrees;
	set(value):
		parent.rotation_degrees = value;

func init_state(_parent: Node, _stateMachine: StateMachine) -> void:
	self.parent = _parent;
	self.stateMachine = _stateMachine;
	ready_state();

func ready_state() -> void:
	pass;
func begin_state() -> void:
	pass;
func end_state() -> void:
	pass;

@abstract
func update(_delta: float) -> void;
@abstract
func fixed_update(_delta: float) -> void;
