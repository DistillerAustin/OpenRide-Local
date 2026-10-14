class_name KartInput
extends RefCounted
## One kart's controls for one tick (#43): the rider's from `InputBus`, a bot's from
## `KartBotDriver.think`.

var power_w := 0.0  ## watts
var cadence := 0.0  ## rpm
var lean := 0.0  ## -1 left .. +1 right
var resistance := 0.0  ## 0-100
var standing := false
var use_item := false  ## an edge: true for the one tick the item is used
