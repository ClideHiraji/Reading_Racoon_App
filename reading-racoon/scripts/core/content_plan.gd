class_name ContentPlan
extends RefCounted
## Teacher-picked content (D-020 game side, server D-019): checks the manifest from
## GET /api/content/manifest and plans which files to download and delete. Pure
## logic, unit-tested; Sync does the HTTP and the disk work.
## The server is trusted with what to show, never with where to write: every
## local path must sit directly in user://content/ with a plain file name.

const DIR := "user://content/"
const STATE := "user://content/state.json"
const EXTENSIONS := ["ogv", "png", "jpg", "jpeg"]
const KINDS := ["video"]


## True for "user://content/<name>.<ext>" with only letters, digits, - _ . in the name.
static func safe_local(path: String) -> bool:
	if not path.begins_with(DIR):
		return false
	var name := path.trim_prefix(DIR)
	if name == "" or name.contains("/") or name.contains("\\") or name.contains("..") or name.begins_with("."):
		return false
	for i in name.length():
		var c := name.unicode_at(i)
		var ok := (c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122) \
				or c == 45 or c == 46 or c == 95
		if not ok:
			return false
	return name.get_extension().to_lower() in EXTENSIONS


## A server path for a file ("/api/content/files/<uuid>"), never another host.
static func safe_url(url: String) -> bool:
	return url.begins_with("/api/content/files/") and not url.contains("..") and not url.contains("://")


static func _sha(value) -> String:
	var s := str(value).to_lower()
	if s.length() != 64:
		return ""
	for i in s.length():
		var c := s.unicode_at(i)
		if not ((c >= 48 and c <= 57) or (c >= 97 and c <= 102)):
			return ""
	return s


## The manifest's books and videos, keeping only well-formed items. A page picture
## or video with an unsafe path or bad hash loses its file (the page still shows
## its paper scene); a video without a safe file is dropped.
## Returns {books: [], watch: []}.
static func clean(manifest: Dictionary) -> Dictionary:
	var books := []
	for b in manifest.get("books", []):
		if typeof(b) != TYPE_DICTIONARY or str(b.get("id", "")) == "" or b.get("pages", []).is_empty():
			continue
		var book: Dictionary = b.duplicate(true)
		for p in book.pages:
			if p.has("image") and not (safe_local(str(p.image)) and safe_url(str(p.get("image_url", "")))
					and _sha(p.get("image_sha256", "")) != ""):
				p.erase("image")
				p.erase("image_url")
				p.erase("image_sha256")
		books.append(book)
	var watch := []
	for w in manifest.get("watch", []):
		if typeof(w) != TYPE_DICTIONARY or str(w.get("id", "")) == "" or str(w.get("kind", "")) not in KINDS:
			continue
		if not (safe_local(str(w.get("file", ""))) and safe_url(str(w.get("file_url", "")))
				and _sha(w.get("sha256", "")) != ""):
			continue
		watch.append(w.duplicate(true))
	return {"books": books, "watch": watch}


## Every file the cleaned manifest needs: [{local, url, sha256, size}].
static func files(cleaned: Dictionary) -> Array:
	var out := []
	for w in cleaned.get("watch", []):
		out.append({"local": str(w.file), "url": str(w.file_url), "sha256": _sha(w.sha256),
				"size": int(w.get("size_bytes", 0))})
	for b in cleaned.get("books", []):
		for p in b.pages:
			if p.has("image"):
				out.append({"local": str(p.image), "url": str(p.image_url), "sha256": _sha(p.image_sha256),
						"size": 0})
	return out


## Files to fetch: missing, or on disk with a different hash than the manifest's
## (the teacher replaced it). `have` = {local path: sha256 of the verified copy}.
static func to_download(needed: Array, have: Dictionary) -> Array:
	return needed.filter(func(f): return have.get(f.local, "") != f.sha256)


## SHA-256 of a file, read 1 MB at a time (Sync calls it on a worker for big videos).
static func file_sha256(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	while file.get_position() < file.get_length():
		ctx.update(file.get_buffer(1 << 20))
	return ctx.finish().hex_encode()


## Verified files no longer in the manifest (the item was removed or unpublished).
static func to_delete(needed: Array, have: Dictionary) -> Array:
	var keep := {}
	for f in needed:
		keep[f.local] = true
	return have.keys().filter(func(path): return not keep.has(path))
