extends ItemType
class_name Fish

var location: Game.Location # The location the fish can appear in.
var power_needed: int # The power needed for the fish, so if you're in a location where you can catch the fish but your total rod power is below this number, you won't have the chance to catch this, also if your rod power is double this amount, you'll instantly catch it.
var threshold: int # Power needed to instantly catch the fish.
var difficulty: Game.Difficulty # The difficulty of the fish in the fishing minigame. 
var hour_start: float
var hour_end: float # Defines the range of time at which the fish can appear. Assuming it's Game.time / Game.TIME_IN_DAY
