extends RefCounted
## Money on screen: whole units with thousands separators (12,400 and
## 1,250,000; never 1.25M). The one formatter every money label uses.


## `n` with a comma every three digits, its sign kept.
static func money(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length()-3) + out
		s = s.substr(0, s.length()-3)
	return ("-" if n < 0 else "") + s + out
