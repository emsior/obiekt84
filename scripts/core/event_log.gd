## Dziennik zdarzeń symulacji.
##
## Wpis ma stały schemat {tick, subject, event, reason}. Kolejność wpisów wynika
## wyłącznie z kolejności faz ticka — nigdy z kolejności node'ów ani sygnałów.
class_name EventLog
extends RefCounted

const FIELD_SEPARATOR := "|"
const LINE_SEPARATOR := "\n"

var _entries: Array[Dictionary] = []


func append(tick: int, subject: String, event: String, reason: String) -> void:
	_entries.append({
		"tick": tick,
		"subject": subject,
		"event": event,
		"reason": reason,
	})


func clear() -> void:
	_entries.clear()


func size() -> int:
	return _entries.size()


func is_empty() -> bool:
	return _entries.is_empty()


## Niezależna kopia wpisów. Wywołujący nie może zmodyfikować logu.
func get_entries() -> Array[Dictionary]:
	var copy: Array[Dictionary] = []
	for entry: Dictionary in _entries:
		copy.append(entry.duplicate(true))
	return copy


## Ostatnie n wpisów jako kopia — dla warstwy prezentacji.
func get_last_entries(count: int) -> Array[Dictionary]:
	var from := maxi(0, _entries.size() - count)
	var copy: Array[Dictionary] = []
	for i in range(from, _entries.size()):
		copy.append(_entries[i].duplicate(true))
	return copy


## Kanoniczna, stabilna serializacja: jeden wiersz na zdarzenie,
## stała kolejność pól "tick|subject|event|reason".
## Nie polegamy na domyślnej serializacji Dictionary.
func to_canonical() -> String:
	var lines := PackedStringArray()
	for entry: Dictionary in _entries:
		lines.append(FIELD_SEPARATOR.join(PackedStringArray([
			str(entry["tick"]),
			String(entry["subject"]),
			String(entry["event"]),
			String(entry["reason"]),
		])))
	return LINE_SEPARATOR.join(lines)
