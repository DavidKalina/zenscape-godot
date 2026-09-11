extends RefCounted
## Persistent inventory lives on its campsite, including through editor saves.
static func valid(record: Dictionary) -> bool:
	for key in ["wood","food","photos"]:
		if not record.has(key): continue
		var limit := 8 if key == "wood" else 3 if key == "food" else 999
		if record.asset != "campsite" or not GardenData._integer(record[key]) or record[key]<0 or record[key]>limit: return false
	if record.has("carrying") and (record.asset != "campsite" or not record.carrying is bool): return false
	if record.has("camper") and (record.asset != "campsite" or record.camper not in ["photographer","backpacker"]): return false
	return true
