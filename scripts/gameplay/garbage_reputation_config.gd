class_name GarbageReputationConfig
extends RefCounted

## Tuning for litter reputation decay — more garbage and longer neglect increase loss.

# How long garbage can sit before it starts hurting reputation (game minutes).
const GRACE_GAME_MINUTES := 8.0

# How often to apply reputation loss while offending garbage remains (game minutes).
const PENALTY_INTERVAL_GAME_MINUTES := 2.0

# Reputation lost per offending piece each penalty tick.
const REPUTATION_LOSS_PER_PIECE_PER_TICK := 1
