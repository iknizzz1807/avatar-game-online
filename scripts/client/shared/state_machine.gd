class_name StateMachine

static var UPDATE_NULL : Callable = (func(_delta : float) -> void: 
	pass;
);

var parentNode : Node;
var stateDictionary : Dictionary[int, StateNode] = {}
var currentState: int;
var prevState : int;
var stateDataTransfer : Dictionary;

var state_to_state_name : Callable = (func(state: int) -> String: return str(state))

func _init(_parentNode: Node) -> void:
	self.parentNode = _parentNode;

func add_states(
	state : int,
	state_node : StateNode
) -> void:
	assert(state_node != null, "State node is null");
	assert(stateDictionary.has(state) == false, "State already exists in state machine");
	stateDictionary[state] = state_node;
	state_node.init_state(parentNode, self);


func get_current_state_name() -> String:
	return state_to_state_name.call(currentState);

func set_initial_state(state: int) -> void:
	if stateDictionary.has(state):
		_set_state(state)
	else:
		printerr("No state with name " + state_to_state_name.call(state))


func update(delta : float) -> void:
	if (stateDictionary.has(currentState)):
		stateDictionary[currentState].update(delta)


func physics_update(delta: float) -> void:
	if (stateDictionary.has(currentState)):
		stateDictionary[currentState].fixed_update(delta);


func change_state(state: int, data : Dictionary = {}) -> void:
	if stateDictionary.has(state):
		if (state == currentState):
			print("Already in state " + state_to_state_name.call(state))
			return;
		stateDataTransfer = data; 
		stateDataTransfer.make_read_only();
		_set_state.call_deferred(state)
	else:
		printerr("No state with name " + state_to_state_name.call(state))


func _set_state(state: int) -> void:
	if currentState:
		stateDictionary[currentState].end_state();

	prevState = currentState;
	currentState = state;
	stateDictionary[currentState].begin_state();
