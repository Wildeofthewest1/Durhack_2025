extends Resource
class_name DialogueData

@export var planet_name: String = "UNNAMED"
@export var lines: Array[String] = [
	"Welcome, pilot.",
	"Our orbit is stable. How can we assist you?"
]

@export var portrait_texture: Texture2D = null

# Optional simple reply buttons. Each reply is text only.
# You can later extend with branching if you want.
@export var replies: Array[String] = [
	"Request status report.",
	"Just passing by."
]
