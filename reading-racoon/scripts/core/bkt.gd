class_name BKT
extends RefCounted
## Bayesian Knowledge Tracing math (see docs/knowledge/05-bkt-engine.md).


## Chance the child knows the skill after one answer.
static func posterior(p: float, correct: bool, g: float, s: float) -> float:
	if correct:
		var known := p * (1.0 - s)
		return known / (known + (1.0 - p) * g)
	var slipped := p * s
	return slipped / (slipped + (1.0 - p) * (1.0 - g))


## Chance the child knows the skill next time, counting the chance to learn it now.
static func transition(p_post: float, t: float) -> float:
	return p_post + (1.0 - p_post) * t


## Guess rate for one item. Choice items use 1 / number of choices.
## Always keeps 1 - S > G, or the math breaks.
static func guess_for(base_g: float, s: float, num_choices: int) -> float:
	var g := base_g
	if num_choices >= 2:
		g = 1.0 / num_choices
	return minf(g, 1.0 - s - 0.01)
