extends Control
## Interface do jogo: HUD, janela de demandas e menu completo.
## Desenha tudo em coordenadas de tela (1280x720 no projeto) e consome o
## input quando ha menu ou dialogo aberto. Só a tela inicial e o menu param a
## simulação: conversas e consertos acontecem com o posto rodando.

const VisualScript = preload("res://scripts/Visual.gd")

const URL_PLAY := "https://github.com/wavizo-bot/Postinho-de-Saude/releases/latest"
const URL_CONTATO := "mailto:mmr05@hotmail.com?subject=Postinho%20de%20Sa%C3%BAde"

const ROTULOS := {
	"nenhum": "Sem", "bone": "Boné", "touca": "Touca", "chapeu_praia": "Praia",
	"laco": "Laço", "coroa": "Coroa", "orelhas": "Orelhas", "capacete": "Cap.",
	"boina": "Boina", "oculos": "Óculos", "mascara": "Máscara", "bolsa": "Bolsa",
	"cachecol": "Cachecol", "curto": "Curto", "franja": "Franja", "coque": "Coque",
	"longo": "Longo", "cacheado": "Cacheado", "calvo": "Calvo",
}

var main: Node
var gm: Node
var prefs: Dictionary = {}

var tela_inicio := false
var menu_aberto := false
var pagina := "home"
var hover := ""
var pressionado := ""
var toque_indice := -1
var t := 0.0
var mouse := Vector2(-100, -100)

var botoes: Array = []
var areas_ui: Array = []
## Último texto informativo do HUD; os testes usam para garantir que não
## voltou contador de PCs nem relógio de sessão.
var info_hud := ""

var _fonte: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fonte = ThemeDB.fallback_font
	set_process(true)


# =================================================================== estado

func pausado() -> bool:
	if gm == null:
		return false
	# Conversas, exames e consertos não param o posto. Nada aqui é irremediável.
	return tela_inicio or menu_aberto


func atualizar(dt: float) -> void:
	t += dt
	queue_redraw()


func ponto_em_ui(p: Vector2) -> bool:
	if tela_inicio or menu_aberto or (gm != null and gm.modal != null):
		return true
	for a in areas_ui:
		if (a as Rect2).has_point(p):
			return true
	for b in botoes:
		if (b.rect as Rect2).has_point(p):
			return true
	return false


func _botao_em(p: Vector2) -> String:
	var i := botoes.size() - 1
	while i >= 0:
		var b: Dictionary = botoes[i]
		if (b.rect as Rect2).has_point(p):
			return str(b.id)
		i -= 1
	return ""


func _registrar(id: String, r: Rect2) -> void:
	botoes.append({"id": id, "rect": r})


func _registrar_ui(r: Rect2) -> void:
	areas_ui.append(r)


# =================================================================== entrada

func ao_evento(event: InputEvent) -> bool:
	if gm == null:
		return false
	if event is InputEventKey:
		var tecla := event as InputEventKey
		if tecla.pressed and not tecla.echo and (tecla.keycode == KEY_ESCAPE or tecla.keycode == KEY_BACK):
			if gm.modal != null:
				gm.fechar_dialogo()
			elif menu_aberto:
				if pagina == "home":
					menu_aberto = false
				else:
					pagina = "home"
			return true
		return false
	if event is InputEventMouseMotion:
		mouse = event.position
		hover = _botao_em(event.position)
		if ponto_em_ui(event.position):
			Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if hover != "" else Input.CURSOR_ARROW)
		return menu_aberto or gm.modal != null
	if event is InputEventMouseButton:
		return _ao_botao(event)
	if event is InputEventScreenTouch:
		return _ao_toque(event)
	if event is InputEventScreenDrag:
		return menu_aberto or gm.modal != null
	return false


func _ao_botao(event: InputEventMouseButton) -> bool:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return ponto_em_ui(event.position)
	if event.pressed:
		var id := _botao_em(event.position)
		if id != "":
			pressionado = id
			hover = id
			return true
		return ponto_em_ui(event.position)
	if pressionado != "":
		var alvo := _botao_em(event.position)
		var era := pressionado
		pressionado = ""
		if alvo == era:
			_acionar(alvo)
		return true
	return ponto_em_ui(event.position)


func _ao_toque(event: InputEventScreenTouch) -> bool:
	if event.pressed:
		var id := _botao_em(event.position)
		if id != "":
			pressionado = id
			hover = id
			toque_indice = event.index
			return true
		return ponto_em_ui(event.position)
	if event.index == toque_indice:
		var alvo := _botao_em(event.position)
		var era := pressionado
		pressionado = ""
		toque_indice = -1
		if alvo == era and alvo != "":
			_acionar(alvo)
		return true
	return ponto_em_ui(event.position)


func _acionar(id: String) -> void:
	if id == "":
		return
	if id.begins_with("ap:"):
		var partes := id.split(":")
		if partes.size() >= 3:
			var valor := ":".join(partes.slice(2))
			main.aplicar_aparencia(partes[1], valor)
		return
	if id.begins_with("minijogo:"):
		gm.minijogo_escolher(int(id.substr(9)))
		return
	if id.begins_with("exame:"):
		gm.exame_escolher(int(id.substr(6)))
		return
	if id.begins_with("tema:"):
		main.aplicar_tema(id.substr(5))
		return
	if id.begins_with("regra:ritmo:"):
		main.aplicar_regras({"velocidade": float(id.substr(12))})
		return
	if id.begins_with("regra:mult:"):
		var partes := id.split(":")
		if partes.size() >= 4:
			var chave := str(partes[2])
			var sinal := str(partes[3])
			var r: Dictionary = prefs.get("regras", {})
			var atual := float(r.get(chave, 1.0))
			var novo := clampf(snappedf(atual + (0.1 if sinal == "+" else -0.1), 0.1), 0.5, 2.0)
			main.aplicar_regras({chave: novo})
		return
	match id:
		"inicio:continuar":
			main.continuar_sessao()
		"inicio:nova":
			main.nova_sessao()
		"impressora:focar":
			main.focar_impressora()
		"menu":
			if gm.modal == null:
				menu_aberto = true
				pagina = "home"
				pressionado = ""
		"centralizar":
			main.centralizar_jogador()
		"dialogo:fechar":
			gm.fechar_dialogo()
		"menu:continuar":
			menu_aberto = false
			pagina = "home"
		"menu:personalizar":
			pagina = "personalizar"
		"menu:aparencia":
			pagina = "aparencia"
		"menu:regras":
			pagina = "regras"
		"menu:sons":
			pagina = "sons"
		"menu:info":
			pagina = "info"
		"menu:fechar":
			pagina = "fechar"
		"menu:voltar":
			pagina = "home"
		"fechar:sim":
			main.sair_jogo()
		"fechar:nao":
			pagina = "home"
		"sons:toggle":
			main.aplicar_sons(not bool(prefs.get("sons", true)))
		"sons:teste":
			if bool(prefs.get("sons", true)) and gm != null:
				gm.som("aceitar")
		"regra:reset":
			main.aplicar_regras({"velocidade": 1.0, "demandas": 1.0, "pacientes": 1.0, "paciencia": 1.0})
		"info:play":
			OS.shell_open(URL_PLAY)
		"info:contato":
			OS.shell_open(URL_CONTATO)
		_:
			if id.begins_with("dialogo:opcao:"):
				gm.escolher_opcao(int(id.substr(14)))


# =================================================================== desenho

func _draw() -> void:
	botoes.clear()
	areas_ui.clear()
	if gm == null:
		return
	var w := maxf(size.x, 320.0)
	var h := maxf(size.y, 240.0)
	if tela_inicio:
		_desenhar_tela_inicio(w, h)
		return
	if gm.modal != null:
		var tipo := str(gm.modal.get("tipo", ""))
		if tipo == "reparo":
			_desenhar_reparo(w, h)
		elif tipo == "exame":
			_desenhar_exame(w, h)
		else:
			_desenhar_dialogo(w, h)
		return
	if menu_aberto:
		_desenhar_menu(w, h)
		return
	_desenhar_hud(w, h)
	_desenhar_alertas(w, h)
	_desenhar_botoes_canto(w, h)


func _f() -> Font:
	if _fonte == null:
		_fonte = ThemeDB.fallback_font
	return _fonte


func _cor(nome: String, padrao: String = "#ffffff") -> Color:
	if main != null and main.paleta is Dictionary:
		return main.paleta.get(nome, Color(padrao))
	return Color(padrao)


func _texto(txt: String, pos: Vector2, tam: int, cor: Color, alinhamento: int = HORIZONTAL_ALIGNMENT_LEFT, largura: float = -1.0) -> void:
	draw_string(_f(), pos, txt, alinhamento, largura, tam, cor)


func _texto_centro(txt: String, centro: Vector2, tam: int, cor: Color) -> void:
	var largura := _f().get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	draw_string(_f(), Vector2(centro.x - largura * 0.5, centro.y + tam * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, cor)


func _largura(txt: String, tam: int) -> float:
	return _f().get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x


func _painel(r: Rect2, cor: Color, raio: float = 16.0, borda: Color = Color(0, 0, 0, 0)) -> void:
	draw_rect(Rect2(r.position + Vector2(0, 5), r.size), Color(0, 0, 0, 0.20), true)
	VisualScript.retangulo_arredondado(self, r, cor, raio)
	if borda.a > 0.001:
		VisualScript.contorno_arredondado(self, r, borda, raio, 1.4)


func _cor_estilo(estilo: String) -> Color:
	match estilo:
		"primario":
			return _cor("ui_destaque", "#43c38d")
		"aviso":
			return _cor("ui_aviso", "#f0b44a")
		"perigo":
			return _cor("ui_perigo", "#e36a61")
		"fantasma":
			return Color(_cor("ui_painel2", "#22303d"), 0.55)
		_:
			return _cor("ui_painel2", "#22303d")


func _cor_texto_estilo(estilo: String) -> Color:
	if estilo in ["primario", "aviso"]:
		return Color("#17212b")
	if estilo == "perigo":
		return Color("#fff5f3")
	return _cor("ui_texto", "#f4f7fa")


func _botao(id: String, r: Rect2, texto: String, estilo: String = "secundario", selecionado: bool = false, tam: int = 17) -> void:
	_registrar(id, r)
	var ativo := hover == id
	var base := _cor_estilo(estilo)
	if ativo:
		base = base.lightened(0.10)
	if pressionado == id:
		base = base.darkened(0.10)
	_painel(r, base, 12.0, _cor("ui_aviso", "#f0b44a") if selecionado else Color(0, 0, 0, 0))
	if selecionado:
		VisualScript.contorno_arredondado(self, r, _cor("ui_aviso", "#f0b44a"), 12.0, 2.2)
	var cor := _cor_texto_estilo(estilo)
	draw_string(_f(), Vector2(r.position.x, r.position.y + r.size.y * 0.5 + tam * 0.34), texto,
		HORIZONTAL_ALIGNMENT_CENTER, r.size.x, tam, cor)


func _botao_compacto(id: String, r: Rect2, texto: String, selecionado: bool, tam: int = 13) -> void:
	_registrar(id, r)
	var base := Color(_cor("ui_painel", "#17212b"), 0.72)
	if hover == id:
		base = _cor("ui_painel2", "#22303d").lightened(0.08)
	if selecionado:
		base = _cor("destaque", "#2f8f6b")
	if pressionado == id:
		base = base.darkened(0.08)
	VisualScript.retangulo_arredondado(self, r, base, 8.0)
	VisualScript.contorno_arredondado(self, r,
		_cor("ui_aviso", "#f0b44a") if selecionado else Color(_cor("ui_borda", "#53687a"), 0.75), 8.0,
		2.0 if selecionado else 1.0)
	draw_string(_f(), Vector2(r.position.x, r.position.y + r.size.y * 0.5 + tam * 0.34), texto,
		HORIZONTAL_ALIGNMENT_CENTER, r.size.x, tam, _cor("ui_texto", "#f4f7fa"))


# =================================================================== HUD

func _desenhar_tela_inicio(w: float, h: float) -> void:
	# Fundo em faixas para um degradê suave, sem depender de textura.
	var topo := Color("#17343c")
	var base := Color("#0b141b")
	var faixas := 22
	for i in faixas:
		var f := float(i) / float(faixas - 1)
		draw_rect(Rect2(0, h * float(i) / float(faixas), w, h / float(faixas) + 1.0),
			topo.lerp(base, f), true)
	VisualScript.elipse(self, Vector2(w * 0.80, h * 0.20), w * 0.30, h * 0.34, Color("#43c38d", 0.075))
	VisualScript.elipse(self, Vector2(w * 0.18, h * 0.86), w * 0.24, h * 0.28, Color("#f0b44a", 0.045))

	var mw := minf(w - 48.0, 920.0)
	var mh := minf(h - 40.0, 560.0)
	var r := Rect2((w - mw) * 0.5, (h - mh) * 0.5, mw, mh)
	_painel(r, Color(_cor("ui_painel", "#17212b"), 0.985), 24.0,
		Color(_cor("ui_destaque", "#43c38d"), 0.62))

	# Marca do postinho.
	var logo := r.position + Vector2(66, 66)
	draw_circle(logo, 31.0, Color(_cor("ui_destaque", "#43c38d"), 0.20))
	draw_circle(logo, 24.0, _cor("ui_destaque", "#43c38d"))
	draw_rect(Rect2(logo + Vector2(-4, -13), Vector2(8, 26)), Color("#102019"), true)
	draw_rect(Rect2(logo + Vector2(-13, -4), Vector2(26, 8)), Color("#102019"), true)
	_texto("POSTINHO DE SAÚDE", Vector2(r.position.x + 110, r.position.y + 62), 31,
		_cor("ui_texto", "#f4f7fa"))
	_texto("A rotina de um Agente Comunitário de Saúde", Vector2(r.position.x + 112, r.position.y + 86), 13,
		_cor("ui_fraco", "#a9bac8"))

	draw_multiline_string(_f(), Vector2(r.position.x + 44, r.position.y + 136),
		"Um dia no posto: acolher quem chega, escutar o corredor, resolver demandas e cuidar da própria energia. Não existe vitória, derrota ou resposta certa.",
		HORIZONTAL_ALIGNMENT_LEFT, minf(mw - 380.0, 540.0), 14, 4,
		_cor("ui_fraco", "#a9bac8"))

	# Cartão da sessão salva.
	var info: Dictionary = {}
	if gm.has_method("info_sessao"):
		info = gm.info_sessao()
	var cartao := Rect2(r.position.x + 44, r.position.y + 196, minf(mw - 388.0, 540.0), 92)
	VisualScript.retangulo_arredondado(self, cartao, Color(_cor("ui_painel2", "#22303d"), 0.72), 14.0)
	VisualScript.contorno_arredondado(self, cartao,
		Color(_cor("ui_borda", "#53687a"), 0.60), 14.0, 1.0)
	if info.is_empty():
		_texto("Nenhuma sessão salva", Vector2(cartao.position.x + 20, cartao.position.y + 34), 17,
			_cor("ui_texto", "#f4f7fa"))
		_texto("Ao começar, a equipe do dia é sorteada: chefia, clínica e apoio mudam a cada sessão.",
			Vector2(cartao.position.x + 20, cartao.position.y + 58), 12,
			_cor("ui_fraco", "#a9bac8"), HORIZONTAL_ALIGNMENT_LEFT, cartao.size.x - 40)
	else:
		_texto("Sessão salva", Vector2(cartao.position.x + 20, cartao.position.y + 30), 16,
			_cor("ui_destaque", "#43c38d"))
		var resumo := "%d%% de energia  •  %d trabalho(s) pendente(s)" % [
			int(round(clampf(float(info.get("energia", 0.0)) / maxf(0.001, float(gm.E_MAX)), 0.0, 1.0) * 100.0)),
			int(info.get("tarefas", 0)),
		]
		_texto(resumo, Vector2(cartao.position.x + 20, cartao.position.y + 54), 12,
			_cor("ui_texto", "#f4f7fa"))
		_texto("%d pessoa(s) no posto quando o dia foi salvo. Apenas um espaço de save." % int(info.get("pessoas", 0)),
			Vector2(cartao.position.x + 20, cartao.position.y + 74), 11,
			_cor("ui_fraco", "#a9bac8"))

	# Ilustração da equipe.
	var terra := Vector2(r.end.x - 166.0, r.end.y - 150.0)
	VisualScript.elipse(self, terra, 126.0, 18.0, Color(0, 0, 0, 0.24))
	VisualScript.elipse(self, terra, 88.0, 11.0, Color(0, 0, 0, 0.18))
	var amostras := [
		{"tipo": "jogador", "pele": "#FFEB3B", "roupa": "#2f6fd0", "roupa2": "#dce7ff",
			"calca": "#34404d", "cabelo": "#2b1b17", "estilo_cabelo": "curto", "especie": "humano"},
		{"tipo": "funcionario_sala", "pele": "#b07a52", "roupa": "#f4f7fa", "roupa2": "#dbe7ee",
			"calca": "#34404d", "cabelo": "#2b1b17", "estilo_cabelo": "coque",
			"especie": "capivara", "animal": true},
		{"tipo": "funcionario_sala", "pele": "#8A5A44", "roupa": "#2a9d8f", "roupa2": "#e7f6f2",
			"calca": "#3d405b", "cabelo": "#2b1b17", "estilo_cabelo": "franja", "especie": "humano"},
	]
	var deslocamentos := [-62.0, 2.0, 64.0]
	for i in amostras.size():
		VisualScript.retrato(self, amostras[i],
			terra + Vector2(deslocamentos[i], 0.0 if i != 1 else 4.0),
			1.75 if i != 1 else 1.92, t)
	_texto("Equipe sorteada a cada sessão", Vector2(terra.x - 120, terra.y + 34), 11,
		_cor("ui_fraco", "#a9bac8"), HORIZONTAL_ALIGNMENT_CENTER, 240)

	# Botões.
	var by := r.end.y - 122.0
	if info.is_empty():
		_botao("inicio:nova", Rect2(r.position.x + 44, by, 236, 54), "Começar o dia", "primario", false, 19)
	else:
		_botao("inicio:continuar", Rect2(r.position.x + 44, by, 236, 54), "Continuar sessão", "primario", false, 19)
		_botao("inicio:nova", Rect2(r.position.x + 292, by, 204, 54), "Nova sessão", "secundario", false, 18)
		_texto("Começar uma nova sessão substitui o save atual.", Vector2(r.position.x + 44, by + 72), 11,
			Color(_cor("ui_fraco", "#a9bac8"), 0.85))

	_texto("Sem prova, sem nota e sem game over. Só a rotina do posto.",
		Vector2(r.position.x + 44, r.end.y - 20), 11, Color(_cor("ui_fraco", "#a9bac8"), 0.80))
	_texto(VersaoPostinho.texto(),
		Vector2(r.end.x - 92, r.end.y - 20), 11, Color(_cor("ui_fraco", "#a9bac8"), 0.65))


func _desenhar_hud(w: float, h: float) -> void:
	var bw := minf(700.0, w - 360.0)
	if bw < 470.0:
		bw = w - 32.0
	var barra := Rect2(12, 10, bw, 50)
	_registrar_ui(barra)
	_painel(barra, Color(_cor("ui_painel", "#17212b"), 0.93), 15.0, Color(_cor("ui_borda", "#53687a"), 0.85))
	var x0 := barra.position.x + 14.0

	# Trabalhos pendentes em dez marcas.
	_texto("TRABALHOS", Vector2(x0, barra.position.y + 16), 9, _cor("ui_fraco", "#a9bac8"))
	var cor_t := _cor("ui_perigo", "#e36a61") if gm.tarefas >= 10 else _cor("ui_aviso", "#f0b44a")
	for i in 10:
		var pr := Rect2(x0 + float(i) * 11.0, barra.position.y + 23, 8, 9)
		draw_rect(pr, cor_t if i < int(gm.tarefas) else Color(0, 0, 0, 0.30), true)
	_texto("%d/10" % int(gm.tarefas), Vector2(x0 + 116, barra.position.y + 33), 14,
		_cor("ui_perigo", "#e36a61") if gm.tarefas >= 10 else _cor("ui_texto", "#f4f7fa"))

	# Energia.
	var ex := x0 + 176.0
	_texto("ENERGIA", Vector2(ex, barra.position.y + 16), 9, _cor("ui_fraco", "#a9bac8"))
	var frac_e := clampf(float(gm.energia) / maxf(0.001, float(gm.E_MAX)), 0.0, 1.0)
	var cor_e := _cor("ui_destaque", "#43c38d")
	if frac_e < 0.4:
		cor_e = _cor("ui_perigo", "#e36a61")
	elif frac_e < 0.7:
		cor_e = _cor("ui_aviso", "#f0b44a")
	var barra_e := Rect2(ex, barra.position.y + 23, 146, 9)
	draw_rect(barra_e, Color(0, 0, 0, 0.30), true)
	if frac_e > 0.0:
		draw_rect(Rect2(barra_e.position, Vector2(barra_e.size.x * frac_e, barra_e.size.y)), cor_e, true)
	_texto("%d%%" % int(round(frac_e * 100.0)), Vector2(ex + 150, barra.position.y + 33), 12, cor_e)

	# Fila do guichê: informação útil, sem contador de tempo nem números de depuração.
	info_hud = ""
	if bw >= 640.0:
		var fila := int(gm.fila_guiche.size())
		info_hud = "Fila do guichê: %d" % fila if fila > 0 else "Saguão tranquilo"
		_texto(info_hud, Vector2(x0 + 380, barra.position.y + 32), 11, _cor("ui_fraco", "#a9bac8"))

	# Estado do jogador dentro da barra.
	var estado := _estado_texto()
	var stw := maxf(112.0, _largura(estado, 13) + 40.0)
	var st := Rect2(barra.end.x - stw - 8.0, barra.position.y + 8, stw, 34)
	VisualScript.retangulo_arredondado(self, st, Color(_cor("ui_painel2", "#22303d"), 0.86), 17.0)
	VisualScript.contorno_arredondado(self, st, Color(_cor("ui_borda", "#53687a"), 0.70), 17.0, 1.0)
	var olho := _cor("ui_destaque", "#43c38d")
	if gm.estado == gm.Estado.NA_COPA or gm.cafe_modo != gm.ModoCafe.NENHUM:
		olho = _cor("ui_aviso", "#f0b44a")
	elif gm.tarefas >= 10:
		olho = _cor("ui_perigo", "#e36a61")
	draw_circle(st.position + Vector2(18, 17), 5.0, olho)
	_texto(estado, Vector2(st.position.x + 29, st.position.y + 22), 13, _cor("ui_texto", "#f4f7fa"))

	# Indicador da impressora. Clicar leva a câmera até ela.
	var quebrada := bool(gm.impressora.get("quebrada", false))
	var ir := Rect2(12, barra.end.y + 8.0, 236.0, 30.0)
	_registrar("impressora:focar", ir)
	var base_i := Color(_cor("ui_painel", "#17212b"), 0.86)
	if quebrada:
		var pulso_i := 0.5 + 0.5 * sin(t * 6.0)
		base_i = Color(_cor("ui_perigo", "#e36a61"), 0.20 + pulso_i * 0.14)
	elif hover == "impressora:focar":
		base_i = _cor("ui_painel2", "#22303d")
	VisualScript.retangulo_arredondado(self, ir, base_i, 10.0)
	VisualScript.contorno_arredondado(self, ir,
		Color(_cor("ui_perigo", "#e36a61"), 0.85) if quebrada else Color(_cor("ui_borda", "#53687a"), 0.65),
		10.0, 1.2)
	draw_rect(Rect2(ir.position.x + 10, ir.position.y + 9, 18, 11), Color("#dce4e8"), true)
	draw_rect(Rect2(ir.position.x + 12, ir.position.y + 12, 10, 4), Color("#9fb0b8"), true)
	draw_rect(Rect2(ir.position.x + 13, ir.position.y + 20, 12, 4), Color("#f7fafb"), true)
	draw_circle(ir.position + Vector2(24, 14.5), 2.0,
		_cor("ui_perigo", "#e36a61") if quebrada else _cor("ui_destaque", "#43c38d"))
	_texto("Impressora quebrada" if quebrada else "Impressora ok",
		Vector2(ir.position.x + 36, ir.position.y + 20), 12,
		_cor("ui_texto", "#f4f7fa") if quebrada else _cor("ui_fraco", "#a9bac8"))
	if quebrada:
		_texto("consertar", Vector2(ir.end.x - 66, ir.position.y + 20), 10,
			Color(_cor("ui_perigo", "#e36a61"), 0.95))

	# Dica inicial.
	if float(gm.tempo) < 32.0:
		var alfa := clampf((32.0 - float(gm.tempo)) / 4.0, 0.0, 1.0)
		var dica := "Arraste para explorar  •  Pinça para aproximar"
		var dw := minf(w - 32.0, _largura(dica, 12) + 34.0)
		var dr := Rect2(16, h - 54, dw, 34)
		_painel(dr, Color(_cor("ui_painel", "#17212b"), 0.72 * alfa), 10.0)
		_texto(dica, Vector2(dr.position.x, dr.position.y + 22), 12,
			Color(_cor("ui_fraco", "#a9bac8"), alfa), HORIZONTAL_ALIGNMENT_CENTER, dr.size.x)


func _estado_texto() -> String:
	if gm.cafe_modo != gm.ModoCafe.NENHUM:
		return "Tomando café"
	match int(gm.estado):
		gm.Estado.NO_PC:
			return "No computador"
		gm.Estado.NA_COPA:
			return "Na copa"
		gm.Estado.CONVERSANDO:
			return "Conversando"
		gm.Estado.CAMINHANDO:
			return "Em deslocamento"
	return "Livre"


func _desenhar_alertas(w: float, _h: float) -> void:
	if gm.alertas.is_empty():
		return
	var total: int = int(gm.alertas.size())
	var inicio := maxi(0, total - 3)
	var linhas: Array = []
	for i in range(inicio, total):
		linhas.append(gm.alertas[i])
	var n := linhas.size()
	for i in n:
		var a: Dictionary = linhas[i]
		var dur := float(a.get("t", 0.0))
		var alfa := clampf(dur / 0.7, 0.0, 1.0)
		var texto := str(a.get("texto", ""))
		var larg := minf(w - 160.0, maxf(280.0, _largura(texto, 14) + 46.0))
		var y := size.y - 154.0 - float(n - 1 - i) * 42.0
		var r := Rect2((w - larg) * 0.5, y, larg, 36)
		_painel(r, Color(_cor("ui_painel", "#17212b"), 0.90 * alfa), 18.0,
			Color(_cor("ui_borda", "#53687a"), 0.65 * alfa))
		draw_multiline_string(_f(), Vector2(r.position.x + 20, r.position.y + 23), texto,
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 40, 14, 1, Color(_cor("ui_texto", "#f4f7fa"), alfa))


func _desenhar_botoes_canto(w: float, h: float) -> void:
	var menu_r := Rect2(w - 134.0, h - 78.0, 118.0, 54.0)
	_registrar("menu", menu_r)
	var base_m := _cor("ui_destaque", "#43c38d")
	if hover == "menu":
		base_m = base_m.lightened(0.08)
	if pressionado == "menu":
		base_m = base_m.darkened(0.08)
	_painel(menu_r, base_m, 27.0)
	var cy := menu_r.position.y + menu_r.size.y * 0.5
	for i in 3:
		draw_line(Vector2(menu_r.position.x + 19, cy - 7 + i * 7),
			Vector2(menu_r.position.x + 35, cy - 7 + i * 7), Color("#17212b"), 2.6, true)
	_texto("Menu", Vector2(menu_r.position.x + 43, cy + 6), 16, Color("#17212b"))

	var ag_r := Rect2(w - 256.0, h - 78.0, 112.0, 54.0)
	_registrar("centralizar", ag_r)
	var base_a := Color(_cor("ui_painel", "#17212b"), 0.92)
	if hover == "centralizar":
		base_a = _cor("ui_painel2", "#22303d")
	if pressionado == "centralizar":
		base_a = base_a.darkened(0.08)
	_painel(ag_r, base_a, 27.0, Color(_cor("ui_borda", "#53687a"), 0.85))
	var ac := ag_r.position + Vector2(23, 27)
	draw_circle(ac + Vector2(0, -6), 4.5, _cor("ui_destaque", "#43c38d"))
	draw_arc(ac + Vector2(0, 7), 7.0, PI, TAU, 12, _cor("ui_destaque", "#43c38d"), 3.0, true)
	_texto("Agente", Vector2(ag_r.position.x + 38, cy + 6), 14, _cor("ui_texto", "#f4f7fa"))


# =================================================================== dialogo

func _desenhar_dialogo(w: float, h: float) -> void:
	draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.58), true)
	var dw := clampf(w * 0.62, 720.0, 910.0)
	var dh := clampf(h * 0.66, 400.0, 500.0)
	if dw > w - 32.0:
		dw = w - 32.0
	if dh > h - 32.0:
		dh = h - 32.0
	var dx := (w - dw) * 0.5
	var dy := (h - dh) * 0.5
	var painel := Rect2(dx, dy, dw, dh)
	_painel(painel, Color(_cor("ui_painel", "#17212b"), 0.985), 20.0, Color(_cor("ui_destaque", "#43c38d"), 0.75))

	var modal: Dictionary = gm.modal
	var alvo = gm.entidades.get(str(modal.get("alvo_id", "")), null)
	var cor_fala := Color(str(modal.get("cor", "#43c38d")))
	var eh_papo: bool = str(modal.get("tipo", "")) == "papo"
	var eh_papo_paciente: bool = eh_papo and bool(modal.get("papo_paciente", false))
	var respondido: bool = str(modal.get("fase", "")) == "resposta"
	# Faixa de identificacao.
	var faixa := Rect2(dx, dy, dw, 96)
	VisualScript.retangulo_arredondado(self, faixa, Color(cor_fala, 0.22), 20.0)
	draw_line(Vector2(dx + 28, dy + 96), Vector2(dx + dw - 28, dy + 96), Color(cor_fala, 0.55), 1.5, true)

	# Retrato.
	var centro_retrato := Vector2(dx + 62, dy + 62)
	draw_circle(centro_retrato, 40.0, Color(0, 0, 0, 0.18))
	draw_circle(centro_retrato, 37.0, Color(cor_fala, 0.45))
	if alvo != null:
		VisualScript.retrato(self, alvo, centro_retrato + Vector2(0, 23), 1.85, t)
	draw_circle(centro_retrato + Vector2(28, -26), 14.0, _cor("ui_aviso", "#f0b44a"))
	if eh_papo:
		_texto_centro("..." if not respondido else "!", centro_retrato + Vector2(28, -29), 15, Color("#17212b"))
	else:
		_texto_centro("!", centro_retrato + Vector2(28, -27), 18, Color("#17212b"))

	_texto(str(modal.get("nome", "")), Vector2(dx + 112, dy + 42), 24, _cor("ui_texto", "#f4f7fa"))
	_texto(str(modal.get("cargo", "")), Vector2(dx + 112, dy + 64), 13, _cor("ui_fraco", "#a9bac8"))
	if eh_papo:
		var rotulo := "CONVERSA NA ESPERA" if eh_papo_paciente else "PAPO DE CORREDOR"
		_texto((rotulo if not respondido else "RESPOSTA"), Vector2(dx + 112, dy + 84), 11,
			Color(Color("#b99cf0") if not respondido else cor_fala.lightened(0.15)))
	else:
		_texto("DEMANDA", Vector2(dx + 112, dy + 84), 11, Color(cor_fala.lightened(0.15)))

	# Fechar.
	var fx := dx + dw - 50
	_botao("dialogo:fechar", Rect2(fx, dy + 18, 32, 32), "×", "fantasma", false, 20)

	# Texto da demanda, no topo.
	var texto := str(modal.get("texto", ""))
	var caixa := Rect2(dx + 28, dy + 110, dw - 56, 100.0 if eh_papo else 92.0)
	VisualScript.retangulo_arredondado(self, caixa, Color(_cor("ui_painel2", "#22303d"), 0.82), 13.0)
	draw_rect(Rect2(caixa.position.x + 4, caixa.position.y + 12, 3, caixa.size.y - 24), Color(cor_fala, 0.75), true)
	draw_multiline_string(_f(), Vector2(caixa.position.x + 18, caixa.position.y + 31), texto,
		HORIZONTAL_ALIGNMENT_LEFT, caixa.size.x - 34, 18 if eh_papo else 19, 4 if eh_papo else 3,
		_cor("ui_texto", "#f4f7fa"))

	var aviso := str(modal.get("fundido", ""))
	if aviso != "":
		_texto(aviso, Vector2(dx + 30, dy + 222), 12, _cor("ui_aviso", "#f0b44a"))

	var opcoes: Array = modal.get("opcoes", [])
	var n := opcoes.size()
	var bh := 54.0
	var gap := 9.0
	var inicio_y := dy + dh - 26.0 - (float(n) * bh + float(maxi(0, n - 1)) * gap)
	var frac_e := clampf(float(gm.energia) / maxf(0.001, float(gm.E_MAX)), 0.0, 1.0)
	var cor_e := _cor("ui_destaque", "#43c38d")
	if frac_e < 0.4:
		cor_e = _cor("ui_perigo", "#e36a61")
	elif frac_e < 0.7:
		cor_e = _cor("ui_aviso", "#f0b44a")
	if eh_papo:
		var sem_custo := "Sem custo de energia"
		if eh_papo_paciente:
			sem_custo = "Sem custo de energia • sem resposta certa"
		_texto(sem_custo if not respondido else "Conversa concluída",
			Vector2(dx + 30, inicio_y - 16), 13, Color("#b99cf0"))
	else:
		_texto("Sua energia: %d%%" % int(round(frac_e * 100.0)), Vector2(dx + 30, inicio_y - 16), 13, cor_e)
	_texto("Escolha uma resposta" if not respondido else "Toque para encerrar",
		Vector2(dx + 30, inicio_y - 16), 12, _cor("ui_fraco", "#a9bac8"),
		HORIZONTAL_ALIGNMENT_RIGHT, dw - 60)

	for i in n:
		var op: Dictionary = opcoes[i]
		var estilo := "secundario"
		if eh_papo:
			# As duas respostas têm o mesmo peso visual: não há alternativa "certa".
			estilo = "secundario"
		elif bool(op.get("aceitar", false)):
			estilo = "aviso" if bool(op.get("relutante", false)) else "primario"
		elif bool(op.get("relutante", false)):
			estilo = "secundario"
		var br := Rect2(dx + 28, inicio_y + float(i) * (bh + gap), dw - 56, bh)
		_botao("dialogo:opcao:%d" % i, br, str(op.get("texto", "")), estilo, false, 18)
	
	# Dica no rodape.
	var dica := "O posto continua rodando enquanto vocês conversam."
	if eh_papo_paciente:
		dica = "Aqui ninguém é reprovado. Não existe resposta certa, só escuta."
	elif eh_papo:
		dica = "Papo de corredor: sem custo de energia, com o posto rodando."
	_texto(dica, Vector2(dx + 30, dy + dh - 8), 11, Color(_cor("ui_fraco", "#a9bac8"), 0.75))


# =================================================================== minijogos

func _desenhar_reparo(w: float, h: float) -> void:
	var modal: Dictionary = gm.modal
	draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.64), true)
	var dw := minf(w - 48.0, 840.0)
	var dh := minf(h - 48.0, 500.0)
	var dx := (w - dw) * 0.5
	var dy := (h - dh) * 0.5
	var r := Rect2(dx, dy, dw, dh)
	var cor := _cor("ui_aviso", "#f0b44a")
	_painel(r, Color(_cor("ui_painel", "#17212b"), 0.995), 22.0, Color(cor, 0.85))
	VisualScript.retangulo_arredondado(self, Rect2(dx, dy, dw, 92), Color(cor, 0.16), 22.0)
	draw_line(Vector2(dx + 26, dy + 92), Vector2(dx + dw - 26, dy + 92), Color(cor, 0.55), 1.5, true)
	draw_circle(Vector2(dx + 54, dy + 46), 25.0, Color(cor, 0.22))
	_texto_centro("!", Vector2(dx + 54, dy + 45), 24, cor)
	var alvo := str(modal.get("alvo", "pc"))
	_texto(str(modal.get("titulo", "Conserto de emergência")), Vector2(dx + 92, dy + 40), 24,
		_cor("ui_texto", "#f4f7fa"))
	_texto("Impressora do balcão" if alvo == "impressora" else "Computador",
		Vector2(dx + 94, dy + 64), 12, _cor("ui_fraco", "#a9bac8"))
	_botao("dialogo:fechar", Rect2(dx + dw - 50, dy + 18, 32, 32), "×", "fantasma", false, 20)
	_texto(str(modal.get("texto", "")), Vector2(dx + 30, dy + 126), 14,
		_cor("ui_texto", "#f4f7fa"), HORIZONTAL_ALIGNMENT_LEFT, dw - 60)

	var seq: Array = modal.get("sequencia", [])
	var prog: Array = modal.get("progresso", [])
	var cores: Array = modal.get("cores", [])
	var nomes: Array = modal.get("nomes", [])
	var n := seq.size()
	var passo := int(floor(t / 0.62)) % maxi(1, n + 2)
	var mostrando := passo < n
	var placa := Rect2(dx + 52, dy + 178, dw - 104, 124)
	VisualScript.retangulo_arredondado(self, placa, Color("#101d18"), 14.0)
	VisualScript.contorno_arredondado(self, placa, Color(cor, 0.35), 14.0, 1.2)
	_texto("SEQUÊNCIA DAS LUZES", Vector2(placa.position.x + 18, placa.position.y + 24), 10,
		Color(cor, 0.85))
	_texto("%d de %d" % [mini(prog.size(), n), n], Vector2(placa.end.x - 120, placa.position.y + 24),
		11, _cor("ui_fraco", "#a9bac8"), HORIZONTAL_ALIGNMENT_RIGHT, 100)
	draw_line(Vector2(placa.position.x + 28, placa.position.y + 78),
		Vector2(placa.end.x - 28, placa.position.y + 78), Color("#33473f"), 3.0, true)
	var esp := placa.size.x / float(n + 1)
	for i in n:
		var c := Vector2(placa.position.x + esp * float(i + 1), placa.position.y + 78)
		var ci := int(seq[i])
		var fio := Color(str(cores[ci])) if ci >= 0 and ci < cores.size() else cor
		var aceso := mostrando and passo == i
		var feito := i < prog.size()
		draw_line(c, Vector2(c.x, placa.position.y + 40), Color(fio, 0.60 if not aceso else 1.0), 3.0, true)
		if aceso:
			VisualScript.elipse(self, c, 25.0, 25.0, Color(fio, 0.24))
		draw_circle(c, 13.5, Color(fio, 0.95 if (aceso or feito) else 0.36), true, -1.0, true)
		draw_arc(c, 13.5, 0.0, TAU, 24, Color(1, 1, 1, 0.32 if aceso else 0.12), 1.4, true)
		if feito:
			_texto_centro("✓", c, 12, Color("#102019"))

	var nota_y := placa.end.y + 22.0
	draw_multiline_string(_f(), Vector2(dx + 52, nota_y),
		"Repita a ordem tocando nos fios. Um erro reinicia a sequência e gasta um pouco de energia.",
		HORIZONTAL_ALIGNMENT_LEFT, dw - 104, 12, 2, _cor("ui_fraco", "#a9bac8"))

	var total := 5
	var bw2 := minf(96.0, (dw - 120.0) / 5.0)
	var gap2 := 10.0
	var total_w := float(total) * bw2 + float(total - 1) * gap2
	var x0 := dx + (dw - total_w) * 0.5
	var y0 := dy + dh - 104.0
	for i in total:
		var br := Rect2(x0 + float(i) * (bw2 + gap2), y0, bw2, 82.0)
		var id := "minijogo:%d" % i
		_registrar(id, br)
		var fio2 := Color(str(cores[i])) if i < cores.size() else cor
		var c2 := br.position + Vector2(br.size.x * 0.5, 27)
		if hover == id:
			draw_circle(c2, 25.0, Color(fio2, 0.20))
		draw_circle(c2, 18.0, fio2, true, -1.0, true)
		draw_arc(c2, 18.0, 0.0, TAU, 28, Color(0, 0, 0, 0.26), 2.0, true)
		draw_circle(c2, 4.5, Color(1, 1, 1, 0.42), true, -1.0, true)
		_texto(str(nomes[i]) if i < nomes.size() else "Fio %d" % (i + 1),
			Vector2(br.position.x, br.position.y + 64), 12, _cor("ui_texto", "#f4f7fa"),
			HORIZONTAL_ALIGNMENT_CENTER, br.size.x)


func _desenhar_exame(w: float, h: float) -> void:
	var modal: Dictionary = gm.modal
	draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.64), true)
	var dw := minf(w - 36.0, 1080.0)
	var dh := minf(h - 32.0, 664.0)
	var dx := (w - dw) * 0.5
	var dy := (h - dh) * 0.5
	var r := Rect2(dx, dy, dw, dh)
	var cor := _cor("ui_destaque", "#43c38d")
	_painel(r, Color(_cor("ui_painel", "#17212b"), 0.995), 22.0, Color(cor, 0.80))
	VisualScript.retangulo_arredondado(self, Rect2(dx, dy, dw, 92), Color(cor, 0.14), 22.0)
	draw_line(Vector2(dx + 26, dy + 92), Vector2(dx + dw - 26, dy + 92), Color(cor, 0.50), 1.5, true)
	VisualScript.retangulo_arredondado(self, Rect2(dx + 41, dy + 39, 27, 19), cor, 4.0)
	VisualScript.retangulo_arredondado(self, Rect2(dx + 39, dy + 33, 13, 9), cor.darkened(0.10), 3.0)
	_texto("Arquivo de exames", Vector2(dx + 84, dy + 40), 24, _cor("ui_texto", "#f4f7fa"))
	_texto("Encontre a pasta certa entre as gavetas do arquivo.", Vector2(dx + 86, dy + 64), 12,
		_cor("ui_fraco", "#a9bac8"))
	_botao("dialogo:fechar", Rect2(dx + dw - 50, dy + 18, 32, 32), "×", "fantasma", false, 20)
	draw_multiline_string(_f(), Vector2(dx + 30, dy + 118),
		str(modal.get("texto", "")), HORIZONTAL_ALIGNMENT_LEFT, dw - 60, 14, 2,
		_cor("ui_texto", "#f4f7fa"))

	var pastas: Array = modal.get("pastas", [])
	var n := pastas.size()
	var cols := 6
	var rows := maxi(1, int(ceil(float(n) / float(cols))))
	var area := Rect2(dx + 34, dy + 178, dw - 68, dh - 236)
	var cw := area.size.x / float(cols)
	var ch := area.size.y / float(rows)
	var fw := minf(cw - 14.0, 106.0)
	var fh := minf(ch - 14.0, 78.0)
	for i in n:
		var pasta: Dictionary = pastas[i]
		var col := i % cols
		var row := int(i / cols)
		var centro := Vector2(area.position.x + cw * (float(col) + 0.5),
			area.position.y + ch * (float(row) + 0.5))
		var fr := Rect2(centro - Vector2(fw, fh) * 0.5, Vector2(fw, fh))
		var id := "exame:%d" % i
		_registrar(id, fr.grow(4))
		var cb := Color(str(pasta.get("cor", "#c98a5b")))
		if hover == id:
			cb = cb.lightened(0.13)
			VisualScript.retangulo_arredondado(self, fr.grow(5), Color(1, 1, 1, 0.09), 11.0)
		draw_set_transform(centro, float(pasta.get("girada", 0.0)), Vector2.ONE)
		var local := Rect2(-fw * 0.5, -fh * 0.5, fw, fh)
		VisualScript.retangulo_arredondado(self,
			Rect2(local.position + Vector2(4, 0), Vector2(fw * 0.42, 12)), cb.darkened(0.10), 4.0)
		VisualScript.retangulo_arredondado(self, local, cb, 7.0)
		VisualScript.contorno_arredondado(self, local, cb.darkened(0.26), 7.0, 1.0)
		draw_rect(Rect2(local.position + Vector2(7, 9), Vector2(fw - 14, fh - 20)),
			Color(1, 1, 1, 0.12), true)
		var etiqueta := Rect2(local.position + Vector2(9, fh - 29), Vector2(fw - 18, 18))
		draw_rect(etiqueta, Color("#f6f1e4"), true)
		_desenhar_simbolo_pasta(Vector2(0, -fh * 0.10), str(pasta.get("sinal", "")), cb)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	_texto("Tentativas: %d" % int(modal.get("tentativas", 0)),
		Vector2(dx + 34, dy + dh - 20), 12, _cor("ui_fraco", "#a9bac8"))
	_texto("Errar gasta um pouco de energia, mas a pasta continua no arquivo.",
		Vector2(dx + 150, dy + dh - 20), 11, Color(_cor("ui_fraco", "#a9bac8"), 0.80),
		HORIZONTAL_ALIGNMENT_RIGHT, dw - 184)


func _desenhar_simbolo_pasta(c: Vector2, sinal: String, _cor_pasta: Color) -> void:
	match sinal:
		"ponto":
			draw_circle(c, 4.0, Color("#4b352a"), true, -1.0, true)
		"linha":
			draw_line(c + Vector2(-7, 0), c + Vector2(7, 0), Color("#4b352a"), 2.0, true)
		"estrela":
			var pts := PackedVector2Array()
			for k in 10:
				var ang := -PI * 0.5 + float(k) * PI / 5.0
				var raio := 7.0 if k % 2 == 0 else 3.2
				pts.append(c + Vector2(cos(ang), sin(ang)) * raio)
			draw_colored_polygon(pts, Color("#4b352a"))
		"cruz":
			draw_rect(Rect2(c + Vector2(-2, -8), Vector2(4, 16)), Color("#2ecc71"), true)
			draw_rect(Rect2(c + Vector2(-8, -2), Vector2(16, 4)), Color("#2ecc71"), true)


# =================================================================== menu

func _desenhar_menu(w: float, h: float) -> void:
	draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.66), true)
	match pagina:
		"personalizar":
			_menu_personalizar(w, h)
		"aparencia":
			_menu_aparencia(w, h)
		"regras":
			_menu_regras(w, h)
		"sons":
			_menu_sons(w, h)
		"info":
			_menu_info(w, h)
		"fechar":
			_menu_fechar(w, h)
		_:
			_menu_home(w, h)


func _menu_painel(w: float, h: float, larg: float, alt: float) -> Rect2:
	var mw := minf(w - 56.0, larg)
	var mh := minf(h - 32.0, alt)
	var r := Rect2((w - mw) * 0.5, (h - mh) * 0.5, mw, mh)
	_painel(r, Color(_cor("ui_painel", "#17212b"), 0.985), 20.0, Color(_cor("ui_borda", "#53687a"), 0.95))
	return r


func _menu_titulo(r: Rect2, titulo: String, sub: String) -> void:
	draw_rect(Rect2(r.position.x, r.position.y, 6, 78), _cor("ui_destaque", "#43c38d"), true)
	_texto(titulo, Vector2(r.position.x + 28, r.position.y + 38), 26, _cor("ui_texto", "#f4f7fa"))
	_texto(sub, Vector2(r.position.x + 28, r.position.y + 62), 13, _cor("ui_fraco", "#a9bac8"))
	draw_line(Vector2(r.position.x + 24, r.position.y + 84), Vector2(r.end.x - 24, r.position.y + 84),
		Color(_cor("ui_borda", "#53687a"), 0.55), 1.0)


func _menu_voltar(r: Rect2) -> void:
	_botao("menu:voltar", Rect2(r.position.x + 24, r.end.y - 58, 124, 40), "Voltar", "fantasma", false, 15)


func _menu_home(w: float, h: float) -> void:
	var r := _menu_painel(w, h, 620.0, 586.0)
	_menu_titulo(r, "Menu", "Postinho de Saúde • rotina do agente")
	var itens := [
		{"id": "menu:continuar", "texto": "Continuar", "estilo": "primario"},
		{"id": "menu:personalizar", "texto": "Personalizar personagem", "estilo": "secundario"},
		{"id": "menu:aparencia", "texto": "Aparência do postinho", "estilo": "secundario"},
		{"id": "menu:regras", "texto": "Regras da dinâmica", "estilo": "secundario"},
		{"id": "menu:sons", "texto": "Sons: %s" % ("ligados" if bool(prefs.get("sons", true)) else "desligados"), "estilo": "secundario"},
		{"id": "menu:info", "texto": "Informações e estatísticas", "estilo": "secundario"},
		{"id": "menu:fechar", "texto": "Fechar jogo", "estilo": "perigo"},
	]
	var y := r.position.y + 98.0
	for item in itens:
		_botao(str(item.id), Rect2(r.position.x + 48, y, r.size.x - 96, 52), str(item.texto), str(item.estilo), false, 18)
		y += 64.0
	_texto("O jogo fica pausado enquanto o menu estiver aberto.", Vector2(r.position.x, r.end.y - 18),
		12, _cor("ui_fraco", "#a9bac8"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


func _menu_personalizar(w: float, h: float) -> void:
	var r := _menu_painel(w, h, 1080.0, 700.0)
	_menu_titulo(r, "Personalizar personagem", "Monte o visual do seu agente comunitário.")
	var preview := Rect2(r.position.x + 24, r.position.y + 100, 252, r.size.y - 176)
	VisualScript.retangulo_arredondado(self, preview, Color(_cor("ui_painel2", "#22303d"), 0.62), 16.0)
	VisualScript.contorno_arredondado(self, preview, Color(_cor("ui_borda", "#53687a"), 0.55), 16.0, 1.0)
	var tp := Color(_cor("destaque", "#2f8f6b"), 0.20)
	draw_circle(preview.get_center() + Vector2(0, 42), 88.0, tp)
	draw_circle(preview.get_center() + Vector2(0, 42), 62.0, Color(tp, 0.55))
	var p: Dictionary = gm.jogador()
	VisualScript.retrato(self, p, preview.get_center() + Vector2(0, 38), 3.15, t)
	_texto(str(p.get("nome", "Agente")), Vector2(preview.position.x, preview.end.y - 56), 18,
		_cor("ui_texto", "#f4f7fa"), HORIZONTAL_ALIGNMENT_CENTER, preview.size.x)
	_texto("Agente Comunitário de Saúde", Vector2(preview.position.x, preview.end.y - 34), 11,
		_cor("ui_fraco", "#a9bac8"), HORIZONTAL_ALIGNMENT_CENTER, preview.size.x)

	var ap: Dictionary = gm.dnpcs.get("aparencia", {})
	var linhas := [
		{"chave": "pele", "titulo": "Pele", "tipo": "cor", "valores": ap.get("tons_pele", ["#EDC4B3", "#D69F7E", "#8A5A44"])},
		{"chave": "roupa", "titulo": "Colete / roupa", "tipo": "cor", "valores": ap.get("cores_roupa", ["#2f6fd0", "#e76f51", "#2a9d8f"])},
		{"chave": "calca", "titulo": "Calça", "tipo": "cor", "valores": ap.get("cores_calca", ["#3d405b", "#264653", "#5f0f40"])},
		{"chave": "cabelo", "titulo": "Cor do cabelo", "tipo": "cor", "valores": ap.get("cores_cabelo", ["#2b1b17", "#7b4b2a", "#d8b26e"])},
		{"chave": "estilo_cabelo", "titulo": "Estilo do cabelo", "tipo": "texto", "valores": ap.get("estilos_cabelo", ["curto", "franja", "coque", "longo", "cacheado", "calvo"])},
		{"chave": "chapeu", "titulo": "Chapéu", "tipo": "texto", "valores": ap.get("chapeus", ["nenhum", "bone", "touca"])},
		{"chave": "acessorio", "titulo": "Acessório", "tipo": "texto", "valores": ap.get("acessorios", ["nenhum", "oculos", "mascara"])},
	]
	var ox := r.position.x + 304.0
	var ow := r.size.x - 336.0
	var oy := r.position.y + 106.0
	var altura_linha := (r.size.y - 186.0) / 7.0
	for i in linhas.size():
		var linha: Dictionary = linhas[i]
		var ly := oy + float(i) * altura_linha
		_texto(str(linha.titulo), Vector2(ox, ly + 14), 12, _cor("ui_fraco", "#a9bac8"))
		var chave := str(linha.chave)
		var atual := str(p.get(chave, ""))
		var cx := ox
		var cy := ly + 23.0
		for valor in linha.valores:
			var texto_val := str(valor)
			if str(linha.tipo) == "cor":
				var cr := Rect2(cx, cy, 30, 30)
				_chip_cor("ap:%s:%s" % [chave, texto_val], cr, Color(texto_val), atual.to_upper() == texto_val.to_upper())
				cx += 36.0
			else:
				var rotulo := str(ROTULOS.get(texto_val, texto_val.capitalize()))
				var cw := clampf(_largura(rotulo, 12) + 20.0, 40.0, 96.0)
				_chip_texto("ap:%s:%s" % [chave, texto_val], Rect2(cx, cy, cw, 30), rotulo, atual == texto_val)
				cx += cw + 6.0
	_menu_voltar(r)


func _chip_cor(id: String, r: Rect2, cor: Color, selecionado: bool) -> void:
	_registrar(id, r)
	var borda := _cor("ui_aviso", "#f0b44a") if selecionado else Color(_cor("ui_borda", "#53687a"), 0.75)
	if hover == id:
		draw_rect(r.grow(3), Color(1, 1, 1, 0.16), true)
	VisualScript.retangulo_arredondado(self, r, cor, 7.0)
	VisualScript.contorno_arredondado(self, r, borda, 7.0, 2.6 if selecionado else 1.2)
	if selecionado:
		draw_circle(r.get_center(), 4.0, Color("#17212b"))


func _chip_texto(id: String, r: Rect2, texto: String, selecionado: bool) -> void:
	_registrar(id, r)
	var base := Color(_cor("ui_painel", "#17212b"), 0.72)
	if hover == id:
		base = _cor("ui_painel2", "#22303d").lightened(0.08)
	if selecionado:
		base = _cor("destaque", "#2f8f6b")
	VisualScript.retangulo_arredondado(self, r, base, 7.0)
	VisualScript.contorno_arredondado(self, r,
		_cor("ui_aviso", "#f0b44a") if selecionado else Color(_cor("ui_borda", "#53687a"), 0.75),
		7.0, 2.0 if selecionado else 1.0)
	_texto(texto, Vector2(r.position.x, r.position.y + 20), 12, _cor("ui_texto", "#f4f7fa"),
		HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


func _menu_aparencia(w: float, h: float) -> void:
	var r := _menu_painel(w, h, 900.0, 500.0)
	_menu_titulo(r, "Aparência do postinho", "Escolha a paleta que combina com o seu posto.")
	var temas := [
		{"id": "classico", "nome": "Clássico acolhedor", "desc": "Madeira, tons quentes e muita luz."},
		{"id": "moderno", "nome": "Moderno", "desc": "Superfícies claras e azul tranquilo."},
		{"id": "quente", "nome": "Tons quentes", "desc": "Terracota e aconchego no fim do dia."},
	]
	var atual := str(prefs.get("tema", "classico"))
	var larg := (r.size.x - 88.0) / 3.0
	for i in temas.size():
		var tema: Dictionary = temas[i]
		var tr := Rect2(r.position.x + 28 + float(i) * (larg + 16), r.position.y + 102, larg, r.size.y - 174)
		_registrar("tema:%s" % str(tema.id), tr)
		var pal: Dictionary = main.paletas.get(str(tema.id), {})
		var principal := Color(pal.get("destaque", "#2f8f6b"))
		var fundo := Color(pal.get("ui_painel2", "#22303d"))
		if atual == str(tema.id):
			_painel(tr, fundo.lightened(0.04), 14.0, _cor("ui_aviso", "#f0b44a"))
		else:
			_painel(tr, fundo, 14.0, Color(_cor("ui_borda", "#53687a"), 0.60))
		var prev := Rect2(tr.position.x + 14, tr.position.y + 16, tr.size.x - 28, 150)
		VisualScript.retangulo_arredondado(self, prev, Color(pal.get("piso", "#d9d2c1")), 10.0)
		draw_rect(Rect2(prev.position.x + 8, prev.position.y + 8, prev.size.x - 16, 34), Color(pal.get("parede", "#f3eee2")), true)
		draw_rect(Rect2(prev.position.x + 18, prev.position.y + 58, prev.size.x - 36, 12), Color(pal.get("mesa", "#b48755")), true)
		draw_rect(Rect2(prev.position.x + 18, prev.position.y + 70, 8, 26), Color(pal.get("mesa_esc", "#7e5a34")), true)
		draw_rect(Rect2(prev.end.x - 34, prev.position.y + 70, 8, 26), Color(pal.get("mesa_esc", "#7e5a34")), true)
		draw_circle(prev.position + Vector2(34, 112), 22.0, Color(pal.get("cadeira", "#6f8f86")), true)
		draw_circle(prev.end - Vector2(34, 38), 20.0, Color(principal, 0.75), true)
		draw_rect(Rect2(prev.position.x + 8, prev.end.y - 18, prev.size.x - 16, 8), Color(pal.get("piso2", "#e7e0d0")), true)
		_texto(str(tema.nome), Vector2(tr.position.x + 16, tr.position.y + 198), 17, _cor("ui_texto", "#f4f7fa"))
		draw_multiline_string(_f(), Vector2(tr.position.x + 16, tr.position.y + 222), str(tema.desc),
			HORIZONTAL_ALIGNMENT_LEFT, tr.size.x - 32, 12, 2, _cor("ui_fraco", "#a9bac8"))
		if atual == str(tema.id):
			draw_circle(tr.position + Vector2(tr.size.x - 24, 24), 10.0, _cor("ui_aviso", "#f0b44a"))
			_texto_centro("✓", tr.position + Vector2(tr.size.x - 24, 23), 14, Color("#17212b"))
	_menu_voltar(r)


func _menu_regras(w: float, h: float) -> void:
	var r := _menu_painel(w, h, 800.0, 586.0)
	_menu_titulo(r, "Regras da dinâmica", "Ajuste o ritmo sem mudar as regras do atendimento.")
	_texto("O postinho continua funcionando enquanto você conversa, trabalha ou toma café.",
		Vector2(r.position.x + 28, r.position.y + 108), 12, _cor("ui_fraco", "#a9bac8"))
	_texto("Não existe vitória, derrota ou resposta certa: o jogo é a rotina do posto.",
		Vector2(r.position.x + 28, r.position.y + 126), 12, Color("#b99cf0"))
	var regras: Dictionary = prefs.get("regras", {})
	var vel := float(regras.get("velocidade", 1.0))

	# Ritmo geral.
	var y := r.position.y + 140.0
	_texto("Ritmo do dia", Vector2(r.position.x + 28, y + 24), 14, _cor("ui_texto", "#f4f7fa"))
	var opcoes := [{"v": 0.8, "t": "Tranquilo"}, {"v": 1.0, "t": "Normal"}, {"v": 1.3, "t": "Corrido"}]
	var bx := r.position.x + 300.0
	for op in opcoes:
		var sel := absf(vel - float(op.v)) < 0.01
		_botao("regra:ritmo:%s" % str(op.v), Rect2(bx, y, 138, 40),
			"%s (%.1fx)" % [str(op.t), float(op.v)], "primario" if sel else "secundario", sel, 13)
		bx += 148.0

	y += 66.0
	_texto("Frequência das demandas", Vector2(r.position.x + 28, y + 24), 14, _cor("ui_texto", "#f4f7fa"))
	_controle_mult("demandas", r, y, float(regras.get("demandas", 1.0)))
	y += 64.0
	_texto("Chegada de pacientes", Vector2(r.position.x + 28, y + 24), 14, _cor("ui_texto", "#f4f7fa"))
	_controle_mult("pacientes", r, y, float(regras.get("pacientes", 1.0)))
	y += 64.0
	_texto("Paciência dos pacientes", Vector2(r.position.x + 28, y + 24), 14, _cor("ui_texto", "#f4f7fa"))
	_controle_mult("paciencia", r, y, float(regras.get("paciencia", 1.0)))

	y += 78.0
	_botao("regra:reset", Rect2(r.position.x + 28, y, 180, 40), "Restaurar padrão", "fantasma", false, 13)
	draw_multiline_string(_f(), Vector2(r.position.x + 232, y + 16),
		"Multiplicadores abaixo de 100% deixam o posto mais calmo. Acima de 100%, mais movimento e espera.",
		HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 268, 12, 2, _cor("ui_fraco", "#a9bac8"))
	_menu_voltar(r)


func _controle_mult(chave: String, r: Rect2, y: float, valor: float) -> void:
	var cx := r.position.x + 300.0
	_botao("regra:mult:%s:-" % chave, Rect2(cx, y + 2, 42, 40), "−", "secundario", false, 20)
	var vr := Rect2(cx + 50, y + 2, 116, 40)
	VisualScript.retangulo_arredondado(self, vr, Color(_cor("ui_painel", "#17212b"), 0.72), 9.0)
	VisualScript.contorno_arredondado(self, vr, Color(_cor("ui_borda", "#53687a"), 0.75), 9.0, 1.0)
	_texto("%d%%" % int(round(valor * 100.0)), Vector2(vr.position.x, y + 29), 16,
		_cor("ui_texto", "#f4f7fa"), HORIZONTAL_ALIGNMENT_CENTER, vr.size.x)
	_botao("regra:mult:%s:+" % chave, Rect2(cx + 174, y + 2, 42, 40), "+", "secundario", false, 20)


func _menu_sons(w: float, h: float) -> void:
	var r := _menu_painel(w, h, 660.0, 420.0)
	_menu_titulo(r, "Sons", "Efeitos curtos gerados em tempo real, sem arquivos externos.")
	var ligado := bool(prefs.get("sons", true))
	var centro := Vector2(r.get_center().x, r.position.y + 168)
	# Alto-falante.
	draw_rect(Rect2(centro + Vector2(-58, -14), Vector2(24, 28)), _cor("ui_painel2", "#22303d"), true)
	draw_colored_polygon(PackedVector2Array([
		centro + Vector2(-34, -14), centro + Vector2(-4, -34),
		centro + Vector2(-4, 34), centro + Vector2(-34, 14),
	]), _cor("ui_painel2", "#22303d"))
	if ligado:
		for i in 2:
			draw_arc(centro + Vector2(-2, 0), 26.0 + float(i) * 14.0, -0.9, 0.9, 16,
				_cor("ui_destaque", "#43c38d"), 3.0, true)
	else:
		draw_line(centro + Vector2(18, -24), centro + Vector2(58, 24), _cor("ui_perigo", "#e36a61"), 4.0, true)
		draw_line(centro + Vector2(58, -24), centro + Vector2(18, 24), _cor("ui_perigo", "#e36a61"), 4.0, true)
	_texto("Sons ligados" if ligado else "Sons desligados", Vector2(r.position.x, centro.y + 74), 20,
		_cor("ui_texto", "#f4f7fa"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	_botao("sons:toggle", Rect2(r.get_center().x - 180, centro.y + 98, 170, 48),
		"Desligar" if ligado else "Ligar", "primario" if not ligado else "secundario", false, 17)
	_botao("sons:teste", Rect2(r.get_center().x + 10, centro.y + 98, 170, 48),
		"Testar som", "secundario", false, 17)
	_menu_voltar(r)


func _menu_info(w: float, h: float) -> void:
	var r := _menu_painel(w, h, 900.0, 620.0)
	_menu_titulo(r, "Informações e estatísticas", "Um retrato da sua rotina no postinho.")
	var esquerda := Rect2(r.position.x + 28, r.position.y + 102, 430, r.size.y - 178)
	var direita := Rect2(r.position.x + 480, r.position.y + 102, r.size.x - 508, r.size.y - 178)
	VisualScript.retangulo_arredondado(self, esquerda, Color(_cor("ui_painel2", "#22303d"), 0.52), 14.0)
	VisualScript.retangulo_arredondado(self, direita, Color(_cor("ui_painel2", "#22303d"), 0.52), 14.0)

	var pacientes_no_posto := 0
	for p in gm.pessoas:
		if str(p.tipo) == "paciente" and p.visivel and not p.oculto and str(p.fase) not in ["saindo", "saiu"]:
			pacientes_no_posto += 1
	var stats := [
		["Pacientes no posto", str(pacientes_no_posto)],
		["Tarefas concluídas", str(gm.count("tarefas_concluidas"))],
		["Cafés tomados", str(gm.count("cafes"))],
		["Conversas de corredor", str(gm.count("papos_respondidos"))],
		["Conversas com animais", str(gm.count("papos_animais"))],
		["Pacientes atendidos", str(gm.count("pacientes_atendidos"))],
		["Demandas aceitas", str(gm.count("demandas_aceitas"))],
		["Atendidos no guichê", str(gm.count("atendidos_guiche"))],
		["Atendidos nas salas", str(gm.count("atendidos_sala"))],
		["Atendidos na recepção", str(gm.count("atendidos_recepcao"))],
		["Computadores consertados", str(gm.count("pcs_consertados"))],
		["Impressoras consertadas", str(gm.count("impressoras_consertadas"))],
		["Exames encontrados", str(gm.count("exames_encontrados"))],
		["Desistências", str(gm.count("desistencias") + gm.count("desistencias_fila") + gm.count("desistencias_tolerancia"))],
	]
	var sy := esquerda.position.y + 26.0
	for i in stats.size():
		var linha: Array = stats[i]
		if i % 2 == 0:
			draw_rect(Rect2(esquerda.position.x + 12, sy - 12, esquerda.size.x - 24, 25), Color(_cor("ui_painel", "#17212b"), 0.35), true)
		_texto(str(linha[0]), Vector2(esquerda.position.x + 24, sy + 7), 13, _cor("ui_fraco", "#a9bac8"))
		_texto(str(linha[1]), Vector2(esquerda.position.x + 24, sy + 7), 14, _cor("ui_texto", "#f4f7fa"),
			HORIZONTAL_ALIGNMENT_RIGHT, esquerda.size.x - 48)
		sy += 29.0

	_texto("Sobre", Vector2(direita.position.x + 22, direita.position.y + 34), 16, _cor("ui_texto", "#f4f7fa"))
	draw_multiline_string(_f(), Vector2(direita.position.x + 22, direita.position.y + 60),
		"Um jogo sobre a rotina de um Agente Comunitário de Saúde: acolher, escutar e resolver as demandas da comunidade. Não há prova, vitória ou derrota: você acompanha a vida do posto.",
		HORIZONTAL_ALIGNMENT_LEFT, direita.size.x - 44, 13, 5, _cor("ui_fraco", "#a9bac8"))
	_texto(VersaoPostinho.completo(),
		Vector2(direita.position.x + 22, direita.position.y + 148), 12, _cor("ui_fraco", "#a9bac8"))
	_texto("mmr05@hotmail.com  •  11 97883-1938",
		Vector2(direita.position.x + 22, direita.position.y + 166), 10, Color(_cor("ui_fraco", "#a9bac8"), 0.9))

	_botao("info:play", Rect2(direita.position.x + 22, direita.position.y + 180, direita.size.x - 44, 44),
		"Baixar a versão mais recente", "primario", false, 13)
	_botao("info:contato", Rect2(direita.position.x + 22, direita.position.y + 236, direita.size.x - 44, 44),
		"Falar com o desenvolvedor", "secundario", false, 13)
	draw_multiline_string(_f(), Vector2(direita.position.x + 22, direita.position.y + 312),
		"Os links abrem no navegador ou aplicativo de e-mail do aparelho.",
		HORIZONTAL_ALIGNMENT_LEFT, direita.size.x - 44, 11, 2, Color(_cor("ui_fraco", "#a9bac8"), 0.85))
	_menu_voltar(r)


func _menu_fechar(w: float, h: float) -> void:
	var r := _menu_painel(w, h, 560.0, 268.0)
	_menu_titulo(r, "Fechar jogo", "O progresso do seu agente será salvo automaticamente.")
	var texto := "Tem certeza que deseja fechar o jogo?"
	draw_multiline_string(_f(), Vector2(r.position.x + 28, r.position.y + 122), texto,
		HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 56, 18, 2, _cor("ui_texto", "#f4f7fa"))
	_botao("fechar:sim", Rect2(r.position.x + 36, r.end.y - 74, (r.size.x - 84) * 0.5, 46),
		"Sim, fechar", "perigo", false, 16)
	_botao("fechar:nao", Rect2(r.position.x + 48 + (r.size.x - 84) * 0.5, r.end.y - 74, (r.size.x - 84) * 0.5, 46),
		"Continuar jogando", "primario", false, 16)


# =================================================================== utilidades
