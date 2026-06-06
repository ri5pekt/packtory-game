class_name CustomerAngerReputationConfig
extends RefCounted

## Tuning for reputation loss while angry shoppers remain in queue.

# How often to apply reputation loss per angry customer (game minutes).
const PENALTY_INTERVAL_GAME_MINUTES := 4.0

# Reputation lost per angry customer each penalty tick.
const REPUTATION_LOSS_PER_ANGRY_CUSTOMER_PER_TICK := 1
