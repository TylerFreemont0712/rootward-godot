class_name StudioRebase
extends RefCounted
## Reapplies one Studio draft to a newer copy of its source file, without touching any input doc.
##
## Base and draft share session ids. The disk doc does not, so objects are matched by persistent id, then by their
## kind, art and cell, and finally by the nearest unmatched object with the same kind and art. Ambiguous matches are
## reported instead of guessed.


## The candidate merged doc, the current disk doc with aligned session ids, and any conflicts.
static func rebase(base: StudioDoc, draft: StudioDoc, current: StudioDoc) -> Dictionary:
	var conflicts: Array[Dictionary] = []
	var base_objects: Array = _objects(base)
	var draft_objects: Array = _objects(draft)
	var current_objects: Array = _objects(current)
	var base_to_draft: Array[int] = _match_draft_sids(base, draft, base_objects, draft_objects, conflicts)
	var base_to_current: Array[int] = _match_current_objects(
		base, draft, current, base_objects, draft_objects, current_objects, base_to_draft, conflicts
	)
	var current_to_base: Array[int] = []
	for current_index: int in current_objects.size():
		current_to_base.append(-1)
	for base_index: int in base_to_current.size():
		var current_index: int = base_to_current[base_index]
		if current_index >= 0 and current_index < current_to_base.size():
			current_to_base[current_index] = base_index

	var allocator := {"next": _first_free_sid(base, draft, current)}
	var reserved: Dictionary = _reserved_sids(base, draft)
	var used: Dictionary = {}
	var current_sids: Array[int] = _assign_current_sids(
		base, draft, current, current_objects, current_to_base, base_to_draft, reserved, used, allocator
	)

	var output := current.copy()
	output.data = JsoncWriter.normalized(current.data)
	var output_objects: Array = []
	var output_sids: Array[int] = []
	for current_index: int in current_objects.size():
		var current_object: Variant = current_objects[current_index]
		var base_index: int = current_to_base[current_index]
		if base_index < 0 or typeof(current_object) != TYPE_DICTIONARY:
			output_objects.append(JsoncWriter.normalized(current_object))
			output_sids.append(current_sids[current_index])
			continue

		var base_object: Variant = base_objects[base_index]
		var draft_index: int = base_to_draft[base_index]
		var current_sid: int = current_sids[current_index]
		if draft_index == -1:
			if _same_value(base_object, current_object):
				continue
			_add_conflict(
				conflicts,
				current.path,
				current_sid,
				"object",
				"The draft removed this object, but the current file changed it.",
				true,
				base_object,
				false,
				null,
				true,
				current_object
			)
			output_objects.append(JsoncWriter.normalized(current_object))
			output_sids.append(current_sid)
			continue
		if draft_index == -2:
			output_objects.append(JsoncWriter.normalized(current_object))
			output_sids.append(current_sid)
			continue
		if draft_index < 0 or draft_index >= draft_objects.size():
			output_objects.append(JsoncWriter.normalized(current_object))
			output_sids.append(current_sid)
			continue

		var draft_object: Variant = draft_objects[draft_index]
		if typeof(base_object) != TYPE_DICTIONARY or typeof(draft_object) != TYPE_DICTIONARY:
			if _same_value(base_object, draft_object):
				output_objects.append(JsoncWriter.normalized(current_object))
				output_sids.append(current_sid)
			else:
				_add_conflict(
					conflicts,
					current.path,
					current_sid,
					"object",
					"This object changed in both the draft and current file.",
					true,
					base_object,
					true,
					draft_object,
					true,
					current_object
				)
				output_objects.append(JsoncWriter.normalized(current_object))
				output_sids.append(current_sid)
			continue

		var merged_object: Dictionary = _merge_dictionary(
			base_object as Dictionary,
			draft_object as Dictionary,
			current_object as Dictionary,
			current.path,
			current_sid,
			"",
			conflicts
		)
		output_objects.append(JsoncWriter.normalized(merged_object))
		output_sids.append(current_sid)

	for base_index: int in base_objects.size():
		if base_to_current[base_index] >= 0 or base_to_current[base_index] == -2:
			continue
		var draft_index: int = base_to_draft[base_index]
		if draft_index == -1 or draft_index == -2:
			continue
		if draft_index < 0 or draft_index >= draft_objects.size():
			continue
		var base_object: Variant = base_objects[base_index]
		var draft_object: Variant = draft_objects[draft_index]
		if _same_value(base_object, draft_object):
			continue
		_add_conflict(
			conflicts,
			current.path,
			_sid_at(base, base_index),
			"object",
			"The draft changed this object, but it is no longer in the current file.",
			true,
			base_object,
			true,
			draft_object,
			false,
			null
		)

	var base_sid_lookup: Dictionary = _sid_lookup(base, base_objects.size())
	for draft_index: int in draft_objects.size():
		var draft_sid: int = _sid_at(draft, draft_index)
		if base_sid_lookup.has(draft_sid):
			continue
		var draft_object: Variant = draft_objects[draft_index]
		output_objects.append(JsoncWriter.normalized(draft_object))
		var addition_sid: int = draft_sid
		if addition_sid < 1 or used.has(addition_sid):
			addition_sid = _allocate_sid(used, allocator)
		else:
			used[addition_sid] = true
		output_sids.append(addition_sid)

	var output_data: Dictionary = output.data
	var map_keys: Array[String] = _union_keys(base.data, draft.data, current.data)
	for key: String in map_keys:
		if key == "objects":
			continue
		if key == "ground":
			var ground_result := _merge_ground_slot(base, draft, current, conflicts)
			if ground_result["present"]:
				output_data[key] = ground_result["value"]
			else:
				output_data.erase(key)
			continue
		var merged_slot := _merge_slot(
			base.data.has(key),
			base.data.get(key),
			draft.data.has(key),
			draft.data.get(key),
			current.data.has(key),
			current.data.get(key),
			current.path,
			null,
			key,
			conflicts
		)
		if merged_slot["present"]:
			output_data[key] = JsoncWriter.normalized(merged_slot["value"])
		else:
			output_data.erase(key)

	if output_objects.size() > 0 or current.data.has("objects") or base.data.has("objects") or draft.data.has("objects"):
		output_data["objects"] = output_objects
	else:
		output_data.erase("objects")
	output.data = JsoncWriter.normalized(output_data)
	output.sids = output_sids
	output.next_sid = int(allocator["next"])

	var aligned_base := current.copy()
	aligned_base.data = JsoncWriter.normalized(current.data)
	aligned_base.sids = current_sids
	aligned_base.next_sid = int(allocator["next"])
	return {
		"ok": conflicts.is_empty(),
		"doc": output,
		"base_doc": aligned_base,
		"conflicts": conflicts,
	}


static func _objects(doc: StudioDoc) -> Array:
	var value: Variant = doc.data.get("objects", [])
	return value as Array if typeof(value) == TYPE_ARRAY else []


static func _sid_at(doc: StudioDoc, index: int) -> int:
	if index >= 0 and index < doc.sids.size():
		return doc.sids[index]
	return index + 1


static func _match_draft_sids(
	base: StudioDoc,
	draft: StudioDoc,
	base_objects: Array,
	draft_objects: Array,
	conflicts: Array[Dictionary]
) -> Array[int]:
	var matches: Array[int] = []
	var base_counts: Dictionary = {}
	for base_index: int in base_objects.size():
		var sid: int = _sid_at(base, base_index)
		base_counts[sid] = int(base_counts.get(sid, 0)) + 1
	for base_index: int in base_objects.size():
		var sid: int = _sid_at(base, base_index)
		var draft_indices: Array[int] = _indices_with_sid(draft.sids, sid)
		if int(base_counts[sid]) > 1 or draft_indices.size() > 1:
			_add_conflict(
				conflicts,
				draft.path,
				sid,
				"identity",
				"The draft session id is ambiguous, so this object cannot be matched safely.",
				true,
			base_objects[base_index],
				draft_indices.size() > 0,
				draft_objects[draft_indices[0]] if draft_indices.size() > 0 else null,
				false,
				null
			)
			matches.append(-2)
		elif draft_indices.is_empty():
			matches.append(-1)
		else:
			matches.append(draft_indices[0])
	return matches


static func _indices_with_sid(sids: Array[int], sid: int) -> Array[int]:
	var indices: Array[int] = []
	for index: int in sids.size():
		if sids[index] == sid:
			indices.append(index)
	return indices


static func _match_current_objects(
	base: StudioDoc,
	draft: StudioDoc,
	current: StudioDoc,
	base_objects: Array,
	draft_objects: Array,
	current_objects: Array,
	base_to_draft: Array[int],
	conflicts: Array[Dictionary]
) -> Array[int]:
	var matches: Array[int] = []
	var current_claims: Array[int] = []
	var blocked_current: Dictionary = {}
	for base_index: int in base_objects.size():
		matches.append(-1)
	for current_index: int in current_objects.size():
		current_claims.append(-1)

	for base_index: int in base_objects.size():
		if typeof(base_objects[base_index]) != TYPE_DICTIONARY:
			continue
		var object: Dictionary = base_objects[base_index]
		var object_id: String = _persistent_id(object)
		if object_id.is_empty():
			continue
		var draft_index: int = base_to_draft[base_index]
		if _base_id_count(base_objects, object_id) > 1:
			var same_id: Array[int] = _current_indices_with_id(current_objects, object_id)
			for candidate_index: int in same_id:
				blocked_current[candidate_index] = true
			matches[base_index] = -2
			if _has_draft_intent(base_objects[base_index], draft_objects, draft_index):
				_add_identity_conflict(base, draft, current, base_index, draft_index, same_id, base_objects, draft_objects, current_objects, conflicts, "Several base objects share this persistent id.")
			continue
		var candidates: Array[int] = _current_indices_with_id(current_objects, object_id)
		if candidates.size() > 1:
			matches[base_index] = -2
			for candidate_index: int in candidates:
				blocked_current[candidate_index] = true
			if _has_draft_intent(base_objects[base_index], draft_objects, draft_index):
				_add_identity_conflict(base, draft, current, base_index, draft_index, candidates, base_objects, draft_objects, current_objects, conflicts, "Several current objects share this persistent id.")
		elif candidates.size() == 1:
			var candidate_index: int = candidates[0]
			if current_claims[candidate_index] >= 0:
				var previous_base: int = current_claims[candidate_index]
				matches[base_index] = -2
				matches[previous_base] = -2
				blocked_current[candidate_index] = true
				if _has_draft_intent(base_objects[base_index], draft_objects, draft_index):
					_add_identity_conflict(base, draft, current, base_index, draft_index, candidates, base_objects, draft_objects, current_objects, conflicts, "This current object matches more than one base object.")
				var previous_draft_index: int = base_to_draft[previous_base]
				if _has_draft_intent(base_objects[previous_base], draft_objects, previous_draft_index):
					_add_identity_conflict(base, draft, current, previous_base, previous_draft_index, candidates, base_objects, draft_objects, current_objects, conflicts, "This current object matches more than one base object.")
			else:
				matches[base_index] = candidate_index
				current_claims[candidate_index] = base_index

	var exact_lists: Array[Array] = []
	for base_index: int in base_objects.size():
		var candidates: Array[int] = []
		if matches[base_index] == -1 and typeof(base_objects[base_index]) == TYPE_DICTIONARY:
			var base_object: Dictionary = base_objects[base_index]
			if _persistent_id(base_object).is_empty():
				var base_cell: Variant = _object_cell(base_object)
				if base_cell != null:
					for current_index: int in current_objects.size():
						if current_claims[current_index] != -1 or blocked_current.has(current_index):
							continue
						if typeof(current_objects[current_index]) != TYPE_DICTIONARY:
							continue
						var current_object: Dictionary = current_objects[current_index]
						var current_cell: Variant = _object_cell(current_object)
						if current_cell != null and current_cell == base_cell and _same_kind_art(base_object, current_object):
							candidates.append(current_index)
		exact_lists.append(candidates)

	for base_index: int in base_objects.size():
		var candidates: Array = exact_lists[base_index]
		if candidates.is_empty():
			continue
		var reverse_count := 0
		for other_index: int in exact_lists.size():
			if exact_lists[other_index].has(candidates[0]):
				reverse_count += 1
		if candidates.size() != 1 or reverse_count != 1:
			matches[base_index] = -2
			for candidate: Variant in candidates:
				blocked_current[int(candidate)] = true
			if _has_draft_intent(base_objects[base_index], draft_objects, base_to_draft[base_index]):
				_add_identity_conflict(
					base,
					draft,
					current,
					base_index,
					base_to_draft[base_index],
					_exact_candidate_indices(candidates),
					base_objects,
					draft_objects,
					current_objects,
					conflicts,
					"Several objects have the same kind, art and cell."
				)
		else:
			var candidate_index: int = int(candidates[0])
			matches[base_index] = candidate_index
			current_claims[candidate_index] = base_index

	var nearest_lists: Array[Array] = []
	var nearest_distances: Array[int] = []
	var distance_valid: Array[bool] = []
	for base_index: int in base_objects.size():
		nearest_lists.append([])
		nearest_distances.append(2147483647)
		distance_valid.append(false)
		if matches[base_index] != -1 or typeof(base_objects[base_index]) != TYPE_DICTIONARY:
			continue
		var base_object: Dictionary = base_objects[base_index]
		if not _persistent_id(base_object).is_empty():
			continue
		var candidates: Array[int] = []
		for current_index: int in current_objects.size():
			if current_claims[current_index] != -1 or blocked_current.has(current_index):
				continue
			if typeof(current_objects[current_index]) != TYPE_DICTIONARY:
				continue
			if _same_kind_art(base_object, current_objects[current_index] as Dictionary):
				candidates.append(current_index)
		if candidates.is_empty():
			continue
		var base_cell: Variant = _object_cell(base_object)
		var candidate_distances: Dictionary = {}
		var cells_valid := base_cell != null
		if cells_valid:
			var base_position: Vector2i = base_cell
			for candidate_index: int in candidates:
				var candidate_cell: Variant = _object_cell(current_objects[candidate_index] as Dictionary)
				if candidate_cell == null:
					cells_valid = false
					break
				var candidate_position: Vector2i = candidate_cell
				candidate_distances[candidate_index] = (
					absi(candidate_position.x - base_position.x) + absi(candidate_position.y - base_position.y)
				)
		if not cells_valid:
			if candidates.size() == 1:
				nearest_lists[base_index] = candidates
			else:
				nearest_lists[base_index] = candidates
			continue
		var nearest: Array[int] = []
		var nearest_distance: int = 2147483647
		for candidate_index: int in candidates:
			var distance: int = int(candidate_distances[candidate_index])
			if distance < nearest_distance:
				nearest_distance = distance
				nearest.clear()
				nearest.append(candidate_index)
			elif distance == nearest_distance:
				nearest.append(candidate_index)
		nearest_lists[base_index] = nearest
		nearest_distances[base_index] = nearest_distance
		distance_valid[base_index] = true

	for base_index: int in base_objects.size():
		var nearest: Array = nearest_lists[base_index]
		if nearest.size() <= 1:
			continue
		matches[base_index] = -2
		var tied: Array[int] = _exact_candidate_indices(nearest)
		for candidate_index: int in tied:
			blocked_current[candidate_index] = true
		if _has_draft_intent(base_objects[base_index], draft_objects, base_to_draft[base_index]):
			_add_identity_conflict(
				base,
				draft,
				current,
				base_index,
				base_to_draft[base_index],
				tied,
				base_objects,
				draft_objects,
				current_objects,
				conflicts,
				"The nearest current objects are tied, so this object cannot be matched safely."
			)

	for base_index: int in base_objects.size():
		if matches[base_index] != -1 or nearest_lists[base_index].size() != 1:
			continue
		var candidate_index: int = nearest_lists[base_index][0]
		if blocked_current.has(candidate_index):
			matches[base_index] = -2
			var blocked_candidate: Array[int] = [candidate_index]
			if _has_draft_intent(base_objects[base_index], draft_objects, base_to_draft[base_index]):
				_add_identity_conflict(
					base,
					draft,
					current,
					base_index,
					base_to_draft[base_index],
					blocked_candidate,
					base_objects,
					draft_objects,
					current_objects,
					conflicts,
					"This current object is part of another ambiguous match."
				)
			continue
		var references: Array[int] = []
		for other_base_index: int in nearest_lists.size():
			if nearest_lists[other_base_index].has(candidate_index):
				references.append(other_base_index)
		if references.size() == 1:
			matches[base_index] = candidate_index
			current_claims[candidate_index] = base_index
			continue
		var valid_references := true
		var closest_distance: int = 2147483647
		var closest_bases: Array[int] = []
		for reference_index: int in references:
			if not distance_valid[reference_index]:
				valid_references = false
				break
			var distance: int = nearest_distances[reference_index]
			if distance < closest_distance:
				closest_distance = distance
				closest_bases.clear()
				closest_bases.append(reference_index)
			elif distance == closest_distance:
				closest_bases.append(reference_index)
		if valid_references and closest_bases.size() == 1:
			var closest_base: int = closest_bases[0]
			matches[closest_base] = candidate_index
			current_claims[candidate_index] = closest_base
			continue
		blocked_current[candidate_index] = true
		for reference_index: int in references:
			matches[reference_index] = -2
			if _has_draft_intent(base_objects[reference_index], draft_objects, base_to_draft[reference_index]):
				var candidate_list: Array[int] = [candidate_index]
				_add_identity_conflict(
					base,
					draft,
					current,
					reference_index,
					base_to_draft[reference_index],
					candidate_list,
					base_objects,
					draft_objects,
					current_objects,
					conflicts,
					"Several base objects are equally close to the same current object."
				)

	return matches


static func _has_draft_intent(base_object: Variant, draft_objects: Array, draft_index: int) -> bool:
	if draft_index == -1 or draft_index == -2:
		return true
	if draft_index < 0 or draft_index >= draft_objects.size():
		return false
	return not _same_value(base_object, draft_objects[draft_index])


static func _persistent_id(object: Dictionary) -> String:
	var value: Variant = object.get("id")
	return String(value) if typeof(value) == TYPE_STRING and not String(value).is_empty() else ""


static func _exact_candidate_indices(candidates: Array) -> Array[int]:
	var indices: Array[int] = []
	for candidate: Variant in candidates:
		indices.append(int(candidate))
	return indices


static func _base_id_count(objects: Array, object_id: String) -> int:
	var count := 0
	for value: Variant in objects:
		if typeof(value) == TYPE_DICTIONARY and _persistent_id(value as Dictionary) == object_id:
			count += 1
	return count


static func _current_indices_with_id(objects: Array, object_id: String) -> Array[int]:
	var indices: Array[int] = []
	for index: int in objects.size():
		if typeof(objects[index]) == TYPE_DICTIONARY and _persistent_id(objects[index] as Dictionary) == object_id:
			indices.append(index)
	return indices


static func _same_kind_art(first: Dictionary, second: Dictionary) -> bool:
	return _same_value(first.get("kind"), second.get("kind")) and _same_value(first.get("art"), second.get("art"))


static func _object_cell(object: Dictionary) -> Variant:
	var value: Variant = object.get("at")
	if typeof(value) != TYPE_ARRAY:
		return null
	var cell: Array = value
	if cell.size() != 2 or not _whole_number(cell[0]) or not _whole_number(cell[1]):
		return null
	return Vector2i(int(cell[0]), int(cell[1]))


static func _whole_number(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) != TYPE_FLOAT:
		return false
	var number: float = value
	return number == floorf(number) and absf(number) <= JsoncWriter.MAX_WHOLE


static func _add_identity_conflict(
	base: StudioDoc,
	draft: StudioDoc,
	current: StudioDoc,
	base_index: int,
	draft_index: int,
	candidates: Array[int],
	base_objects: Array,
	draft_objects: Array,
	current_objects: Array,
	conflicts: Array[Dictionary],
	message: String
) -> void:
	var candidate_objects: Array = []
	for candidate_index: int in candidates:
		if candidate_index >= 0 and candidate_index < current_objects.size():
			candidate_objects.append(JsoncWriter.normalized(current_objects[candidate_index]))
	var draft_present := draft_index >= 0 and draft_index < draft_objects.size()
	_add_conflict(
		conflicts,
		current.path,
		_sid_at(base, base_index),
		"identity",
		message,
		true,
		base_objects[base_index],
		draft_present,
		draft_objects[draft_index] if draft_present else null,
		true,
		candidate_objects
	)


static func _merge_dictionary(
	base: Dictionary,
	draft: Dictionary,
	current: Dictionary,
	file_path: String,
	sid: Variant,
	field_prefix: String,
	conflicts: Array[Dictionary]
) -> Dictionary:
	var merged: Dictionary = {}
	for key: String in _union_keys(base, draft, current):
		var field_name: String = key if field_prefix.is_empty() else "%s.%s" % [field_prefix, key]
		var slot := _merge_slot(
			base.has(key),
			base.get(key),
			draft.has(key),
			draft.get(key),
			current.has(key),
			current.get(key),
			file_path,
			sid,
			field_name,
			conflicts
		)
		if slot["present"]:
			merged[key] = JsoncWriter.normalized(slot["value"])
	return merged


static func _merge_slot(
	base_present: bool,
	base_value: Variant,
	draft_present: bool,
	draft_value: Variant,
	current_present: bool,
	current_value: Variant,
	file_path: String,
	sid: Variant,
	field: String,
	conflicts: Array[Dictionary]
) -> Dictionary:
	if _same_slot(draft_present, draft_value, base_present, base_value):
		return _slot(current_present, current_value)
	if _same_slot(current_present, current_value, base_present, base_value):
		return _slot(draft_present, draft_value)
	if _same_slot(draft_present, draft_value, current_present, current_value):
		return _slot(current_present, current_value)
	if draft_present and current_present and typeof(draft_value) == TYPE_DICTIONARY and typeof(current_value) == TYPE_DICTIONARY:
		var base_dictionary: Dictionary = {}
		if base_present and typeof(base_value) == TYPE_DICTIONARY:
			base_dictionary = base_value
		elif base_present:
			_add_slot_conflict(
				conflicts,
				file_path,
				sid,
				field,
				base_present,
				base_value,
				draft_present,
				draft_value,
				current_present,
				current_value
			)
			return _slot(current_present, current_value)
		var merged_dictionary: Dictionary = _merge_dictionary(
			base_dictionary,
			draft_value,
			current_value,
			file_path,
			sid,
			field,
			conflicts
		)
		return _slot(true, merged_dictionary)

	_add_slot_conflict(
		conflicts,
		file_path,
		sid,
		field,
		base_present,
		base_value,
		draft_present,
		draft_value,
		current_present,
		current_value
	)
	return _slot(current_present, current_value)


static func _same_slot(first_present: bool, first_value: Variant, second_present: bool, second_value: Variant) -> bool:
	if first_present != second_present:
		return false
	return not first_present or _same_value(first_value, second_value)


static func _same_value(first: Variant, second: Variant) -> bool:
	return JsoncWriter.normalized(first) == JsoncWriter.normalized(second)


static func _slot(present: bool, value: Variant) -> Dictionary:
	return {"present": present, "value": JsoncWriter.normalized(value)}


static func _merge_ground_slot(
	base: StudioDoc,
	draft: StudioDoc,
	current: StudioDoc,
	conflicts: Array[Dictionary]
) -> Dictionary:
	var base_present: bool = base.data.has("ground")
	var draft_present: bool = draft.data.has("ground")
	var current_present: bool = current.data.has("ground")
	var base_value: Variant = base.data.get("ground")
	var draft_value: Variant = draft.data.get("ground")
	var current_value: Variant = current.data.get("ground")
	if _same_slot(draft_present, draft_value, base_present, base_value):
		return _slot(current_present, current_value)
	if _same_slot(current_present, current_value, base_present, base_value):
		return _slot(draft_present, draft_value)
	if _same_slot(draft_present, draft_value, current_present, current_value):
		return _slot(current_present, current_value)
	var base_rows: Variant = _ground_rows(base_value) if base_present else []
	var draft_rows: Variant = _ground_rows(draft_value) if draft_present else []
	var current_rows: Variant = _ground_rows(current_value) if current_present else []
	if typeof(draft_rows) == TYPE_ARRAY and typeof(current_rows) == TYPE_ARRAY and (not base_present or typeof(base_rows) == TYPE_ARRAY):
		var rows: Array = _merge_ground_rows(
			base_rows as Array,
			draft_rows as Array,
			current_rows as Array,
			current.path,
			conflicts
		)
		return _slot(true, rows)
	_add_slot_conflict(
		conflicts,
		current.path,
		null,
		"ground",
		base_present,
		base_value,
		draft_present,
		draft_value,
		current_present,
		current_value
	)
	return _slot(current_present, current_value)


static func _ground_rows(value: Variant) -> Variant:
	if typeof(value) != TYPE_ARRAY:
		return null
	var rows: Array[String] = []
	var source: Array = value
	for row: Variant in source:
		if typeof(row) != TYPE_STRING:
			return null
		rows.append(String(row))
	return rows


static func _merge_ground_rows(
	base_rows: Array,
	draft_rows: Array,
	current_rows: Array,
	file_path: String,
	conflicts: Array[Dictionary]
) -> Array[String]:
	var base_size := _ground_size(base_rows)
	var draft_size := _ground_size(draft_rows)
	var current_size := _ground_size(current_rows)
	var height_slot := _merge_slot(
		true, base_size.y, true, draft_size.y, true, current_size.y, file_path, null, "ground.height", conflicts
	)
	var width_slot := _merge_slot(
		true, base_size.x, true, draft_size.x, true, current_size.x, file_path, null, "ground.width", conflicts
	)
	var cell_slots: Dictionary = {}
	var max_width: int = maxi(base_size.x, maxi(draft_size.x, current_size.x))
	var max_height: int = maxi(base_size.y, maxi(draft_size.y, current_size.y))
	for y: int in max_height:
		for x: int in max_width:
			var base_cell: Dictionary = _ground_cell(base_rows, x, y)
			var draft_cell: Dictionary = _ground_cell(draft_rows, x, y)
			var current_cell: Dictionary = _ground_cell(current_rows, x, y)
			var field: String = "ground[%d,%d]" % [x, y]
			var cell_slot := _merge_slot(
				base_cell["present"],
				base_cell["value"],
				draft_cell["present"],
				draft_cell["value"],
				current_cell["present"],
				current_cell["value"],
				file_path,
				null,
				field,
				conflicts
			)
			if cell_slot["present"]:
				cell_slots["%d,%d" % [x, y]] = cell_slot["value"]
	var output_width: int = maxi(0, int(width_slot["value"]))
	var output_height: int = maxi(0, int(height_slot["value"]))
	for y: int in max_height:
		for x: int in max_width:
			if cell_slots.has("%d,%d" % [x, y]):
				output_width = maxi(output_width, x + 1)
				output_height = maxi(output_height, y + 1)
	var output_rows: Array[String] = []
	for y: int in output_height:
		var row := ""
		for x: int in output_width:
			var key: String = "%d,%d" % [x, y]
			row += String(cell_slots[key]) if cell_slots.has(key) else " "
		output_rows.append(row)
	return output_rows


static func _ground_size(rows: Array) -> Vector2i:
	var width := 0
	for row: Variant in rows:
		if typeof(row) == TYPE_STRING:
			width = maxi(width, String(row).length())
	return Vector2i(width, rows.size())


static func _ground_cell(rows: Array, x: int, y: int) -> Dictionary:
	if y < 0 or y >= rows.size() or typeof(rows[y]) != TYPE_STRING:
		return {"present": false, "value": null}
	var row: String = rows[y]
	if x < 0 or x >= row.length():
		return {"present": false, "value": null}
	return {"present": true, "value": row.substr(x, 1)}


static func _add_slot_conflict(
	conflicts: Array[Dictionary],
	file_path: String,
	sid: Variant,
	field: String,
	base_present: bool,
	base_value: Variant,
	draft_present: bool,
	draft_value: Variant,
	current_present: bool,
	current_value: Variant
) -> void:
	_add_conflict(
		conflicts,
		file_path,
		sid,
		field,
		"The draft and current file changed this field differently; the current value was kept.",
		base_present,
		base_value,
		draft_present,
		draft_value,
		current_present,
		current_value
	)


static func _add_conflict(
	conflicts: Array[Dictionary],
	file_path: String,
	sid: Variant,
	field: String,
	message: String,
	base_present: bool,
	base_value: Variant,
	draft_present: bool,
	draft_value: Variant,
	current_present: bool,
	current_value: Variant
) -> void:
	var conflict: Dictionary = {
		"file": file_path,
		"sid": sid,
		"field": field,
		"message": message,
		"base_present": base_present,
		"draft_present": draft_present,
		"current_present": current_present,
	}
	if base_present:
		conflict["base"] = JsoncWriter.normalized(base_value)
	if draft_present:
		conflict["draft"] = JsoncWriter.normalized(draft_value)
	if current_present:
		conflict["current"] = JsoncWriter.normalized(current_value)
	conflicts.append(conflict)


static func _union_keys(first: Dictionary, second: Dictionary, third: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	for source: Dictionary in [third, second, first]:
		for raw_key: Variant in source:
			var key := String(raw_key)
			if not keys.has(key):
				keys.append(key)
	return keys


static func _sid_lookup(doc: StudioDoc, object_count: int) -> Dictionary:
	var found: Dictionary = {}
	for index: int in object_count:
		found[_sid_at(doc, index)] = true
	return found


static func _reserved_sids(base: StudioDoc, draft: StudioDoc) -> Dictionary:
	var reserved: Dictionary = {}
	for sid: int in base.sids:
		if sid > 0:
			reserved[sid] = true
	for sid: int in draft.sids:
		if sid > 0:
			reserved[sid] = true
	return reserved


static func _assign_current_sids(
	base: StudioDoc,
	draft: StudioDoc,
	current: StudioDoc,
	current_objects: Array,
	current_to_base: Array[int],
	base_to_draft: Array[int],
	reserved: Dictionary,
	used: Dictionary,
	allocator: Dictionary
) -> Array[int]:
	var result: Array[int] = []
	for current_index: int in current_objects.size():
		result.append(0)
	for current_index: int in current_objects.size():
		var base_index: int = current_to_base[current_index]
		if base_index < 0:
			continue
		var draft_index: int = base_to_draft[base_index]
		var sid: int = _sid_at(base, base_index)
		if draft_index >= 0 and draft_index < draft.sids.size():
			sid = draft.sids[draft_index]
		if sid < 1 or used.has(sid):
			sid = _allocate_sid(used, allocator)
		else:
			used[sid] = true
		result[current_index] = sid
	for current_index: int in current_objects.size():
		if result[current_index] > 0:
			continue
		var sid: int = _sid_at(current, current_index)
		if sid < 1 or reserved.has(sid) or used.has(sid):
			sid = _allocate_sid(used, allocator)
		else:
			used[sid] = true
		result[current_index] = sid
	return result


static func _first_free_sid(base: StudioDoc, draft: StudioDoc, current: StudioDoc) -> int:
	var next_sid: int = maxi(1, maxi(base.next_sid, maxi(draft.next_sid, current.next_sid)))
	for sid: int in base.sids:
		next_sid = maxi(next_sid, sid + 1)
	for sid: int in draft.sids:
		next_sid = maxi(next_sid, sid + 1)
	for sid: int in current.sids:
		next_sid = maxi(next_sid, sid + 1)
	return next_sid


static func _allocate_sid(used: Dictionary, allocator: Dictionary) -> int:
	var sid: int = int(allocator["next"])
	while sid < 1 or used.has(sid):
		sid += 1
	used[sid] = true
	allocator["next"] = sid + 1
	return sid
