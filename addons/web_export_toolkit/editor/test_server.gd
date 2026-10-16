@tool
extends RefCounted
## Tiny web server for testing the web export locally.
## Serves one folder on 127.0.0.1, only for your own browser.
##
## Why not just open the index.html? Browsers dont load .wasm from file://,
## and with threads on you need the COOP/COEP headers. This does both.
## The dock calls poll() every frame, big files go out in chunks so the
## editor doesnt freeze.

const FIRST_PORT := 8070
const LAST_PORT := 8079
const CHUNK := 1 << 20 # 1 MB per connection and frame

const MIME := {
	"html": "text/html; charset=utf-8",
	"js": "application/javascript",
	"mjs": "application/javascript",
	"wasm": "application/wasm",
	"pck": "application/octet-stream",
	"png": "image/png",
	"svg": "image/svg+xml",
	"ico": "image/x-icon",
	"json": "application/json",
	"css": "text/css",
	"webp": "image/webp",
	"jpg": "image/jpeg",
}

var root := ""
var cross_origin_isolation := false
var port := 0

var _server: TCPServer
var _clients: Array[Dictionary] = []


## starts serving `folder`. returns false if no port was free
func start(folder: String, coop_coep: bool) -> bool:
	stop()
	root = folder.simplify_path()
	cross_origin_isolation = coop_coep
	_server = TCPServer.new()
	for p in range(FIRST_PORT, LAST_PORT + 1):
		if _server.listen(p, "127.0.0.1") == OK:
			port = p
			return true
	_server = null
	port = 0
	return false


func stop() -> void:
	for c in _clients:
		(c.peer as StreamPeerTCP).disconnect_from_host()
	_clients.clear()
	if _server:
		_server.stop()
	_server = null
	port = 0


func is_running() -> bool:
	return _server != null and _server.is_listening()


func url() -> String:
	return "http://127.0.0.1:%d/" % port


func poll() -> void:
	if not is_running():
		return
	while _server.is_connection_available():
		var peer := _server.take_connection()
		_clients.append({"peer": peer, "request": PackedByteArray(), "out": PackedByteArray(), "sent": 0, "age": 0.0})

	for c in _clients.duplicate():
		var peer: StreamPeerTCP = c.peer
		peer.poll()
		var status := peer.get_status()
		if status != StreamPeerTCP.STATUS_CONNECTED:
			_clients.erase(c)
			continue

		if c.out.is_empty():
			# still reading the request
			var available := peer.get_available_bytes()
			if available > 0:
				var got: Array = peer.get_partial_data(available)
				if got[0] == OK:
					c.request.append_array(got[1])
			var text: String = c.request.get_string_from_utf8()
			if "\r\n\r\n" in text:
				c.out = _answer(text)
			elif c.request.size() > 16384:
				_clients.erase(c)
				peer.disconnect_from_host()
			continue

		# sending
		var end := mini(c.sent + CHUNK, c.out.size())
		var res: Array = peer.put_partial_data(c.out.slice(c.sent, end))
		if res[0] != OK:
			_clients.erase(c)
			continue
		c.sent += int(res[1])
		if c.sent >= c.out.size():
			peer.disconnect_from_host()
			_clients.erase(c)


func _answer(request: String) -> PackedByteArray:
	var first := request.get_slice("\r\n", 0)
	var parts := first.split(" ")
	if parts.size() < 2 or not (parts[0] in ["GET", "HEAD"]):
		return _response(405, "text/plain", "Method not allowed".to_utf8_buffer())

	var path := parts[1].get_slice("?", 0).get_slice("#", 0).uri_decode()
	if path.ends_with("/"):
		path += "index.html"
	var file := (root + "/" + path.trim_prefix("/")).simplify_path()
	# dont let anyone walk out of the build folder with ../
	# (root + "/" so a sibling folder like build/web2 doesnt count as inside)
	if not file.begins_with(root + "/"):
		return _response(403, "text/plain", "Forbidden".to_utf8_buffer())
	if not FileAccess.file_exists(file):
		return _response(404, "text/plain", ("Not found: " + path).to_utf8_buffer())

	var body := FileAccess.get_file_as_bytes(file)
	var mime: String = MIME.get(file.get_extension().to_lower(), "application/octet-stream")
	if parts[0] == "HEAD":
		return _response(200, mime, PackedByteArray(), body.size())
	return _response(200, mime, body)


func _response(code: int, mime: String, body: PackedByteArray, length := -1) -> PackedByteArray:
	var reason := {200: "OK", 403: "Forbidden", 404: "Not Found", 405: "Method Not Allowed"}
	var head := "HTTP/1.1 %d %s\r\n" % [code, reason.get(code, "")]
	head += "Content-Type: %s\r\n" % mime
	head += "Content-Length: %d\r\n" % (body.size() if length < 0 else length)
	head += "Cache-Control: no-store\r\n"
	head += "Connection: close\r\n"
	if cross_origin_isolation:
		head += "Cross-Origin-Opener-Policy: same-origin\r\n"
		head += "Cross-Origin-Embedder-Policy: require-corp\r\n"
	head += "\r\n"
	var out := head.to_utf8_buffer()
	out.append_array(body)
	return out
