extends Node2D
## Camada visual principal: desenha o postinho, controla a camera e encaminha
## cliques para o GameManager. As regras ficam todas em scripts/GameManager.gd.

const VisualScript = preload("res://scripts/Visual.gd")
const SonsScript = preload("res://scripts/Sons.gd")
const HudScript = preload("res://ui/Hud.gd")

const PREFS_PATH := "user://preferencias.json"
const ZOOM_MIN := 0.80
const ZOOM_MAX := 1.85
const ZOOM_INICIAL := 0.92
const TEMA_PADRAO := "classico"

var gm: Node
var hud: Control
var som: Node
var camera: Camera2D
var erro: String = ""

var paletas: Dictionary = {}
var paleta: Dictionary = {}
var prefs: Dictionary = {}
var velocidade_sim: float = 1.0
var _autosave_t: float = 0.0

var areas_pessoas: Array = []
var areas_pcs: Array = []
var areas_salas: Array = []
var areas_copas: Array = []
var areas_saidas: Array = []
var areas_laterais: Array = []
var areas_impressoras: Array = []

var _arrastando := false
var _pincando := false
var _moveu := false
var _inicio_tela := Vector2.ZERO
var _inicio_camera := Vector2.ZERO
var _pinch_dist := 1.0
var _pinch_zoom := 1.0
var _pinch_centro := Vector2.ZERO
var _pinch_camera := Vector2.ZERO
var _toques: Dictionary = {}
var _mouse_tela := Vector2(-100, -100)


func _ready() -> void:
	randomize()
	_criar_paletas()
	_carregar_prefs()
	paleta = paletas.get(str(prefs.get("tema", TEMA_PADRAO)), paletas[TEMA_PADRAO])
	gm = load("res://scripts/GameManager.gd").new()
	add_child(gm)
	if not gm.carregar_dados():
		erro = "\n".join(gm.erros_dados)
		queue_redraw()
		return
	gm.iniciar(-1)
	_aplicar_prefs()
	_criar_camera()
	som = SonsScript.new()
	add_child(som)
	_criar_hud()
	get_viewport().size_changed.connect(_ao_mudar_tela)
	camera.position = Vector2(720, 450)
	camera.zoom = Vector2(ZOOM_INICIAL, ZOOM_INICIAL)
	hud.tela_inicio = gm.tem_sessao()
	queue_redraw()


func _notification(que: int) -> void:
	if que == NOTIFICATION_WM_CLOSE_REQUEST:
		salvar_prefs()
		if gm != null and hud != null and not hud.tela_inicio:
			gm.salvar_sessao()


func _exit_tree() -> void:
	salvar_prefs()
	if gm != null and hud != null and not hud.tela_inicio:
		gm.salvar_sessao()


func continuar_sessao() -> void:
	if gm == null or hud == null:
		return
	if gm.carregar_sessao():
		hud.tela_inicio = false
		_aplicar_prefs()
		_autosave_t = 0.0
		camera.position = gm.pos
		hud.queue_redraw()
		queue_redraw()
	else:
		gm.alerta("Não foi possível continuar a sessão. Comece uma nova.", 4.0)


func nova_sessao() -> void:
	if gm == null or hud == null:
		return
	gm.iniciar(-1)
	hud.tela_inicio = false
	_aplicar_prefs()
	_autosave_t = 0.0
	camera.position = Vector2(720, 450)
	hud.queue_redraw()
	queue_redraw()
	gm.salvar_sessao()


func _ao_mudar_tela() -> void:
	if hud != null:
		hud.queue_redraw()


# =================================================================== preferencias

func _prefs_padrao() -> Dictionary:
	return {
		"tema": TEMA_PADRAO,
		"sons": true,
		"aparencia": {},
		"regras": {"velocidade": 1.0, "demandas": 1.0, "pacientes": 1.0, "paciencia": 1.0},
	}


func _carregar_prefs() -> void:
	prefs = _prefs_padrao()
	if not FileAccess.file_exists(PREFS_PATH):
		return
	var arq := FileAccess.open(PREFS_PATH, FileAccess.READ)
	if arq == null:
		return
	var texto := arq.get_as_text()
	arq.close()
	var dados = JSON.parse_string(texto)
	if not (dados is Dictionary):
		return
	for chave in dados.keys():
		if chave == "regras" and dados[chave] is Dictionary:
			for k in dados[chave].keys():
				prefs.regras[k] = dados[chave][k]
		elif chave == "aparencia" and dados[chave] is Dictionary:
			prefs.aparencia = dados[chave].duplicate(true)
		else:
			prefs[chave] = dados[chave]


func _aplicar_prefs() -> void:
	gm.sons_ligados = bool(prefs.get("sons", true))
	var r: Dictionary = prefs.get("regras", {})
	velocidade_sim = clampf(float(r.get("velocidade", 1.0)), 0.6, 1.6)
	gm.mult_demandas = clampf(float(r.get("demandas", 1.0)), 0.5, 2.0)
	gm.mult_pacientes = clampf(float(r.get("pacientes", 1.0)), 0.5, 2.0)
	gm.mult_paciencia = clampf(float(r.get("paciencia", 1.0)), 0.5, 2.0)
	var p: Dictionary = gm.jogador()
	var campos := ["pele", "roupa", "roupa2", "calca", "cabelo", "estilo_cabelo", "chapeu", "acessorio"]
	var ap: Dictionary = prefs.get("aparencia", {})
	if ap.is_empty():
		for k in campos:
			ap[k] = str(p.get(k, ""))
		prefs["aparencia"] = ap
	else:
		for k in ap.keys():
			if k in campos:
				p[k] = str(ap[k])


func salvar_prefs() -> void:
	if gm == null:
		return
	_sincronizar_aparencia()
	var arq := FileAccess.open(PREFS_PATH, FileAccess.WRITE)
	if arq == null:
		return
	arq.store_string(JSON.stringify(prefs, "  "))
	arq.close()


func _sincronizar_aparencia() -> void:
	if gm == null or not gm.entidades.has("jogador"):
		return
	var p: Dictionary = gm.jogador()
	var campos := ["pele", "roupa", "roupa2", "calca", "cabelo", "estilo_cabelo", "chapeu", "acessorio"]
	var ap: Dictionary = prefs.get("aparencia", {})
	for k in campos:
		ap[k] = str(p.get(k, ""))
	prefs["aparencia"] = ap


func aplicar_aparencia(chave: String, valor: String) -> void:
	if gm == null or not gm.entidades.has("jogador"):
		return
	var p: Dictionary = gm.jogador()
	p[chave] = valor
	if chave == "roupa":
		p["roupa2"] = Color(valor).lightened(0.48).to_html(false)
		prefs["aparencia"]["roupa2"] = p["roupa2"]
	prefs["aparencia"][chave] = valor
	salvar_prefs()
	queue_redraw()


func aplicar_tema(id: String) -> void:
	if not paletas.has(id):
		return
	prefs["tema"] = id
	paleta = paletas[id]
	salvar_prefs()
	if hud != null:
		hud.queue_redraw()
	queue_redraw()


func aplicar_regras(regras: Dictionary) -> void:
	var r: Dictionary = prefs.get("regras", {})
	for k in regras.keys():
		r[k] = regras[k]
	prefs["regras"] = r
	velocidade_sim = clampf(float(r.get("velocidade", 1.0)), 0.6, 1.6)
	if gm != null:
		gm.mult_demandas = clampf(float(r.get("demandas", 1.0)), 0.5, 2.0)
		gm.mult_pacientes = clampf(float(r.get("pacientes", 1.0)), 0.5, 2.0)
		gm.mult_paciencia = clampf(float(r.get("paciencia", 1.0)), 0.5, 2.0)
	salvar_prefs()


func aplicar_sons(ligados: bool) -> void:
	prefs["sons"] = ligados
	if gm != null:
		gm.sons_ligados = ligados
	if som != null:
		som.volume = 0.26 if ligados else 0.0
		if not ligados:
			som.vozes.clear()
	salvar_prefs()


func sair_jogo() -> void:
	salvar_prefs()
	get_tree().quit()


func centralizar_jogador() -> void:
	if camera == null or gm == null:
		return
	camera.position = gm.pos
	if camera.zoom.x < 1.0:
		camera.zoom = Vector2(1.0, 1.0)


func focar_impressora() -> void:
	if camera == null or gm == null or gm.impressora.is_empty():
		return
	camera.position = (gm.impressora.pos as Vector2) + Vector2(0, -58)
	if camera.zoom.x < 1.0:
		camera.zoom = Vector2(1.0, 1.0)
	queue_redraw()


# =================================================================== camera

func _criar_camera() -> void:
	camera = Camera2D.new()
	camera.name = "Camera"
	camera.enabled = true
	camera.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(gm.mundo.x)
	camera.limit_bottom = int(gm.mundo.y)
	camera.limit_smoothed = false
	camera.position = Vector2(720, 450)
	camera.zoom = Vector2(ZOOM_INICIAL, ZOOM_INICIAL)
	add_child(camera)


func _para_mundo(tela: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * tela


func _zoom_em(tela: Vector2, fator: float) -> void:
	if camera == null:
		return
	var antes := _para_mundo(tela)
	var z: float = clampf(camera.zoom.x * fator, ZOOM_MIN, ZOOM_MAX)
	camera.zoom = Vector2(z, z)
	var depois := _para_mundo(tela)
	camera.position += antes - depois
	queue_redraw()


# =================================================================== interface

func _criar_hud() -> void:
	var camada := CanvasLayer.new()
	camada.name = "Interface"
	camada.layer = 10
	add_child(camada)
	hud = HudScript.new()
	hud.name = "Hud"
	hud.main = self
	hud.gm = gm
	hud.prefs = prefs
	camada.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.queue_redraw()


# =================================================================== ciclo

func _process(delta: float) -> void:
	if erro != "":
		return
	delta = minf(delta, 0.20)
	if gm == null:
		return
	if som != null:
		for nome in gm.sons:
			som.tocar(str(nome))
		gm.sons.clear()
	if hud != null and not hud.pausado():
		gm.step(delta * velocidade_sim)
		_autosave_t += delta
		if _autosave_t >= gm.SAVE_A_CADA:
			_autosave_t = 0.0
			gm.salvar_sessao()
	if hud != null:
		hud.atualizar(delta)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if erro != "" or gm == null:
		return
	if hud != null and hud.ao_evento(event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		_ao_botao_mouse(event)
	elif event is InputEventMouseMotion:
		_ao_mover_mouse(event)
	elif event is InputEventScreenTouch:
		_ao_toque(event)
	elif event is InputEventScreenDrag:
		_ao_arrastar_toque(event)


func _ao_botao_mouse(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		if hud == null or not hud.ponto_em_ui(event.position):
			_zoom_em(event.position, 1.12)
		get_viewport().set_input_as_handled()
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		if hud == null or not hud.ponto_em_ui(event.position):
			_zoom_em(event.position, 0.89)
		get_viewport().set_input_as_handled()
	elif event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_iniciar_arrasto(event.position)
		else:
			_soltar_arrasto(event.position)


func _ao_mover_mouse(event: InputEventMouseMotion) -> void:
	_mouse_tela = event.position
	if _arrastando and not _pincando:
		var d := event.position - _inicio_tela
		if d.length() > 7.0:
			_moveu = true
		camera.position = _inicio_camera - d / camera.zoom.x
		queue_redraw()
	elif hud != null and not hud.ponto_em_ui(event.position):
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if _hit_mundo(event.position) else Input.CURSOR_ARROW)


func _iniciar_arrasto(p: Vector2) -> void:
	if hud != null and hud.ponto_em_ui(p):
		return
	_arrastando = true
	_pincando = false
	_moveu = false
	_inicio_tela = p
	_inicio_camera = camera.position


func _soltar_arrasto(p: Vector2) -> void:
	var era_arrasto := _arrastando
	var moveu := _moveu
	_arrastando = false
	_pincando = false
	if era_arrasto and not moveu:
		if hud != null and hud.ponto_em_ui(p):
			return
		_clique_mundo(p)


func _ao_toque(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if hud != null and hud.ponto_em_ui(event.position):
			return
		_toques[event.index] = event.position
		if _toques.size() == 1:
			_iniciar_arrasto(event.position)
		elif _toques.size() >= 2:
			_iniciar_pinca()
	else:
		var antes := _toques.size()
		_toques.erase(event.index)
		if antes == 1 and not _pincando:
			_soltar_arrasto(event.position)
		elif _pincando and _toques.size() < 2:
			_pincando = false
			_arrastando = false
	get_viewport().set_input_as_handled()


func _ao_arrastar_toque(event: InputEventScreenDrag) -> void:
	if _toques.has(event.index):
		_toques[event.index] = event.position
	if _toques.size() >= 2:
		_mover_pinca()
	elif _toques.size() == 1 and _arrastando:
		var p: Vector2 = _toques.values()[0]
		var d := p - _inicio_tela
		if d.length() > 7.0:
			_moveu = true
		camera.position = _inicio_camera - d / camera.zoom.x
	get_viewport().set_input_as_handled()


func _iniciar_pinca() -> void:
	if _toques.size() < 2:
		return
	var valores: Array = _toques.values()
	var a: Vector2 = valores[0]
	var b: Vector2 = valores[1]
	_pincando = true
	_moveu = true
	_pinch_dist = maxf(1.0, a.distance_to(b))
	_pinch_zoom = camera.zoom.x
	_pinch_centro = (a + b) * 0.5
	_pinch_camera = camera.position


func _mover_pinca() -> void:
	if _toques.size() < 2:
		return
	var valores: Array = _toques.values()
	var a: Vector2 = valores[0]
	var b: Vector2 = valores[1]
	var dist := maxf(1.0, a.distance_to(b))
	var centro := (a + b) * 0.5
	var z: float = clampf(_pinch_zoom * (dist / _pinch_dist), ZOOM_MIN, ZOOM_MAX)
	camera.zoom = Vector2(z, z)
	camera.position = _pinch_camera - (centro - _pinch_centro) / camera.zoom.x
	queue_redraw()


func _clique_mundo(tela: Vector2) -> void:
	var ponto := _para_mundo(tela)
	var id_pessoa := ""
	for i in range(areas_pessoas.size() - 1, -1, -1):
		var a: Dictionary = areas_pessoas[i]
		if ponto.distance_to(a.pos) <= float(a.raio):
			id_pessoa = str(a.id)
			break
	if id_pessoa != "":
		gm.clicar_pessoa(id_pessoa)
		return
	for a in areas_impressoras:
		if (a.rect as Rect2).has_point(ponto):
			gm.clicar_impressora()
			return
	for a in areas_pcs:
		if (a.rect as Rect2).has_point(ponto):
			gm.clicar_pc(str(a.id))
			return
	for a in areas_saidas:
		if ponto.distance_to(a.pos) <= float(a.raio):
			gm.clicar_saida()
			return
	for a in areas_laterais:
		if (a.rect as Rect2).has_point(ponto):
			gm.clicar_porta_lateral()
			return
	for a in areas_copas:
		if (a.rect as Rect2).has_point(ponto):
			gm.clicar_copa()
			return
	for a in areas_salas:
		if (a.rect as Rect2).has_point(ponto):
			gm.clicar_sala(str(a.id))
			return
	gm.clicar_chao(ponto)


func _hit_mundo(tela: Vector2) -> bool:
	var ponto := _para_mundo(tela)
	for a in areas_pessoas:
		if ponto.distance_to(a.pos) <= float(a.raio):
			return true
	for a in areas_impressoras:
		if (a.rect as Rect2).has_point(ponto):
			return true
	for a in areas_pcs:
		if (a.rect as Rect2).has_point(ponto):
			return true
	for a in areas_saidas:
		if ponto.distance_to(a.pos) <= float(a.raio):
			return true
	for a in areas_laterais:
		if (a.rect as Rect2).has_point(ponto):
			return true
	for a in areas_copas:
		if (a.rect as Rect2).has_point(ponto):
			return true
	for a in areas_salas:
		if (a.rect as Rect2).has_point(ponto):
			return true
	return false


# =================================================================== paletas

func _criar_paletas() -> void:
	paletas = {
		"classico": {
			"fundo": Color("#171d22"), "piso": Color("#d9d2c1"), "piso2": Color("#e7e0d0"),
			"piso3": Color("#cfc6b2"), "parede": Color("#f3eee2"), "parede_esc": Color("#b8ad97"),
			"borda": Color("#5f5848"), "sombra": Color("#0e1216"), "sala_mix": Color("#efe6d4"),
			"sala_peso": 0.12, "mesa": Color("#b48755"), "mesa_esc": Color("#7e5a34"),
			"cadeira": Color("#6f8f86"), "cadeira_esc": Color("#4c6760"), "tapete": Color("#c9b998"),
			"destaque": Color("#2f8f6b"), "destaque2": Color("#e7b24c"), "texto": Color("#2e2b25"),
			"vidro": Color("#a9d7df"), "planta": Color("#4f8a5b"), "planta2": Color("#6fae70"),
			"ui_painel": Color("#17212b"), "ui_painel2": Color("#22303d"), "ui_borda": Color("#53687a"),
			"ui_texto": Color("#f4f7fa"), "ui_fraco": Color("#a9bac8"), "ui_destaque": Color("#43c38d"),
			"ui_aviso": Color("#f0b44a"), "ui_perigo": Color("#e36a61"),
		},
		"moderno": {
			"fundo": Color("#111820"), "piso": Color("#c3d0d2"), "piso2": Color("#d5e0e1"),
			"piso3": Color("#aebdc1"), "parede": Color("#edf3f4"), "parede_esc": Color("#8ba0a7"),
			"borda": Color("#40525c"), "sombra": Color("#080d12"), "sala_mix": Color("#d7e7ea"),
			"sala_peso": 0.26, "mesa": Color("#9aa8ad"), "mesa_esc": Color("#5f7076"),
			"cadeira": Color("#4c7d8a"), "cadeira_esc": Color("#315a66"), "tapete": Color("#9bb7bb"),
			"destaque": Color("#1f8fa8"), "destaque2": Color("#5ac8d8"), "texto": Color("#223038"),
			"vidro": Color("#bce7ef"), "planta": Color("#3c7d69"), "planta2": Color("#60a98c"),
			"ui_painel": Color("#101c26"), "ui_painel2": Color("#1b2d3a"), "ui_borda": Color("#456777"),
			"ui_texto": Color("#f2fafc"), "ui_fraco": Color("#9fb9c5"), "ui_destaque": Color("#37c6d8"),
			"ui_aviso": Color("#f2c14e"), "ui_perigo": Color("#e2685f"),
		},
		"quente": {
			"fundo": Color("#221713"), "piso": Color("#e2c8a8"), "piso2": Color("#efd9bc"),
			"piso3": Color("#d4b38d"), "parede": Color("#f8ead8"), "parede_esc": Color("#c69f78"),
			"borda": Color("#6b4a34"), "sombra": Color("#160d09"), "sala_mix": Color("#f4ddc0"),
			"sala_peso": 0.20, "mesa": Color("#b97b45"), "mesa_esc": Color("#7d4a26"),
			"cadeira": Color("#a05f48"), "cadeira_esc": Color("#713d2e"), "tapete": Color("#d8ac7d"),
			"destaque": Color("#c26a3f"), "destaque2": Color("#f0b95e"), "texto": Color("#402a1f"),
			"vidro": Color("#cfe5e2"), "planta": Color("#698a4d"), "planta2": Color("#8fac61"),
			"ui_painel": Color("#251812"), "ui_painel2": Color("#38251c"), "ui_borda": Color("#7b5947"),
			"ui_texto": Color("#fff7ed"), "ui_fraco": Color("#d3bda9"), "ui_destaque": Color("#f0a85b"),
			"ui_aviso": Color("#f3c96a"), "ui_perigo": Color("#dd6655"),
		},
	}


func _p(chave: String) -> Color:
	return paleta.get(chave, Color("#ff00ff"))


# =================================================================== desenho

func _draw() -> void:
	areas_pessoas.clear()
	areas_pcs.clear()
	areas_salas.clear()
	areas_copas.clear()
	areas_saidas.clear()
	areas_laterais.clear()
	areas_impressoras.clear()
	if erro != "":
		_desenhar_erro()
		return
	if gm == null:
		return
	_desenhar_piso()
	_desenhar_salas()
	_desenhar_paredes_externas()
	_desenhar_mobilia_salas()
	_desenhar_placas_salas()
	_desenhar_recepcao()
	_desenhar_cadeiras_saguao()
	_desenhar_pcs()
	_desenhar_impressora()
	_desenhar_guiche()
	_desenhar_decoracao()
	_desenhar_portas_setas()
	_desenhar_pessoas()
	_desenhar_guiche_frente()
	_desenhar_baloes()
	_desenhar_marcador_jogador()


func _desenhar_erro() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), Color("#1a0e0e"), true)
	var f := ThemeDB.fallback_font
	draw_string(f, Vector2(34, 48), "Erro nos arquivos de dados:", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#ff8a8a"))
	var y := 78.0
	for linha in erro.split("\n"):
		draw_string(f, Vector2(34, y), linha, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#f4eaea"))
		y += 22.0


func _gradiente(r: Rect2, cima: Color, baixo: Color) -> void:
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	draw_polygon(PackedVector2Array([
		r.position,
		Vector2(r.end.x, r.position.y),
		r.end,
		Vector2(r.position.x, r.end.y),
	]), PackedColorArray([cima, cima, baixo, baixo]))


func _desenhar_piso() -> void:
	var m: Vector2 = gm.mundo
	draw_rect(Rect2(Vector2.ZERO, m), _p("fundo"), true)
	# Calcada e entorno.
	draw_rect(Rect2(0, 0, m.x, 24), Color("#0c1115"), true)
	draw_rect(Rect2(0, m.y - 24, m.x, 24), Color("#0c1115"), true)
	# Sombra em camadas para a construcao parecer apoiada no chao.
	draw_rect(gm.construcao.grow(20), Color(0, 0, 0, 0.13), true)
	draw_rect(gm.construcao.grow(9), Color(0, 0, 0, 0.34), true)
	_gradiente(gm.construcao, _p("parede_esc").lightened(0.07), _p("parede_esc").darkened(0.10))
	_gradiente(gm.construcao.grow(-10), _p("piso").lightened(0.035), _p("piso").darkened(0.05))
	# Piso do saguão com placas maiores e leve xadrez.
	_gradiente(gm.lobby, _p("piso2").lightened(0.035), _p("piso2").darkened(0.035))
	var col := 0
	var x: float = gm.lobby.position.x
	while x < gm.lobby.end.x:
		var lin := 0
		var y0: float = gm.lobby.position.y
		while y0 < gm.lobby.end.y:
			if (col + lin) % 2 == 0:
				draw_rect(Rect2(x, y0, minf(48.0, gm.lobby.end.x - x), minf(48.0, gm.lobby.end.y - y0)),
					Color(1, 1, 1, 0.045), true)
			lin += 1
			y0 += 48.0
		x += 48.0
		col += 1
	x = gm.lobby.position.x
	while x <= gm.lobby.end.x:
		draw_line(Vector2(x, gm.lobby.position.y), Vector2(x, gm.lobby.end.y), Color(1, 1, 1, 0.10), 1.0)
		x += 48.0
	var y: float = gm.lobby.position.y
	while y <= gm.lobby.end.y:
		draw_line(Vector2(gm.lobby.position.x, y), Vector2(gm.lobby.end.x, y), Color(0, 0, 0, 0.055), 1.0)
		y += 48.0
	# Corredor diante das salas, entre a ala clinica e o saguao.
	_gradiente(Rect2(326, 44, 192, 816), _p("piso").lightened(0.01), _p("piso").darkened(0.055))
	# Junta de piso e pilares marcam a transicao aberta para o saguao.
	draw_line(Vector2(520, 42), Vector2(520, 858), Color(0, 0, 0, 0.10), 3.0, true)
	draw_line(Vector2(522, 42), Vector2(522, 858), Color(1, 1, 1, 0.16), 1.5, true)
	# Retornos de parede curtos no topo e na base do vão: em planta, o vão
	# aberto entre corredor e saguão fica emoldurado pela própria alvenaria.
	_bloco_parede(Rect2(511, 38, 16, 20), _p("parede"), _p("parede_esc"))
	_bloco_parede(Rect2(511, 842, 16, 20), _p("parede"), _p("parede_esc"))
	# Luz morna entrando pela porta principal.
	var luz := Color(1.0, 0.93, 0.72)
	VisualScript.elipse(self, Vector2(1320, 132), 188.0, 92.0, Color(luz, 0.028))
	VisualScript.elipse(self, Vector2(1320, 124), 124.0, 58.0, Color(luz, 0.035))


func _desenhar_salas() -> void:
	for sala in gm.salas:
		var r := Rect2(sala.x, sala.y, sala.w, sala.h)
		var cor := Color(str(sala.cor)).lerp(_p("sala_mix"), float(paleta.get("sala_peso", 0.12)))
		# Sombra de contato mais funda: a sala se apoia no piso, não flutua.
		draw_rect(Rect2(r.position + Vector2(9, 11), r.size), Color(0, 0, 0, 0.12), true)
		draw_rect(Rect2(r.position + Vector2(4, 5), r.size), Color(0, 0, 0, 0.10), true)
		_gradiente(r, cor.lightened(0.05), cor.darkened(0.05))
		# Ladrilho clínico discreto, sem tapete.
		var passo := 28.0
		var yy := r.position.y + 14.0
		var linha := 0
		while yy < r.end.y - 12.0:
			var xx := r.position.x + 14.0
			var coluna := 0
			while xx < r.end.x - 12.0:
				if (linha + coluna) % 2 == 0:
					draw_rect(Rect2(xx, yy, minf(passo, r.end.x - 12.0 - xx), minf(passo, r.end.y - 12.0 - yy)),
						Color(1, 1, 1, 0.032), true)
				coluna += 1
				xx += passo
			linha += 1
			yy += passo
		# Oclusão interna nas bordas, reforçando o volume da sala.
		draw_rect(Rect2(r.position.x + 14, r.position.y + 14, r.size.x - 28, 7), Color(0, 0, 0, 0.06), true)
		draw_rect(Rect2(r.position.x + 14, r.end.y - 21, r.size.x - 28, 7), Color(0, 0, 0, 0.045), true)
		draw_rect(Rect2(r.position.x + 14, r.position.y + 14, 6, r.size.y - 28), Color(0, 0, 0, 0.04), true)
		# Paredes grossas com porta e batentes.
		_desenhar_paredes_sala(sala, r)
		if sala.tipo != "copa":
			areas_salas.append({"rect": r.grow(-6), "id": str(sala.id)})
		else:
			areas_copas.append({"rect": r.grow(-4)})


func _desenhar_placas_salas() -> void:
	var f := ThemeDB.fallback_font
	for sala in gm.salas:
		var r := Rect2(sala.x, sala.y, sala.w, sala.h)
		var nome := str(sala.nome)
		var largura := minf(r.size.x - 26.0, 132.0)
		var placa := Rect2(r.position + Vector2(13, 11), Vector2(largura, 21))
		draw_rect(Rect2(placa.position + Vector2(1, 2), placa.size), Color(0, 0, 0, 0.18), true)
		VisualScript.retangulo_arredondado(self, placa, Color(_p("borda"), 0.94), 6)
		draw_string(f, placa.position + Vector2(8, 15), nome, HORIZONTAL_ALIGNMENT_LEFT, placa.size.x - 12, 12, _p("parede"))


func _bloco_parede(r: Rect2, cor: Color, esc: Color) -> void:
	if r.size.x <= 0.5 or r.size.y <= 0.5:
		return
	# Sombra no piso, corpo e contorno grosso.
	draw_rect(Rect2(r.position + Vector2(3.5, 4.5), r.size), Color(0, 0, 0, 0.15), true)
	draw_rect(r, esc.darkened(0.24), true)
	draw_rect(r.grow(-1.4), cor, true)
	# Topo iluminado: lê como a espessura da parede vista de cima.
	var topo := clampf(r.size.y * 0.34, 2.0, 5.0)
	draw_rect(Rect2(r.position + Vector2(1.4, 1.4), Vector2(r.size.x - 2.8, topo)), cor.lightened(0.20), true)
	draw_rect(Rect2(r.position.x + 1.4, r.end.y - 3.0, r.size.x - 2.8, 1.7), esc.darkened(0.22), true)


func _desenhar_paredes_sala(sala: Dictionary, r: Rect2) -> void:
	var t := 12.0
	var cor := _p("parede")
	var esc := _p("parede_esc")
	var porta: Dictionary = sala.porta
	var centro := float(porta.get("centro", r.position.y + r.size.y * 0.5))
	var largura := float(porta.get("largura", 48.0))
	var topo := centro - largura * 0.5
	var base := centro + largura * 0.5
	var xdir := r.end.x - t
	# Oeste, norte e sul: paredes cheias, com espessura visível.
	_bloco_parede(Rect2(r.position.x, r.position.y, t, r.size.y), cor, esc)
	_bloco_parede(Rect2(r.position.x + t, r.position.y, r.size.x - t, t), cor, esc)
	_bloco_parede(Rect2(r.position.x + t, r.end.y - t, r.size.x - t, t), cor, esc)
	# Leste com o vão da porta.
	_bloco_parede(Rect2(xdir, r.position.y + t, t, maxf(0.0, topo - r.position.y - t)), cor, esc)
	_bloco_parede(Rect2(xdir, base, t, maxf(0.0, r.end.y - t - base)), cor, esc)
	# Soleira e batentes.
	draw_rect(Rect2(xdir, topo, t, base - topo), Color(esc.darkened(0.16), 0.34), true)
	draw_rect(Rect2(xdir - 2.5, topo - 5, 5, 5), esc.darkened(0.30), true)
	draw_rect(Rect2(xdir - 2.5, base, 5, 5), esc.darkened(0.30), true)
	draw_line(Vector2(xdir + t, topo), Vector2(xdir + t, base), Color(1, 1, 1, 0.20), 1.5, true)
	# Folha da porta aberta para o corredor: madeira, não uma tábua branca.
	var folha := PackedVector2Array([
		Vector2(xdir + t, topo),
		Vector2(xdir + t + 22, topo + 8),
		Vector2(xdir + t + 18, topo + 13),
		Vector2(xdir + t, topo + 4),
	])
	draw_colored_polygon(folha, Color(_p("mesa_esc").lightened(0.12), 0.96))
	draw_line(folha[1], folha[2], _p("borda").darkened(0.10), 1.2, true)
	draw_line(Vector2(xdir + t + 17, topo + 9), Vector2(xdir + t + 15, topo + 11), _p("borda"), 2.0, true)
	# Rodapé interno, onde o piso encontra a parede.
	draw_line(Vector2(r.position.x + t, r.end.y - t - 2), Vector2(xdir, r.end.y - t - 2),
		Color(0, 0, 0, 0.18), 2.0, true)


func _desenhar_paredes_externas() -> void:
	var c: Rect2 = gm.construcao
	var t := 16.0
	var cor := _p("parede")
	var esc := _p("parede_esc")
	var porta: Vector2 = gm._vet(gm.entrada.get("porta", [1320, 26]))
	# Topo com vão da entrada principal.
	_bloco_parede(Rect2(c.position.x, c.position.y, maxf(0.0, porta.x - 46 - c.position.x), t), cor, esc)
	_bloco_parede(Rect2(porta.x + 46, c.position.y, maxf(0.0, c.end.x - porta.x - 46), t), cor, esc)
	# Rodapé e laterais.
	_bloco_parede(Rect2(c.position.x, c.end.y - t, c.size.x, t), cor, esc)
	_bloco_parede(Rect2(c.position.x, c.position.y, t, c.size.y), cor, esc)
	var lat: Dictionary = gm.porta_lateral
	var lr: Rect2 = gm._rect_de(lat.get("rect"), Rect2(1406, 690, 18, 96))
	_bloco_parede(Rect2(c.end.x - t, c.position.y, t, maxf(0.0, lr.position.y - c.position.y)), cor, esc)
	_bloco_parede(Rect2(c.end.x - t, lr.end.y, t, maxf(0.0, c.end.y - lr.end.y)), cor, esc)
	# Portal de entrada: batentes, soleira e tapete de entrada curto.
	draw_rect(Rect2(porta.x - 46, c.position.y, 46, 26), Color(0, 0, 0, 0.10), true)
	draw_rect(Rect2(porta.x, c.position.y, 46, 26), Color(0, 0, 0, 0.10), true)
	draw_line(Vector2(porta.x - 46, c.position.y), Vector2(porta.x - 46, c.position.y + 26), esc.darkened(0.28), 4.0, true)
	draw_line(Vector2(porta.x + 46, c.position.y), Vector2(porta.x + 46, c.position.y + 26), esc.darkened(0.28), 4.0, true)
	draw_rect(Rect2(porta.x - 50, c.position.y + t, 100, 5), Color(0, 0, 0, 0.12), true)
	draw_colored_polygon(PackedVector2Array([
		Vector2(porta.x - 46, c.position.y), Vector2(porta.x + 46, c.position.y),
		Vector2(porta.x + 72, 164), Vector2(porta.x - 72, 164),
	]), Color(1.0, 0.93, 0.68, 0.10))
	# Portal lateral.
	draw_rect(Rect2(c.end.x - t, lr.position.y, t + 4, lr.size.y), Color(0, 0, 0, 0.12), true)
	draw_line(Vector2(c.end.x - 1, lr.position.y), Vector2(c.end.x - 1, lr.end.y), esc.darkened(0.28), 3.0, true)
	draw_line(Vector2(c.end.x - t, lr.position.y), Vector2(c.end.x, lr.position.y), esc.darkened(0.28), 3.0, true)
	draw_line(Vector2(c.end.x - t, lr.end.y), Vector2(c.end.x, lr.end.y), esc.darkened(0.28), 3.0, true)
	# Placa do postinho, na parede superior longe da entrada.
	var placa := Rect2(1010, 40, 232, 30)
	VisualScript.retangulo_arredondado(self, placa, Color(_p("destaque").darkened(0.18), 0.94), 8)
	VisualScript.contorno_arredondado(self, placa, Color(1, 1, 1, 0.18), 8, 1.5)
	_desenhar_cruz(placa.position + Vector2(20, 15), 7.5, _p("parede"))
	var f := ThemeDB.fallback_font
	draw_string(f, placa.position + Vector2(38, 20), "POSTINHO DE SAÚDE", HORIZONTAL_ALIGNMENT_LEFT, placa.size.x - 44, 14, _p("parede"))


func _desenhar_cruz(centro: Vector2, tam: float, cor: Color) -> void:
	draw_rect(Rect2(centro + Vector2(-tam * 0.28, -tam), Vector2(tam * 0.56, tam * 2)), cor, true)
	draw_rect(Rect2(centro + Vector2(-tam, -tam * 0.28), Vector2(tam * 2, tam * 0.56)), cor, true)


func _desenhar_mobilia_salas() -> void:
	for sala in gm.salas:
		var r := Rect2(sala.x, sala.y, sala.w, sala.h)
		match str(sala.tipo):
			"chefe":
				_desenhar_sala_chefe(r)
			"medica", "enfermeira":
				_desenhar_consultorio(r, str(sala.tipo))
			"vacina":
				_desenhar_sala_vacina(r)
			"procedimentos":
				_desenhar_sala_procedimentos(r)
			"copa":
				_desenhar_copa(r, sala)
		# Cadeiras de trabalho da sala (sem letras ou numeros).
		for i in sala.cadeiras.size():
			var pos: Vector2 = sala.cadeiras[i]
			var tem_pc := false
			for pc in gm.pcs:
				if pc.tipo == "sala" and str(pc.sala) == str(sala.id) and (pc.assento as Vector2).distance_to(pos) < 3.0:
					tem_pc = true
					break
			if not tem_pc:
				_desenhar_cadeira_escritorio(pos, true)


func _desenhar_sala_chefe(r: Rect2) -> void:
	# Armario e mesa da chefe.
	draw_rect(Rect2(r.position + Vector2(18, 42), Vector2(48, 74)), _p("mesa_esc").darkened(0.12), true)
	draw_rect(Rect2(r.position + Vector2(22, 46), Vector2(34, 2)), Color(1, 1, 1, 0.18), true)
	draw_rect(Rect2(r.position + Vector2(36, 62), Vector2(2, 6)), _p("mesa"), true)
	draw_rect(Rect2(r.position + Vector2(36, 82), Vector2(2, 6)), _p("mesa"), true)
	_desenhar_mesa(Rect2(r.position + Vector2(74, 56), Vector2(118, 40)))
	# Bandeira/quadro e planta.
	_desenhar_quadro(r.position + Vector2(82, 18), Vector2(38, 24), _p("destaque"))
	_desenhar_planta(r.position + Vector2(218, 116), 0.9)
	# Pasta e telefone sobre a mesa.
	draw_rect(Rect2(r.position + Vector2(108, 67), Vector2(24, 14)), _p("parede"), true)
	draw_rect(Rect2(r.position + Vector2(158, 64), Vector2(12, 16)), Color("#2d333b"), true)


func _desenhar_consultorio(r: Rect2, tipo: String) -> void:
	# Armario, pia e maca.
	draw_rect(Rect2(r.position + Vector2(172, 20), Vector2(50, 34)), _p("mesa_esc"), true)
	draw_rect(Rect2(r.position + Vector2(177, 25), Vector2(40, 2)), Color(1, 1, 1, 0.16), true)
	draw_rect(Rect2(r.position + Vector2(186, 38), Vector2(2, 6)), _p("mesa"), true)
	draw_rect(Rect2(r.position + Vector2(80, 109), Vector2(58, 22)), Color("#dfe8ea"), true)
	draw_rect(Rect2(r.position + Vector2(84, 112), Vector2(50, 6)), _p("vidro"), true)
	draw_circle(r.position + Vector2(110, 120), 3.0, _p("destaque").darkened(0.1))
	# Maca lateral.
	var maca := Rect2(r.position + Vector2(178, 104), Vector2(52, 30))
	draw_rect(maca.grow(2), Color(0, 0, 0, 0.12), true)
	draw_rect(maca, Color("#e8eef0"), true)
	draw_rect(Rect2(maca.position, Vector2(maca.size.x, 5)), _p("vidro"), true)
	draw_line(maca.position + Vector2(8, 0), maca.position + Vector2(8, maca.size.y), _p("cadeira_esc"), 2.0, true)
	# Quadro com cruz.
	var cor := _p("destaque") if tipo == "medica" else _p("destaque2")
	_desenhar_quadro(r.position + Vector2(18, 18), Vector2(38, 24), cor)
	# Prateleira de frascos.
	for i in 3:
		draw_circle(r.position + Vector2(36 + i * 12, 100), 4.0, Color("#d9eef2"))
		draw_rect(Rect2(r.position + Vector2(32 + i * 12, 100), Vector2(8, 8)), Color(0, 0, 0, 0.03), true)


func _desenhar_sala_vacina(r: Rect2) -> void:
	# Geladeira de vacinas.
	var gel := Rect2(r.position + Vector2(194, 22), Vector2(40, 64))
	draw_rect(gel.grow(2), Color(0, 0, 0, 0.12), true)
	draw_rect(gel, Color("#eef4f3"), true)
	draw_rect(Rect2(gel.position + Vector2(3, 3), Vector2(gel.size.x - 6, 24)), _p("vidro"), true)
	draw_line(gel.position + Vector2(0, 31), gel.position + Vector2(gel.size.x, 31), _p("cadeira_esc"), 1.5, true)
	draw_circle(gel.position + Vector2(33, 23), 1.6, _p("destaque"))
	# Bancada e frascos.
	_desenhar_balcao(Rect2(r.position + Vector2(64, 16), Vector2(102, 22)))
	for i in 5:
		draw_circle(r.position + Vector2(75 + i * 16, 27), 3.0, Color("#dff1f3"))
		draw_rect(Rect2(r.position + Vector2(73 + i * 16, 27), Vector2(4, 7)), Color("#c5dde0"), true)
	# Poltronas de vacinação nos lugares de atendimento.
	_desenhar_poltrona_clinica(r.position + Vector2(204, 82), Color("#cfe6ea"))
	_desenhar_poltrona_clinica(r.position + Vector2(204, 136), Color("#cfe6ea"))
	# Mesinha de apoio entre as poltronas.
	draw_rect(Rect2(r.position + Vector2(176, 104), Vector2(24, 18)), Color("#dfe8ea"), true)
	draw_circle(r.position + Vector2(188, 109), 2.6, Color("#f4fbfc"), true)
	draw_rect(Rect2(r.position + Vector2(185, 111), Vector2(6, 5)), Color("#c2dde1"), true)
	# Cartaz de gotinha.
	_desenhar_quadro(r.position + Vector2(26, 58), Vector2(36, 34), _p("destaque2"))
	draw_circle(r.position + Vector2(44, 72), 7.0, Color("#e8f7f9"))
	draw_circle(r.position + Vector2(44, 77), 4.0, _p("destaque"))


func _desenhar_sala_procedimentos(r: Rect2) -> void:
	# Maca de procedimentos.
	var maca := Rect2(r.position + Vector2(168, 20), Vector2(58, 34))
	draw_rect(maca.grow(2), Color(0, 0, 0, 0.12), true)
	draw_rect(maca, Color("#eef1f4"), true)
	draw_rect(Rect2(maca.position, Vector2(maca.size.x, 5)), Color("#c5cdd8"), true)
	# Bandeja e instrumentos.
	draw_rect(Rect2(r.position + Vector2(181, 28), Vector2(32, 12)), _p("vidro"), true)
	draw_line(r.position + Vector2(185, 34), r.position + Vector2(209, 34), _p("cadeira_esc"), 1.0, true)
	# Armario e pia.
	draw_rect(Rect2(r.position + Vector2(20, 22), Vector2(56, 74)), _p("mesa_esc").darkened(0.10), true)
	for i in 3:
		draw_line(r.position + Vector2(24, 38 + i * 18), r.position + Vector2(72, 38 + i * 18), Color(0, 0, 0, 0.18), 1.4, true)
		draw_circle(r.position + Vector2(66, 43 + i * 18), 1.5, _p("destaque2"))
	_desenhar_balcao(Rect2(r.position + Vector2(92, 20), Vector2(58, 22)))
	draw_rect(Rect2(r.position + Vector2(101, 27), Vector2(14, 8)), Color("#c7ecef"), true)
	draw_circle(r.position + Vector2(137, 31), 2.2, _p("destaque"))
	# Poltronas de procedimento e biombo.
	_desenhar_poltrona_clinica(r.position + Vector2(204, 74), Color("#d8dbe8"))
	_desenhar_poltrona_clinica(r.position + Vector2(204, 142), Color("#d8dbe8"))
	_desenhar_biombo(r.position + Vector2(166, 104))


func _desenhar_biombo(pos: Vector2) -> void:
	for i in 3:
		var p := pos + Vector2(float(i) * 9.0, float(i) * -5.0)
		draw_colored_polygon(PackedVector2Array([
			p + Vector2(0, 0), p + Vector2(9, -4), p + Vector2(9, 26), p + Vector2(0, 30),
		]), Color(_p("vidro").darkened(0.06 + 0.02 * i), 0.95))
		draw_line(p + Vector2(0, 0), p + Vector2(0, 30), _p("cadeira_esc"), 1.2, true)
		draw_line(p + Vector2(9, -4), p + Vector2(9, 26), _p("cadeira_esc"), 1.2, true)


func _desenhar_poltrona_clinica(pos: Vector2, cor: Color) -> void:
	# Encosto, assento e apoios, virada para o corredor da sala (oeste).
	draw_rect(Rect2(pos + Vector2(-24, 10), Vector2(36, 4)), Color(0, 0, 0, 0.12), true)
	VisualScript.retangulo_arredondado(self, Rect2(pos + Vector2(-22, -9), Vector2(30, 20)), cor, 6.0)
	VisualScript.retangulo_arredondado(self, Rect2(pos + Vector2(8, -14), Vector2(9, 30)), cor.darkened(0.22), 5.0)
	draw_rect(Rect2(pos + Vector2(-20, -13), Vector2(24, 4)), cor.lightened(0.06), true)
	draw_rect(Rect2(pos + Vector2(-20, 9), Vector2(24, 4)), cor.lightened(0.06), true)
	draw_rect(Rect2(pos + Vector2(-28, -4), Vector2(8, 10)), cor.darkened(0.08), true)
	draw_line(pos + Vector2(-18, -8), pos + Vector2(-18, 9), Color(1, 1, 1, 0.22), 1.2, true)


func _desenhar_copa(r: Rect2, sala: Dictionary) -> void:
	# Bancada e maquina de cafe.
	_desenhar_balcao(Rect2(r.position + Vector2(14, 14), Vector2(r.size.x - 28, 26)))
	var cafe: Vector2 = sala.cafe if sala.cafe != null else r.position + Vector2(66, 82)
	draw_rect(Rect2(cafe + Vector2(-13, -18), Vector2(26, 32)), Color("#34383f"), true)
	draw_rect(Rect2(cafe + Vector2(-10, -14), Vector2(20, 12)), Color("#d9dde2"), true)
	draw_rect(Rect2(cafe + Vector2(-8, 3), Vector2(16, 5)), Color("#181b20"), true)
	draw_circle(cafe + Vector2(0, -5), 3.0, _p("destaque2"))
	draw_rect(Rect2(cafe + Vector2(-10, 12), Vector2(20, 3)), _p("mesa_esc"), true)
	# Mesa e cadeiras.
	var mesa := Rect2(r.position + Vector2(38, 78), Vector2(92, 40))
	draw_rect(Rect2(mesa.position + Vector2(2, 4), mesa.size), Color(0, 0, 0, 0.14), true)
	VisualScript.retangulo_arredondado(self, mesa, _p("mesa"), 12)
	VisualScript.contorno_arredondado(self, mesa, _p("mesa_esc"), 12, 2)
	draw_circle(mesa.position + Vector2(23, 20), 5.0, Color("#f7f1e4"))
	draw_circle(mesa.position + Vector2(48, 20), 5.0, Color("#f7f1e4"))
	draw_circle(mesa.position + Vector2(72, 20), 5.0, Color("#f7f1e4"))
	_desenhar_cadeira_simples(mesa.position + Vector2(-10, 21))
	_desenhar_cadeira_simples(mesa.position + Vector2(mesa.size.x + 12, 21))
	# Bebedouro e planta.
	draw_rect(Rect2(r.position + Vector2(r.size.x - 46, 58), Vector2(24, 46)), Color("#e9eef1"), true)
	draw_rect(Rect2(r.position + Vector2(r.size.x - 42, 48), Vector2(16, 18)), _p("vidro"), true)
	_desenhar_planta(r.position + Vector2(r.size.x - 32, r.size.y - 26), 0.7)


func _desenhar_mesa(r: Rect2) -> void:
	draw_rect(Rect2(r.position + Vector2(2, 4), r.size), Color(0, 0, 0, 0.14), true)
	draw_rect(r, _p("mesa"), true)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 5)), _p("mesa").lightened(0.12), true)
	draw_rect(Rect2(r.position.x, r.end.y - 4, r.size.x, 4), _p("mesa_esc"), true)
	draw_rect(Rect2(r.position.x + 8, r.end.y, 4, 14), _p("mesa_esc"), true)
	draw_rect(Rect2(r.end.x - 12, r.end.y, 4, 14), _p("mesa_esc"), true)


func _desenhar_carrinho_clinico(r: Rect2) -> void:
	# Carrinho de apoio em inox: lê como estação clínica, não como escrivaninha.
	draw_rect(Rect2(r.position + Vector2(3, 5), r.size), Color(0, 0, 0, 0.14), true)
	draw_rect(r, Color("#dfe8ea"), true)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 4)), Color("#f3f7f8"), true)
	draw_line(Vector2(r.position.x, r.position.y + 8), Vector2(r.end.x, r.position.y + 8),
		Color("#9fb2b8"), 1.2, true)
	# Gaveta e puxador.
	var gav := Rect2(r.position + Vector2(9, 13), Vector2(30, maxf(10.0, r.size.y - 20)))
	draw_rect(gav, Color("#ccd8dc"), true)
	draw_rect(Rect2(gav.position + Vector2(0, 1.5), Vector2(gav.size.x, 1.4)), Color(1, 1, 1, 0.55), true)
	draw_rect(Rect2(gav.position + Vector2(11, gav.size.y - 4), Vector2(8, 1.8)), Color("#7f9198"), true)
	# Rodinhas.
	for x in [r.position.x + 9.0, r.end.x - 9.0]:
		draw_circle(Vector2(x, r.end.y + 4), 2.6, Color("#54656c"), true)
	# Bandeja com frascos do lado direito.
	draw_rect(Rect2(r.end.x - 40, r.position.y + 12, 30, 14), Color("#c3d9dd"), true)
	for i in 3:
		draw_circle(Vector2(r.end.x - 34 + i * 9, r.position.y + 19), 2.2, Color("#f2fbfc"), true)


func _desenhar_balcao(r: Rect2) -> void:
	draw_rect(Rect2(r.position + Vector2(0, 4), r.size), Color(0, 0, 0, 0.13), true)
	draw_rect(r, _p("mesa"), true)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 4)), _p("mesa").lightened(0.15), true)
	draw_rect(Rect2(r.position.x, r.end.y - 5, r.size.x, 5), _p("mesa_esc"), true)


func _desenhar_quadro(pos: Vector2, tam: Vector2, cor: Color) -> void:
	draw_rect(Rect2(pos + Vector2(2, 2), tam), Color(0, 0, 0, 0.12), true)
	draw_rect(Rect2(pos, tam), _p("parede"), true)
	draw_rect(Rect2(pos + Vector2(3, 3), tam - Vector2(6, 6)), cor.lightened(0.16), true)
	draw_line(pos + Vector2(6, tam.y - 6), pos + Vector2(tam.x - 9, 7), Color(1, 1, 1, 0.35), 2.0, true)


func _desenhar_planta(pos: Vector2, escala: float = 1.0) -> void:
	var s := escala
	VisualScript.elipse(self, pos + Vector2(4, 16) * s, 12.0 * s, 4.0 * s, Color(0.06, 0.07, 0.09, 0.20))
	# Vaso com brilho lateral.
	VisualScript.retangulo_arredondado(self, Rect2(pos + Vector2(-8.4, 4.4) * s, Vector2(16.8, 14.5) * s),
		Color("#8d4f31"), 3.0 * s)
	VisualScript.retangulo_arredondado(self, Rect2(pos + Vector2(-7.4, 5.0) * s, Vector2(14.8, 12.5) * s),
		Color("#a6633e"), 2.6 * s)
	draw_rect(Rect2(pos + Vector2(-9, 4) * s, Vector2(18, 4) * s), Color("#d18b5e"), true)
	draw_line(pos + Vector2(-8.4, 5.2) * s, pos + Vector2(8.4, 5.2) * s, Color(1, 1, 1, 0.22), 1.0 * s, true)
	for i in 6:
		var ang := -PI * 0.5 + (float(i) - 2.5) * 0.52
		var p := pos + Vector2(cos(ang), sin(ang)) * 12.0 * s
		draw_circle(p, 6.0 * s, _p("planta").darkened(0.06) if i % 2 == 0 else _p("planta2").darkened(0.04), true, -1.0, true)
		draw_circle(p + Vector2(-1.2, -1.8) * s, 3.2 * s, _p("planta").lightened(0.10) if i % 2 == 0 else _p("planta2").lightened(0.08), true, -1.0, true)
	draw_circle(pos + Vector2(0, -3) * s, 4.5 * s, _p("planta2").lightened(0.12), true, -1.0, true)


func _desenhar_recepcao() -> void:
	# Duas ilhas de trabalho. Sem tapete: só cantoneiras de piso, rótulos e o
	# divisor entre as colunas, como demarcação pintada de piso técnico.
	var cor := Color(_p("destaque").darkened(0.10), 0.55)
	var f := ThemeDB.fallback_font
	for faixa in [Rect2(558, 330, 188, 420), Rect2(746, 330, 160, 420)]:
		_cantoneiras_piso(faixa, cor, 12.0)
	draw_line(Vector2(746, 344), Vector2(746, 736), Color(_p("destaque").darkened(0.10), 0.30), 1.5, true)
	# Rótulos com um traço curto: leem como pintura de piso, não como móvel.
	for rotulo in [["ACS", Vector2(566, 323)], ["RECEPÇÃO", Vector2(754, 323)]]:
		var txt := str(rotulo[0])
		var p: Vector2 = rotulo[1]
		draw_string(f, p, txt, HORIZONTAL_ALIGNMENT_LEFT, 140, 12, Color(_p("destaque").darkened(0.18), 0.9))
		draw_line(p + Vector2(0, 5), p + Vector2(_largura_texto(txt, 12), 5), Color(_p("destaque").darkened(0.10), 0.35), 2.0, true)


func _cantoneiras_piso(r: Rect2, cor: Color, tam: float) -> void:
	for canto in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]:
		var dx := tam if canto.x <= r.position.x + 0.5 else -tam
		var dy := tam if canto.y <= r.position.y + 0.5 else -tam
		draw_line(canto, canto + Vector2(dx, 0), cor, 1.6, true)
		draw_line(canto, canto + Vector2(0, dy), cor, 1.6, true)


func _largura_texto(txt: String, tam: int) -> float:
	return ThemeDB.fallback_font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x


func _desenhar_cadeiras_saguao() -> void:
	for i in gm.cadeiras.size():
		var c: Dictionary = gm.cadeiras[i]
		_desenhar_cadeira_saguao(c.pos, str(c.ocupante) != "")


func _desenhar_cadeira_saguao(pos: Vector2, ocupada: bool) -> void:
	# Sombra e pernas.
	draw_rect(Rect2(pos + Vector2(-8, 8), Vector2(16, 3)), Color(0, 0, 0, 0.12), true)
	draw_line(pos + Vector2(-7, 1), pos + Vector2(-7, 10), _p("cadeira_esc"), 1.6, true)
	draw_line(pos + Vector2(7, 1), pos + Vector2(7, 10), _p("cadeira_esc"), 1.6, true)
	# Encosto e assento.
	var cor := _p("cadeira") if not ocupada else _p("cadeira").lightened(0.06)
	VisualScript.retangulo_arredondado(self, Rect2(pos + Vector2(-10, -7), Vector2(20, 5)), _p("cadeira_esc"), 2.5)
	VisualScript.retangulo_arredondado(self, Rect2(pos + Vector2(-9, -3), Vector2(18, 11)), cor, 3.5)
	draw_line(pos + Vector2(-9, 1), pos + Vector2(9, 1), Color(1, 1, 1, 0.18), 1.0, true)


func _desenhar_cadeira_escritorio(pos: Vector2, virada_direita: bool = true) -> void:
	draw_rect(Rect2(pos + Vector2(-8, 9), Vector2(16, 3)), Color(0, 0, 0, 0.13), true)
	draw_line(pos + Vector2(0, 3), pos + Vector2(0, 10), _p("cadeira_esc"), 2.2, true)
	draw_line(pos + Vector2(-6, 10), pos + Vector2(6, 10), _p("cadeira_esc"), 1.8, true)
	var encosto_x := -9.0 if virada_direita else 4.0
	VisualScript.retangulo_arredondado(self, Rect2(pos + Vector2(encosto_x, -13), Vector2(5, 20)), _p("cadeira_esc"), 2.5)
	VisualScript.retangulo_arredondado(self, Rect2(pos + Vector2(-8, -3), Vector2(16, 11)), _p("cadeira"), 4.0)


func _desenhar_cadeira_simples(pos: Vector2) -> void:
	draw_rect(Rect2(pos + Vector2(-7, 7), Vector2(14, 3)), Color(0, 0, 0, 0.12), true)
	draw_line(pos + Vector2(-5, 1), pos + Vector2(-5, 9), _p("cadeira_esc"), 1.4, true)
	draw_line(pos + Vector2(5, 1), pos + Vector2(5, 9), _p("cadeira_esc"), 1.4, true)
	VisualScript.retangulo_arredondado(self, Rect2(pos + Vector2(-8, -9), Vector2(16, 5)), _p("cadeira_esc"), 2.0)
	VisualScript.retangulo_arredondado(self, Rect2(pos + Vector2(-7, -4), Vector2(14, 9)), _p("cadeira"), 3.0)


func _desenhar_pcs() -> void:
	for pc in gm.pcs:
		var mesa: Rect2 = pc.mesa
		var tipo := str(pc.tipo)
		var cor_tela := _p("destaque")
		if str(pc.problema) == "grave":
			cor_tela = _p("ui_perigo")
		elif str(pc.problema) == "leve":
			cor_tela = _p("ui_aviso")
		if bool(pc.jogador):
			cor_tela = _p("ui_aviso")
		# Cadeira do funcionario/jogador.
		if tipo != "sala":
			_desenhar_cadeira_escritorio(pc.assento, true)
		# Mesa do posto ou carrinho clinico, conforme o tipo de sala.
		if tipo == "sala" and str(pc.sala) in ["D", "F"]:
			_desenhar_carrinho_clinico(mesa)
		else:
			_desenhar_mesa(mesa)
		# Monitor inclinado para o lado de quem senta (sul), com base na mesa.
		var centro: Vector2 = pc.pos
		var tela_poly := PackedVector2Array([
			centro + Vector2(-16, -17), centro + Vector2(16, -17),
			centro + Vector2(20, -2), centro + Vector2(-20, -2),
		])
		draw_colored_polygon(PackedVector2Array([
			tela_poly[0] + Vector2(2, 3), tela_poly[1] + Vector2(2, 3),
			tela_poly[2] + Vector2(2, 3), tela_poly[3] + Vector2(2, 3),
		]), Color(0, 0, 0, 0.18))
		draw_colored_polygon(tela_poly, Color("#20262c"))
		draw_colored_polygon(PackedVector2Array([
			centro + Vector2(-13, -14), centro + Vector2(13, -14),
			centro + Vector2(16, -4), centro + Vector2(-16, -4),
		]), cor_tela.darkened(0.22))
		draw_rect(Rect2(centro + Vector2(-2.5, -2), Vector2(5, 4)), Color("#20262c"), true)
		draw_rect(Rect2(centro + Vector2(-8, 1), Vector2(16, 3)), Color("#20262c"), true)
		draw_line(centro + Vector2(-10, -11), centro + Vector2(-10, -5), Color(1, 1, 1, 0.25), 1.0, true)
		draw_rect(Rect2(centro + Vector2(-5, -10), Vector2(9, 2)), Color(1, 1, 1, 0.45), true)
		# Teclado horizontal, centrado no lado longo da mesa.
		var teclado := Rect2(Vector2(pc.pos.x - 17.0, mesa.end.y - 10.0), Vector2(34, 8))
		draw_rect(Rect2(teclado.position + Vector2(1, 1), teclado.size), Color(0, 0, 0, 0.14), true)
		draw_rect(teclado, Color("#d5dbe0"), true)
		for i in 3:
			draw_line(teclado.position + Vector2(2, 1.4 + i * 2.0), teclado.position + Vector2(teclado.size.x - 2, 1.4 + i * 2.0),
				Color(0, 0, 0, 0.13), 0.7, true)
		# Indicador de problema/ocupacao.
		if str(pc.problema) != "":
			var pulso := 0.5 + 0.5 * sin(gm.tempo * 8.0)
			draw_circle(centro + Vector2(16, -18), 3.2, Color(_p("ui_perigo") if str(pc.problema) == "grave" else _p("ui_aviso"), 0.55 + pulso * 0.35))
			draw_line(centro + Vector2(14, -20), centro + Vector2(18, -16), Color("#fff8e8"), 1.2, true)
			draw_line(centro + Vector2(18, -20), centro + Vector2(14, -16), Color("#fff8e8"), 1.2, true)
		if tipo == "recepcao":
			# Cadeira de atendimento do paciente.
			if pc.atendimento != null:
				_desenhar_cadeira_atendimento(pc.atendimento)
		# Area de clique ampla, sem invadir a coluna vizinha.
		var area := Rect2(mesa.position - Vector2(10, 10),
			Vector2(mesa.size.x + 20, (pc.assento as Vector2).y - mesa.position.y + 30))
		areas_pcs.append({"rect": area, "id": str(pc.id)})


func _desenhar_cadeira_atendimento(pos: Vector2) -> void:
	draw_rect(Rect2(pos + Vector2(-8, 9), Vector2(16, 3)), Color(0, 0, 0, 0.11), true)
	draw_line(pos + Vector2(-7, 2), pos + Vector2(-7, 10), _p("cadeira_esc"), 1.6, true)
	draw_line(pos + Vector2(7, 2), pos + Vector2(7, 10), _p("cadeira_esc"), 1.6, true)
	VisualScript.retangulo_arredondado(self, Rect2(pos + Vector2(-8, -3), Vector2(16, 10)), _p("cadeira").lightened(0.08), 3.5)
	VisualScript.retangulo_arredondado(self, Rect2(pos + Vector2(4, -11), Vector2(5, 12)), _p("cadeira_esc"), 2.0)


func _desenhar_impressora() -> void:
	if gm.impressora.is_empty():
		return
	var pos: Vector2 = gm.impressora.pos
	# Mesinha de apoio encostada na parede.
	draw_rect(Rect2(pos + Vector2(-31, 7), Vector2(62, 6)), Color(0, 0, 0, 0.16), true)
	draw_rect(Rect2(pos + Vector2(-28, 12), Vector2(56, 24)), _p("mesa_esc"), true)
	draw_rect(Rect2(pos + Vector2(-28, 12), Vector2(56, 4)), _p("mesa"), true)
	# Corpo da impressora.
	draw_rect(Rect2(pos + Vector2(-22, -17), Vector2(44, 27)), Color("#e7ebee"), true)
	draw_rect(Rect2(pos + Vector2(-22, -17), Vector2(44, 5)), Color("#f7fafb"), true)
	draw_rect(Rect2(pos + Vector2(-18, -11), Vector2(25, 7)), Color("#cfd8dd"), true)
	draw_rect(Rect2(pos + Vector2(9, -12), Vector2(8, 7)), Color("#9fb0b8"), true)
	draw_rect(Rect2(pos + Vector2(-13, 10), Vector2(26, 8)), Color("#c8d2d7"), true)
	draw_rect(Rect2(pos + Vector2(-10, 12), Vector2(20, 4)), Color("#fbfcfc"), true)
	# Gaveta e luz de status.
	if bool(gm.impressora.get("quebrada", false)):
		var pulso := 0.5 + 0.5 * sin(gm.tempo * 9.0)
		draw_circle(pos + Vector2(15, -14), 2.6 + pulso * 1.2, Color(_p("ui_perigo"), 0.55 + pulso * 0.4))
		draw_line(pos + Vector2(-6, -24), pos + Vector2(-2, -29), Color(_p("ui_perigo"), 0.8), 1.5, true)
		draw_line(pos + Vector2(2, -23), pos + Vector2(6, -28), Color(_p("ui_aviso"), 0.8), 1.5, true)
		# Papel amassado saindo da bandeja.
		draw_colored_polygon(PackedVector2Array([
			pos + Vector2(-10, 9), pos + Vector2(-2, 6), pos + Vector2(3, 16),
			pos + Vector2(-4, 21), pos + Vector2(-13, 15),
		]), Color("#f6f2e6"))
		draw_string(ThemeDB.fallback_font, pos + Vector2(-37, 50), "CONSERTAR", HORIZONTAL_ALIGNMENT_LEFT, 80, 9, Color(_p("ui_perigo").darkened(0.15)))
	else:
		draw_circle(pos + Vector2(15, -14), 2.2, Color(_p("destaque"), 0.9))
	areas_impressoras.append({"rect": Rect2(pos + Vector2(-36, -32), Vector2(74, 78))})


func _desenhar_guiche() -> void:
	var g: Dictionary = gm.guiche
	var r := Rect2(float(g.get("x", 862)), float(g.get("y", 118)), float(g.get("w", 226)), float(g.get("h", 46)))
	# Sombra e corpo do balcao.
	draw_rect(Rect2(r.position + Vector2(3, 5), r.size), Color(0, 0, 0, 0.18), true)
	draw_rect(r, _p("mesa"), true)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 6)), _p("mesa").lightened(0.18), true)
	draw_rect(Rect2(r.position.x, r.end.y - 8, r.size.x, 8), _p("mesa_esc"), true)
	# Vidro de protecao.
	draw_rect(Rect2(r.position + Vector2(10, -18), Vector2(r.size.x - 20, 18)), Color(_p("vidro"), 0.28), true)
	draw_line(r.position + Vector2(10, -18), r.position + Vector2(10, 0), _p("vidro").darkened(0.22), 2.0, true)
	draw_line(r.position + Vector2(r.size.x - 10, -18), r.position + Vector2(r.size.x - 10, 0), _p("vidro").darkened(0.22), 2.0, true)
	draw_line(r.position + Vector2(10, -18), r.position + Vector2(r.size.x - 10, -18), _p("vidro").darkened(0.15), 1.5, true)
	# Monitor e telefone.
	draw_rect(Rect2(r.position + Vector2(26, 10), Vector2(32, 21)), Color("#20262c"), true)
	draw_rect(Rect2(r.position + Vector2(29, 13), Vector2(26, 15)), _p("destaque").darkened(0.28), true)
	draw_rect(Rect2(r.position + Vector2(32, 16), Vector2(8, 2)), Color(1, 1, 1, 0.55), true)
	draw_rect(Rect2(r.position + Vector2(32, 20), Vector2(12, 2)), Color(1, 1, 1, 0.32), true)
	draw_rect(Rect2(r.position + Vector2(72, 14), Vector2(17, 12)), _p("cadeira_esc"), true)
	draw_rect(Rect2(r.position + Vector2(77, 17), Vector2(7, 3)), _p("parede"), true)
	# Suporte de senhas.
	draw_rect(Rect2(r.position + Vector2(r.size.x - 46, 10), Vector2(24, 25)), Color("#e8eef0"), true)
	draw_rect(Rect2(r.position + Vector2(r.size.x - 43, 13), Vector2(18, 8)), _p("ui_perigo").darkened(0.1), true)
	draw_circle(r.position + Vector2(r.size.x - 34, 29), 3.0, Color("#b8c8cf"))
	# Marcas de fila no piso.
	var fila: Array = g.get("fila", [])
	for i in fila.size():
		var fp: Vector2 = gm._vet(fila[i])
		draw_circle(fp, 9.0, Color(_p("destaque"), 0.06))
		draw_arc(fp, 9.0, 0.0, TAU, 18, Color(_p("destaque"), 0.24), 1.0, true)


func _desenhar_guiche_frente() -> void:
	var g: Dictionary = gm.guiche
	var r := Rect2(float(g.get("x", 862)), float(g.get("y", 118)), float(g.get("w", 226)), float(g.get("h", 46)))
	# Faixa frontal do balcao fica por cima das pernas de quem atende.
	draw_rect(Rect2(r.position.x + 3, r.position.y + r.size.y - 27, r.size.x - 6, 19), _p("mesa").darkened(0.04), true)
	var f := ThemeDB.fallback_font
	draw_string(f, Vector2(r.position.x, r.end.y - 10), "GUICHÊ", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 11, Color(1, 1, 1, 0.72))
	# Fila de espera com pegadas discretas.
	draw_circle(Vector2(975, 222), 5.0, Color(_p("destaque"), 0.20))


func _desenhar_decoracao() -> void:
	for d in gm.layout.get("decoracao", []):
		var pos := Vector2(float(d.get("x", 0)), float(d.get("y", 0)))
		match str(d.get("tipo", "")):
			"planta":
				_desenhar_planta(pos, 0.95)
			"bebedouro":
				draw_rect(Rect2(pos + Vector2(-13, -6), Vector2(26, 40)), Color("#eaf0f2"), true)
				draw_rect(Rect2(pos + Vector2(-9, -18), Vector2(18, 16)), _p("vidro"), true)
				draw_circle(pos + Vector2(0, -10), 5.0, Color("#bfe4f0"))
				draw_rect(Rect2(pos + Vector2(-6, 22), Vector2(12, 4)), _p("cadeira_esc"), true)
			"quadro":
				_desenhar_quadro(pos, Vector2(48, 32), _p("destaque2"))
			"lixeira":
				draw_rect(Rect2(pos + Vector2(-9, -7), Vector2(18, 24)), Color("#4c5961"), true)
				draw_rect(Rect2(pos + Vector2(-11, -9), Vector2(22, 4)), Color("#65737b"), true)
			"relogio":
				draw_circle(pos, 16.0, _p("parede"), true)
				draw_arc(pos, 16.0, 0.0, TAU, 28, _p("cadeira_esc"), 2.2, true)
				var ang: float = gm.tempo * 0.12
				draw_line(pos, pos + Vector2(cos(ang - PI * 0.5), sin(ang - PI * 0.5)) * 9.0, _p("texto"), 1.6, true)
				draw_line(pos, pos + Vector2(cos(ang * 4.0), sin(ang * 4.0)) * 6.0, _p("ui_perigo"), 1.0, true)
				draw_circle(pos, 1.6, _p("texto"))


func _desenhar_portas_setas() -> void:
	var seta: Vector2 = gm._vet(gm.entrada.get("seta_saida", [1462, 170]))
	var fase := fmod(gm.tempo * 1.25, 1.0)
	for i in 3:
		var y := seta.y + 26.0 - float(i) * 15.0 - fase * 15.0
		var alfa := 0.26 + 0.20 * (1.0 - absf(fase - 0.5) * 2.0)
		draw_line(Vector2(seta.x - 11, y + 7), Vector2(seta.x, y), Color(_p("parede"), alfa), 3.0, true)
		draw_line(Vector2(seta.x + 11, y + 7), Vector2(seta.x, y), Color(_p("parede"), alfa), 3.0, true)
	areas_saidas.append({"pos": seta + Vector2(0, 8), "raio": 32.0})
	# Porta lateral.
	var lat: Dictionary = gm.porta_lateral
	var lr: Rect2 = gm._rect_de(lat.get("rect"), Rect2(1542, 452, 18, 96))
	var setaL: Vector2 = gm._vet(lat.get("seta", [1494, 500]))
	var fl := fmod(gm.tempo * 1.25, 1.0)
	for i in 3:
		var x := setaL.x + float(i) * 14.0 + fl * 14.0
		draw_line(Vector2(x, setaL.y - 11), Vector2(x + 9, setaL.y), Color(_p("parede"), 0.34), 3.0, true)
		draw_line(Vector2(x, setaL.y + 11), Vector2(x + 9, setaL.y), Color(_p("parede"), 0.34), 3.0, true)
	areas_laterais.append({"rect": lr.grow(28)})
	# Ampolas de aviso (futuro) sem texto.
	_desenhar_ampulheta(seta + Vector2(31, 6))
	_desenhar_ampulheta(setaL + Vector2(0, -29))


func _desenhar_ampulheta(pos: Vector2) -> void:
	var cor := Color(_p("ui_aviso"), 0.78)
	draw_line(pos + Vector2(-4, -6), pos + Vector2(4, -6), cor, 1.3, true)
	draw_line(pos + Vector2(-4, 6), pos + Vector2(4, 6), cor, 1.3, true)
	draw_line(pos + Vector2(-4, -6), pos + Vector2(0, 0), cor, 1.1, true)
	draw_line(pos + Vector2(4, -6), pos + Vector2(0, 0), cor, 1.1, true)
	draw_line(pos + Vector2(-4, 6), pos + Vector2(0, 0), cor, 1.1, true)
	draw_line(pos + Vector2(4, 6), pos + Vector2(0, 0), cor, 1.1, true)
	draw_circle(pos + Vector2(0, 3), 2.0, cor)


func _desenhar_pessoas() -> void:
	var lista: Array = gm.pessoas.duplicate()
	lista.sort_custom(func(a, b): return float(a.pos.y) < float(b.pos.y))
	for p in lista:
		if not p.visivel or p.oculto:
			continue
		VisualScript.pessoa(self, p, gm.tempo, 1.0, bool(p.em_esforco))
		var raio := 16.5 * float(p.get("escala", 1.0))
		if p.tipo == "crianca":
			raio = 12.0
		areas_pessoas.append({"pos": p.pos, "raio": raio + 4.0, "id": str(p.id)})


func _desenhar_marcador_jogador() -> void:
	var pj = gm.entidades.get("jogador", null)
	if pj == null or not pj.visivel or pj.oculto:
		return
	var base: Vector2 = pj.pos
	if gm.estado == gm.Estado.NO_PC:
		return
	var pulo := sin(gm.tempo * 3.2) * 2.2
	var topo := base + Vector2(0, -43.0 + pulo)
	draw_colored_polygon(PackedVector2Array([
		topo + Vector2(-6, -7), topo + Vector2(6, -7), topo + Vector2(0, 1),
	]), Color(_p("ui_aviso"), 0.90))
	draw_colored_polygon(PackedVector2Array([
		topo + Vector2(-4, -6), topo + Vector2(4, -6), topo + Vector2(0, -1),
	]), Color(1, 1, 1, 0.55))


func _desenhar_baloes() -> void:
	for p in gm.pessoas:
		if not p.visivel or p.oculto:
			continue
		if str(p.balao_tipo) == "":
			continue
		if p.demanda == null and float(p.balao_ate) <= 0.0:
			continue
		VisualScript.balao(self, p, str(p.balao_tipo), gm.tempo, 1.0)
