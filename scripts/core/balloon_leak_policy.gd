class_name BalloonLeakPolicy
extends RefCounted

# Compatibility policy, deliberately separate from rewards, Pops and damage.
# Type RBE includes the full current shell even if partially damaged. A later
# fidelity patch can replace this one entry point without altering combat.
static func damage(balloon: BalloonState) -> int:
	return balloon.total_rbe()
