class_name EconomyConfig
extends RefCounted

## Configurable economy values — keep rewards and costs out of gameplay logic.
##
## Balance reference (default tuning):
## - Starting balance: $500 (testing).
## - In-person / online fulfillment: $1 revenue each.
## - Online van dispatch: $1 flat fee (break-even per single-package trip).
## - Product reorder: $1 logistics per order (unit COGS disabled until catalog pricing).
## - Worker salary: $25/day; hire fee: $1 one-time.
## - Equipment shelf: $50; delivery delay 120 game minutes (~2 real minutes).

const STARTING_COINS := 500

# Order fulfillment rewards.
const IN_PERSON_ORDER_REWARD := 1
const ONLINE_ORDER_REWARD := 1

# Expenses and purchases (see ProductReorderConfig, WorkerHireConfig, EquipmentCatalog).
const DELIVERY_FEE_PLACEHOLDER := 1
const OUTBOUND_DISPATCH_FEE := 1
const HIRE_FEE_PLACEHOLDER := 1
const SALARY_PLACEHOLDER := 25
const WAREHOUSE_PURCHASE_PLACEHOLDER := 50


static func reward_for_fulfillment(source: String) -> int:
	match source:
		"in_person":
			return IN_PERSON_ORDER_REWARD
		"online":
			return ONLINE_ORDER_REWARD
		_:
			return IN_PERSON_ORDER_REWARD
