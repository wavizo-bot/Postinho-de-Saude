extends RefCounted
## Navegação em grade com AStarGrid2D.
## Recebe retângulos caminháveis e bloqueios (paredes, mesas, balcões).
## O resultado é uma lista de pontos com curvas suavizadas por linha de visão.

var astar := AStarGrid2D.new()
var celula: float = 16.0
var mundo: Vector2 = Vector2(1600, 1000)
var colunas: int = 0
var linhas: int = 0
var pronto: bool = false


func configurar(tamanho_mundo: Vector2, areas: Array, bloqueios: Array, tamanho_celula: float = 16.0) -> void:
	mundo = tamanho_mundo
	celula = tamanho_celula
	colunas = maxi(1, int(ceil(mundo.x / celula)))
	linhas = maxi(1, int(ceil(mundo.y / celula)))
	astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, colunas, linhas)
	astar.cell_size = Vector2(celula, celula)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	for y in linhas:
		for x in colunas:
			var centro := Vector2((float(x) + 0.5) * celula, (float(y) + 0.5) * celula)
			var livre := false
			for r in areas:
				if (r as Rect2).has_point(centro):
					livre = true
					break
			if livre:
				for b in bloqueios:
					if (b as Rect2).has_point(centro):
						livre = false
						break
			if not livre:
				astar.set_point_solid(Vector2i(x, y), true)
	pronto = true


func caminho(de: Vector2, para: Vector2) -> Array:
	if not pronto:
		return [para]
	var a := _celula_livre_mais_proxima(_para_celula(de))
	var b := _celula_livre_mais_proxima(_para_celula(para))
	if a.x < 0 or b.x < 0:
		return [para]
	if a == b:
		return [para]
	var ids = astar.get_id_path(a, b, true)
	if ids == null or ids.is_empty():
		return [para]
	var pontos: Array = []
	for id in ids:
		pontos.append(Vector2((float(id.x) + 0.5) * celula, (float(id.y) + 0.5) * celula))
	if not pontos.is_empty():
		pontos[0] = de
		if not _celula_solida(_para_celula(para)):
			pontos[pontos.size() - 1] = para
	var suave: Array = []
	var i := 0
	while i < pontos.size():
		suave.append(pontos[i])
		var j: int = pontos.size() - 1
		while j > i + 1:
			if linha_livre(pontos[i], pontos[j]):
				break
			j -= 1
		if j <= i:
			i += 1
		else:
			i = j
	return suave


func ponto_livre(p: Vector2) -> bool:
	var c := _para_celula(p)
	if c.x < 0 or c.y < 0 or c.x >= colunas or c.y >= linhas:
		return false
	return not astar.is_point_solid(c)


func linha_livre(a: Vector2, b: Vector2) -> bool:
	var dist := a.distance_to(b)
	if dist < 1.0:
		return true
	var passos := maxi(2, int(ceil(dist / (celula * 0.42))))
	for i in passos + 1:
		var p := a.lerp(b, float(i) / float(passos))
		if not ponto_livre(p):
			return false
	return true


func _para_celula(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / celula)), int(floor(p.y / celula)))


func _celula_solida(id: Vector2i) -> bool:
	if id.x < 0 or id.y < 0 or id.x >= colunas or id.y >= linhas:
		return true
	return astar.is_point_solid(id)


func _celula_livre_mais_proxima(id: Vector2i) -> Vector2i:
	if not _celula_solida(id):
		return id
	var melhor := Vector2i(-1, -1)
	var melhor_dist := 1e20
	var raio := 1
	while raio <= 10:
		for dy in range(-raio, raio + 1):
			for dx in range(-raio, raio + 1):
				if absi(dx) != raio and absi(dy) != raio:
					continue
				var c := id + Vector2i(dx, dy)
				if _celula_solida(c):
					continue
				var d := float(dx * dx + dy * dy)
				if d < melhor_dist:
					melhor_dist = d
					melhor = c
		if melhor.x >= 0:
			return melhor
		raio += 1
	return Vector2i(-1, -1)
