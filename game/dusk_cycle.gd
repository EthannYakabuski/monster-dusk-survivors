extends RefCounted
## Presentation follows active simulation time, never wall-clock/ad duration.

const LENGTH := 120.0
const NAMES := ["Dusk", "Night", "Dawn", "Day"]
const GROUND := [Color("9b7560"), Color("46536b"), Color("c6937c"), Color("c1af83")]
const SKY := [Color("47546f"), Color("192a45"), Color("b17e78"), Color("75a6b5")]
const LANTERN := [0.35, 1.0, 0.45, 0.0]

static func sample(seconds: float) -> Dictionary:
	var phase := fposmod(maxf(0.0, seconds), LENGTH)
	var index := mini(3, int(phase / 30.0))
	var following := (index + 1) % 4
	var blend := smoothstep(0.0, 1.0, fposmod(phase, 30.0) / 30.0)
	return {"name": NAMES[index], "ground": GROUND[index].lerp(GROUND[following], blend),
		"sky": SKY[index].lerp(SKY[following], blend),
		"lantern": lerpf(LANTERN[index], LANTERN[following], blend)}
