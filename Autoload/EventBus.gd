@warning_ignore("unused_signal")
extends Node

# --- Player Events ---
signal player_damaged(amount: float, _source: Node2D)
signal player_healed(amount: float)
signal player_died
signal player_level_up(new_level: int)
signal player_xp_gained(amount: float)

# --- Enemy Events ---
signal enemy_died(position: Vector2, xp_value: float, enemy_type: StringName)
signal combo_changed(combo: int)
signal enemy_spawned(enemy_type: StringName)

# --- Spell Events ---
signal spell_cast(spell_name: StringName, position: Vector2, direction: Vector2)
signal spell_upgraded(spell_name: StringName, new_level: int)

# --- Boss Events ---
signal boss_spawned(boss_name: String, max_hp: float, pos: Vector2)
signal boss_defeated(boss_name: String, pos: Vector2)
signal boss_hp_changed(current_hp: float, max_hp: float)
signal boss_enraged(boss_name: StringName)
signal boss_fight_started
signal boss_fight_ended

# --- Wave Events ---
signal wave_started(wave_number: int)
signal wave_cleared(wave_number: int)

# --- Pickup Events ---
signal pickup_collected(pickup_type: StringName, value: float)
signal mega_magnet_activated
signal mega_magnet_ended

signal currency_collected(value: int, rarity: int)
signal chest_spawned(chest: Node2D)
signal chest_removed(chest: Node2D)
signal chest_opened(artifacts: Array, rarity: int)
signal artifact_equipped(artifact: Resource)

# --- Game Events ---
signal game_started
signal game_paused
signal game_resumed
signal game_over
signal victory
signal level_up_card_selected(card_data: Resource)
signal all_phases_completed

# --- Fusion Events ---
signal spell_fused(main_id: StringName, secondary_id: StringName, fusion_id: StringName)

signal crit_landed(damage: float, position: Vector2)
