class_name BKT
extends RefCounted
## Bayesian Knowledge Tracing update equations (FR-03). Pure math, well under the
## 500 ms budget of NFR-01. Source: docs/knowledge/05-bkt-engine.md.


## P(L | obs): mastery probability after seeing one answer.
static func posterior(p: float, correct: bool, g: float, s: float) -> float:
	if correct:
		var known := p * (1.0 - s)
		return known / (known + (1.0 - p) * g)
	var slipped := p * s
	return slipped / (slipped + (1.0 - p) * (1.0 - g))


## P(L t+1): the chance of learning the skill from this practice opportunity.
static func transition(p_post: float, t: float) -> float:
	return p_post + (1.0 - p_post) * t


## Guess rate for one item. Choice-style items (tap one card, drop one of N tiles)
## use 1 / number of choices (D-003 rule 7). Always keeps 1 - S > G.
static func guess_for(base_g: float, s: float, num_choices: int) -> float:
	var g := base_g
	if num_choices >= 2:
		g = 1.0 / num_choices
	return minf(g, 1.0 - s - 0.01)
