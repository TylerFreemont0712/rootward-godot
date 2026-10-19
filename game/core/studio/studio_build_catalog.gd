class_name StudioBuildCatalog
extends RefCounted
## B01 construction inventory over existing canonical metadata. No extra catalog format or copied asset records.

const GROUPS: Array[String] = ["building", "boundary", "gate", "furniture"]
## Exact existing family IDs, not words matched against an asset's ID, name or tags.
const GATE_FAMILIES: Array[String] = ["gate", "gate-wide-2", "gate-wide-3", "gate-wide-2-v", "expand-gate"]


static func group(entry: Dictionary) -> String:
	var kind := String(entry.get("kind", ""))
	if kind == "building":
		return "building"
	if kind != "prop":
		return ""
	var category := String(entry.get("category", ""))
	if category == "street" and String(entry.get("subcategory", "")) == "fences_and_gates":
		return "gate" if GATE_FAMILIES.has(String(entry.get("family", ""))) else "boundary"
	var places: Variant = entry.get("place", [])
	if category == "furniture" and places is Array and (places as Array).has("indoor"):
		return "furniture"
	return ""
