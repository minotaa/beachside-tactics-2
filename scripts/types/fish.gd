extends ItemType
class_name Fish

var location: Game.Location # The location the fish can appear in.
var power_needed: int # The power needed for the fish, so if you're in a location where you can catch the fish but your total rod power is below this number, you won't have the chance to catch this, also if your rod power is double this amount, you'll instantly catch it.
var difficulty: Game.Difficulty # The difficulty of the fish in the fishing minigame. 
