class_name ItemRarity

enum Tier { COMMON, UNCOMMON, RARE, LEGENDARY }

const COLORS := {
	Tier.COMMON:    Color(0.8, 0.8, 0.8),
	Tier.UNCOMMON:  Color(0.2, 0.8, 0.2),
	Tier.RARE:      Color(0.2, 0.4, 1.0),
	Tier.LEGENDARY: Color(1.0, 0.6, 0.0),
}

const DROP_WEIGHTS := {
	Tier.COMMON:    60,
	Tier.UNCOMMON:  25,
	Tier.RARE:      12,
	Tier.LEGENDARY: 3,
}

static func roll() -> Tier:
	var total := 0
	for w in DROP_WEIGHTS.values():
		total += w
	var r := randi() % total
	var acc := 0
	for tier in DROP_WEIGHTS:
		acc += DROP_WEIGHTS[tier]
		if r < acc:
			return tier
	return Tier.COMMON
