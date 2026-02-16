class_name DeckDefinition
extends Resource

@export var ranks: PackedStringArray = ["A","2","3","4","5","6","7","8","9","10","J","Q","K"]
@export var suit_symbols: PackedStringArray = ["♣","♦","♥","♠"]
@export var jokers: int = 0

static func make_standard_52() -> DeckDefinition:
	var d := DeckDefinition.new()
	d.ranks = ["A","2","3","4","5","6","7","8","9","10","J","Q","K"]
	d.suit_symbols = ["♣","♦","♥","♠"]
	d.jokers = 0
	return d

func main_count() -> int:
	return ranks.size() * suit_symbols.size()

func total_count() -> int:
	return main_count() + jokers

func build_full_deck_ids() -> Array[int]:
	var out: Array[int] = []
	out.resize(total_count())
	for i in range(total_count()):
		out[i] = i
	return out

func card_id_to_text(id: int) -> String:
	if id < 0 or id >= total_count():
		return "??"

	var m: int = main_count()
	if id < m:
		var rcount: int = ranks.size()
		var ridx: int = id % rcount
		@warning_ignore("integer_division")
		var sidx: int = int(id / rcount)
		if sidx < 0 or sidx >= suit_symbols.size():
			return "??"
		return ranks[ridx] + suit_symbols[sidx]

	return "Jkr" + str((id - m) + 1)
