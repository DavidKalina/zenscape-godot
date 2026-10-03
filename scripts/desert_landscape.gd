extends RefCounted
## Source desert.js / desert-monuments.js / desert-mountains.js / desert-salt-basin.js.
## Regional 84-unit landscapes fit one 28-unit diorama; relief remains independently adjustable.
## Held back for an update (docs/HOW-TO-PLAY.md "Desert"): a default game
## offers no desert. With it off, the title never shows an arid world, the
## New world screen has no Red canyon, generated worlds re-roll a desert
## composition and the tray has no Joshua seed. The code all stays: saves
## with desert load and play as before. ENABLED ships it; the --desert flag
## turns it on for development. Tests may set `on` before building.
const ENABLED := false
static var on: bool = ENABLED or "--desert" in OS.get_cmdline_user_args()
const KINDS := ["desert","dunes","tablelands","buttes","monuments","salt-basin","desert-mountains"]
const PROFILES := {
	"desert":[1.0,1.0,1.0,1.0,0.0,[[-6,-7.5,4.8,3.4,6.4],[7.6,-4.2,2,1.6,4.2]]],
	"dunes":[2.1,0.55,0.65,1.8,0.45,[[-9,-9,2,1.7,5]]],
	"tablelands":[0.45,1.2,1.25,0.75,-0.2,[[-6,-6.5,5,4.1,6.5],[6.5,-5,3.8,3.5,5.4],[3.5,5,2.7,2.2,4.8]]],
	"buttes":[0.65,1.3,0.8,1.2,-0.5,[[-8,-7,2.2,1.8,7],[-1,-8,1.5,1.3,5.7],[6,-6,2.2,1.7,6.8],[-5,3,1.6,1.35,4.8],[5,4,1.35,1.6,5.4]]]}
static func hash_at(x: float,z: float,seed_value: float) -> float:
	return fposmod(sin(x*127.1+z*311.7+seed_value)*43758.5453,1.0)
static func fbm(x: float,z: float,seed_value: float) -> float:
	var result := 0.0
	var amp := 0.5
	for i in range(4):
		var ix := floorf(x)
		var iz := floorf(z)
		var u := smoothstep(0,1,x-ix)
		var v := smoothstep(0,1,z-iz)
		var a := hash_at(ix,iz,seed_value)
		var b := hash_at(ix+1,iz,seed_value)
		var c := hash_at(ix,iz+1,seed_value)
		var d := hash_at(ix+1,iz+1,seed_value)
		result += amp*(a+(b-a)*u+(c-a)*v+(a-b-c+d)*u*v)
		amp *= 0.5
		x *= 2.1
		z *= 2.1
	return result
# x = height, y = rock coverage, z = salt coverage.
static func field(g: Dictionary,p: Vector2) -> Vector3:
	var q := p/float(g.breadth)
	var kind: String = g.composition
	var lattice := 97.13 if int(g.seed)==7 else float(g.seed)*0.137+97.13
	var sand := 0.0
	var rock := 0.0
	var salt := 0.0
	var h := 0.0
	if kind in PROFILES:
		var profile: Array = PROFILES[kind]
		sand = 0.75+fbm(q.x*0.09+21,q.y*0.09+21,lattice)*0.8
		var d := q.rotated(float(profile[4]))/float(profile[3])
		var ridge := 1.0-absf(2.0*fbm(d.x*0.045+40,d.y*0.16+40,lattice)-1.0)
		if kind == "dunes":
			var phase := (d.y+(fbm(d.x*0.13+8,d.y*0.08+3,lattice)-0.5)*3.0)/4.5
			var u := fposmod(phase,1.0)
			ridge = smoothstep(0,0.72,u) if u<0.72 else 1.0-smoothstep(0.72,1,u)
		sand += pow(ridge,1.3 if kind=="dunes" else 2.4)*2.1*float(profile[0])
		for m in profile[5]:
			var r := Vector2((q.x-m[0])/(m[2]*profile[2]),(q.y-m[1])/(m[3]*profile[2])).length()
			r += (fbm(q.x*0.5+4,q.y*0.5+4,lattice)-0.5)*0.5
			rock = maxf(rock,float(m[4])*float(profile[1])*(1.0-smoothstep(0.7,1.05,r)))
		h = maxf(sand,rock)
	else:
		q *= 3.0
		lattice = float(g.seed)*0.137+97.13
		var phase := float(g.seed)*0.17
		if kind == "desert-mountains":
			phase = float(g.seed)*0.19
			sand = 1.65+0.65*(1.0-cos((q.y+q.x*0.2)*0.18))
			for side in [-1.0,1.0]:
				var crest: float = side*(25.0+5.0*sin(q.y*0.062+phase+side))+q.y*0.13
				var offset: float = q.x-crest
				var spine := maxf(0,1.0-absf(offset)/(17.0 if offset*side>0 else 14.0))
				var peak := maxf(0,sin(q.y*0.14+phase+side*1.7))
				var tops := 6.5+fbm(q.y*0.085+side*12,phase,lattice)*7.0+pow(peak,3)*8.0
				rock = maxf(rock,pow(spine,1.35)*tops*(0.72+fbm(q.x*0.16+31,q.y*0.14+17,lattice)*0.55))
			h = maxf(sand,rock)
			var wash := 3.0*sin(q.y*0.047+phase)
			var floor_h := 0.8+(42.0-q.y)*0.017
			h = minf(h,lerpf(floor_h,h,smoothstep(1.2,4.2,absf(q.x-wash))))
			if absf(q.x-wash)<4.2: rock = 0.0
		else:
			sand = 1.15+0.6*(1.0-cos((q.y+q.x*0.18)*0.12))+0.16*fbm(q.x*0.035+8,q.y*0.035+3,lattice)
			for f in [[8,-7,6.1,5.1,23,19,10],[-28,-24,9,6,15,19,7],[-21,24,2.8,2.5,10,9,4.5]]:
				var dx: float = q.x-f[0]
				var dz: float = q.y-f[1]
				var angle := atan2(dz,dx)
				var ribs := sin(angle*17+phase)*0.4+sin(angle*29-phase)*0.22
				var apron := maxf(0,1.0-(Vector2(dx,dz).length()+ribs)/float(f[5]))
				var talus := float(f[6])*pow(apron,1.3)
				var turn: float = phase+f[0]*0.13
				var shoulder := 0.09*sin(angle*3+turn)+0.055*sin(angle*5-turn*0.7)
				var notch := 0.17*exp(-pow(sin((angle-turn)*0.5)/0.18,2))
				var wx := dx+0.45*sin(dz*0.35+turn)
				var wz := dz+0.35*sin(dx*0.4-turn)
				var dist := pow(pow(absf(wx/f[2]),3.4)+pow(absf(wz/f[3]),3.4),1.0/3.4)+shoulder+notch
				var flute := 0.033*sin(angle*19+phase)+0.024*sin(angle*31-1.2)
				var cliff := 1.0-smoothstep(0.95,1.12,dist+flute)
				var shelf := smoothstep(-0.3,0.5,dx*0.55+dz*0.32+sin(dz*0.6+turn)*0.6)
				var cap: float = f[4]-shelf*1.1-0.65*fbm(q.x*0.45+9,q.y*0.45+4,lattice)-0.035*dx
				rock = maxf(rock,lerpf(talus,cap,cliff))
			var finger := Vector2((q.x-16.2)/1.15,(q.y+5.1)/1.25).length()
			if finger<1.5: rock = maxf(rock,3.2+17.0*pow(maxf(0,1.0-finger/1.5),0.28))
			h = maxf(sand,rock)
			if kind == "salt-basin":
				var dist := Vector2((q.x-2)/29,(q.y-17)/19).length()+(fbm(q.x*0.08+32,q.y*0.08+11,lattice)-0.5)*0.25
				salt = (1.0-smoothstep(0.7,1.12,dist))*(1.0-smoothstep(2.7,5,h))
				var floor_h := 0.91+0.17*fbm(q.x*0.12+5,q.y*0.12+8,lattice)+0.055*sin(q.x*0.22+q.y*0.13)
				h = lerpf(h,floor_h,smoothstep(0,0.75,salt))
		h = 0.8+h*0.65
	var exposed := float(rock>sand+0.08 and salt<0.1)
	return Vector3(0.8+(h-0.8)*float(g.relief),exposed,salt)
