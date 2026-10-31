extends SceneTree
## Teste de interface com cliques, arrasto, zoom e pinça de verdade.
##   godot --path . --script res://tests/cliques.gd
## O teste abre uma janela, usa os botoes desenhados pelo HUD e fecha sozinho.

const PREFS_PATH := "user://preferencias.json"
const SESSAO_PATH := "user://sessao_postinho.dat"

var falhas := 0
var ok := 0
var main: Node2D
var hud
var gm
var prefs_original := ""
var tinha_prefs := false
var sessao_original := PackedByteArray()
var tinha_sessao := false
var terminou := false


func _initialize() -> void:
	print("=== TESTE DE CLIQUES E INTERFACE ===")
	tinha_prefs = FileAccess.file_exists(PREFS_PATH)
	if tinha_prefs:
		var arq := FileAccess.open(PREFS_PATH, FileAccess.READ)
		if arq != null:
			prefs_original = arq.get_as_text()
			arq.close()
	var alarme := create_timer(300.0)
	alarme.timeout.connect(func():
		if not terminou:
			print("\nCLIQUES INTERROMPIDO: tempo esgotado")
			quit(2))
	tinha_sessao = FileAccess.file_exists(SESSAO_PATH)
	if tinha_sessao:
		sessao_original = FileAccess.get_file_as_bytes(SESSAO_PATH)
	main = load("res://scenes/Main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	gm = main.gm
	hud = main.hud
	if hud == null or gm == null:
		print("FALHA: a cena principal nao carregou o HUD ou o jogo")
		quit(1)
		return
	_checar(bool(hud.tela_inicio), "a tela inicial aparece logo ao abrir o jogo")
	await _testar_tela_inicio()
	await _aguardar(4.0, func(): return hud.botoes.size() > 0)
	_checar(hud.botoes.size() > 0, "o HUD desenhou os botoes")
	_checar(str(hud.info_hud) == "Saguão tranquilo" or "Fila do guichê" in str(hud.info_hud),
		"o HUD mostra a fila do guichê")
	_checar(not ("PCs" in str(hud.info_hud)) and not hud.has_method("_fmt_tempo"),
		"o HUD não voltou a mostrar PCs nem relógio de sessão")
	_checar(await _aguardar(8.0, func(): return bool(gm.jogador().visivel) and int(gm.estado) == int(gm.Estado.LIVRE)),
		"o jogador entrou e esta livre")
	gm.modo_pcs = "um_de_cada"
	gm._aplicar_modo_pcs()
	await _pausa(0.2)

	await _testar_pc_e_esforco()
	await _testar_camera()
	await _testar_menu()
	await _testar_dialogo()
	await _testar_papo()
	await _testar_recepcao_e_portas()
	await _testar_consertos()
	await _finalizar()


func _testar_tela_inicio() -> void:
	print("[tela inicial]")
	gm.salvar_sessao()
	hud.tela_inicio = true
	hud.queue_redraw()
	await _pausa(0.25)
	var t0: float = gm.tempo
	await _pausa(0.35)
	_checar(bool(hud.pausado()) and absf(float(gm.tempo) - t0) < 0.001,
		"a tela inicial pausa a simulacao")
	_checar(_tem_botao("inicio:continuar") and _tem_botao("inicio:nova"),
		"a tela inicial oferece continuar ou iniciar nova sessao")
	_checar(_clicar_botao("inicio:continuar"), "o botao Continuar sessao existe")
	var entrou: bool = await _aguardar(3.0, func(): return not bool(hud.tela_inicio))
	_checar(entrou, "Continuar sessao fecha a tela inicial")
	await _pausa(0.2)
	hud.tela_inicio = true
	hud.queue_redraw()
	await _pausa(0.25)
	_checar(_clicar_botao("inicio:nova"), "o botao Nova sessao existe")
	entrou = await _aguardar(3.0, func(): return not bool(hud.tela_inicio))
	_checar(entrou, "Nova sessao fecha a tela inicial")
	await _pausa(0.35)


# =================================================================== mundo

func _testar_pc_e_esforco() -> void:
	print("[computador e esforco]")
	var pc = null
	for item in gm.pcs:
		if str(item.tipo) == "interno" and str(item.ocupante) == "" and not bool(item.jogador):
			pc = item
			break
	_checar(pc != null, "ha um PC interno livre")
	if pc == null:
		return
	gm.tarefas = 3
	var ponto: Vector2 = main._para_mundo(main.camera.position) # apenas garante a camera ativa
	ponto = _tela_mundo(pc.pos)
	_checar(not hud.ponto_em_ui(ponto), "o PC nao fica coberto pelo HUD")
	_clicar_tela(ponto)
	var sentou: bool = await _aguardar(12.0, func(): return int(gm.estado) == int(gm.Estado.NO_PC))
	_checar(sentou, "clicar no PC livre coloca o jogador no computador")
	_checar(bool(pc.jogador) and gm.foco == pc, "o PC usado fica marcado para o jogador")
	if not sentou:
		return
	_checar(int(gm.jogador().facing) == 1, "o jogador trabalha virado para a direita")
	gm.prog = 0.0
	gm.energia = 4.0
	await _pausa(0.4)
	_checar(float(gm.prog) > 0.0, "o trabalho rende enquanto o jogador esta no PC")
	_clicar_tela(_tela_mundo(gm.jogador().pos))
	_checar(bool(gm.esforco_manual), "clicar no jogador ativa o esforco manual")
	_clicar_tela(_tela_mundo(gm.jogador().pos))
	_checar(not bool(gm.esforco_manual), "clicar de novo desliga o esforco")
	var chao: Vector2 = gm.pos + Vector2(90, 60)
	_clicar_tela(_tela_mundo(chao))
	await _pausa(0.15)
	_checar(int(gm.estado) == int(gm.Estado.CAMINHANDO) or int(gm.estado) == int(gm.Estado.LIVRE),
		"clicar no chao tira o jogador do PC")
	await _aguardar(6.0, func(): return int(gm.estado) == int(gm.Estado.LIVRE))


# =================================================================== camera

func _testar_camera() -> void:
	print("[camera]")
	var antes: Vector2 = main.camera.position
	var a := Vector2(640, 360)
	var b := Vector2(720, 410)
	_tecla_mouse(a, true)
	await process_frame
	_mover_mouse(b)
	await process_frame
	_tecla_mouse(b, false)
	await _pausa(0.1)
	_checar(main.camera.position.distance_to(antes) > 20.0, "arrastar move a camera")
	_checar(int(gm.estado) == int(gm.Estado.LIVRE) or int(gm.estado) == int(gm.Estado.CAMINHANDO),
		"arrastar nao dispara clique no mundo")

	var z_antes: float = main.camera.zoom.x
	_roda_mouse(Vector2(640, 360), MOUSE_BUTTON_WHEEL_UP)
	await _pausa(0.1)
	_checar(main.camera.zoom.x > z_antes, "roda do mouse aproxima a camera")

	# Pinca com dois toques.
	z_antes = main.camera.zoom.x
	var t1 := Vector2(520, 350)
	var t2 := Vector2(760, 370)
	_toque(0, t1, true)
	await process_frame
	_toque(1, t2, true)
	await process_frame
	_arrastar_toque(0, Vector2(470, 340))
	await process_frame
	_arrastar_toque(1, Vector2(830, 390))
	await process_frame
	_toque(0, Vector2(470, 340), false)
	_toque(1, Vector2(830, 390), false)
	await _pausa(0.1)
	_checar(main.camera.zoom.x > z_antes, "pinca com dois toques da zoom")

	# Botao Agente centraliza no jogador.
	main.camera.position = Vector2(300, 300)
	main.camera.zoom = Vector2(0.82, 0.82)
	await _pausa(0.1)
	_checar(_clicar_botao("centralizar"), "o botao Agente existe")
	await _pausa(0.15)
	_checar(main.camera.position.distance_to(gm.pos) < 2.0 and main.camera.zoom.x >= 1.0,
		"Agente centraliza a camera no jogador")


# =================================================================== menu

func _testar_menu() -> void:
	print("[menu]")
	_checar(_clicar_botao("menu"), "o botao Menu existe")
	await _pausa(0.2)
	_checar(bool(hud.menu_aberto) and str(hud.pagina) == "home", "clicar em Menu abre a pagina inicial")
	var t0: float = gm.tempo
	await _pausa(0.4)
	_checar(absf(float(gm.tempo) - t0) < 0.001 and bool(hud.pausado()), "o menu pausa a simulacao")

	# Personalizacao.
	_checar(_clicar_botao("menu:personalizar"), "o botao Personalizar existe")
	await _pausa(0.2)
	_checar(str(hud.pagina) == "personalizar", "a pagina de personalizacao abre")
	var p: Dictionary = gm.jogador()
	var tons: Array = gm.dnpcs.get("aparencia", {}).get("tons_pele", [])
	var alvo := ""
	for cor in tons:
		if str(cor).to_upper() != str(p.pele).to_upper():
			alvo = str(cor)
			break
	_checar(alvo != "" and _clicar_botao("ap:pele:" + alvo), "ha um chip de pele para escolher")
	await _pausa(0.2)
	_checar(str(gm.jogador().pele).to_upper() == alvo.to_upper(), "o clique troca a cor da pele")
	_checar(str(main.prefs.get("aparencia", {}).get("pele", "")).to_upper() == alvo.to_upper(),
		"a escolha de pele fica nas preferencias")
	_checar(_clicar_botao("menu:voltar"), "o botao Voltar existe na personalizacao")
	await _pausa(0.2)
	_checar(str(hud.pagina) == "home", "Voltar retorna ao menu")

	# Aparencia do postinho.
	_checar(_clicar_botao("menu:aparencia"), "o botao Aparencia existe")
	await _pausa(0.2)
	var tema_antes := str(main.prefs.get("tema", "classico"))
	var tema_novo := "moderno" if tema_antes != "moderno" else "quente"
	_checar(_clicar_botao("tema:" + tema_novo), "ha um tema para escolher")
	await _pausa(0.2)
	_checar(str(main.prefs.get("tema", "")) == tema_novo and main.paleta == main.paletas[tema_novo],
		"o clique troca o tema do postinho")
	_checar(_clicar_botao("menu:voltar"), "Voltar existe na aparencia")
	await _pausa(0.2)

	# Regras.
	_checar(_clicar_botao("menu:regras"), "o botao Regras existe")
	await _pausa(0.2)
	_checar(str(hud.pagina) == "regras", "a pagina de regras abre")
	_checar(_clicar_botao("regra:ritmo:1.3"), "ha um botao de ritmo")
	await _pausa(0.15)
	_checar(absf(float(main.velocidade_sim) - 1.3) < 0.01, "o ritmo escolhido vale para a simulacao")
	var demandas_antes: float = float(main.prefs.get("regras", {}).get("demandas", 1.0))
	_checar(_clicar_botao("regra:mult:demandas:+"), "ha um botao para aumentar demandas")
	await _pausa(0.15)
	_checar(absf(float(main.prefs.get("regras", {}).get("demandas", 1.0)) - (demandas_antes + 0.1)) < 0.01,
		"o multiplicador de demandas sobe de 10 em 10%")
	_checar(_clicar_botao("regra:reset"), "o botao Restaurar padrao existe")
	await _pausa(0.15)
	_checar(absf(float(main.prefs.get("regras", {}).get("demandas", 0.0)) - 1.0) < 0.01
		and absf(float(main.velocidade_sim) - 1.0) < 0.01, "Restaurar padrao volta tudo para 100%")
	_checar(_clicar_botao("menu:voltar"), "Voltar existe nas regras")
	await _pausa(0.2)

	# Sons.
	_checar(_clicar_botao("menu:sons"), "o botao Sons existe")
	await _pausa(0.2)
	_checar(str(hud.pagina) == "sons", "a pagina de sons abre")
	var sons_antes := bool(main.prefs.get("sons", true))
	_checar(_clicar_botao("sons:toggle"), "o botao de ligar/desligar sons existe")
	await _pausa(0.15)
	_checar(bool(main.prefs.get("sons", true)) == (not sons_antes) and bool(gm.sons_ligados) == (not sons_antes),
		"o clique liga ou desliga os sons")
	_checar(_clicar_botao("sons:toggle"), "o botao de sons pode ser acionado de novo")
	await _pausa(0.15)
	_checar(bool(main.prefs.get("sons", true)) == sons_antes, "o som volta ao estado anterior")
	_checar(_clicar_botao("menu:voltar"), "Voltar existe nos sons")
	await _pausa(0.2)

	# Informacoes e estatisticas.
	_checar(_clicar_botao("menu:info"), "o botao Informacoes existe")
	await _pausa(0.2)
	_checar(str(hud.pagina) == "info", "a pagina de informacoes abre")
	_checar(_tem_botao("info:play") and _tem_botao("info:contato"), "os botoes de loja e contato existem")
	_checar(_clicar_botao("menu:voltar"), "Voltar existe nas informacoes")
	await _pausa(0.2)

	# Fechar jogo (sem confirmar).
	_checar(_clicar_botao("menu:fechar"), "o botao Fechar jogo existe")
	await _pausa(0.2)
	_checar(str(hud.pagina) == "fechar", "a confirmacao de fechar abre")
	_checar(_clicar_botao("fechar:nao"), "o botao Continuar jogando existe")
	await _pausa(0.2)
	_checar(str(hud.pagina) == "home" and bool(hud.menu_aberto), "Continuar jogando volta ao menu")
	_checar(_clicar_botao("menu:continuar"), "o botao Continuar existe")
	await _pausa(0.2)
	_checar(not bool(hud.menu_aberto), "Continuar fecha o menu")
	var t1: float = gm.tempo
	await _pausa(0.3)
	_checar(float(gm.tempo) > t1, "a simulacao volta a correr depois do menu")


# =================================================================== dialogo

func _testar_dialogo() -> void:
	print("[dialogo]")
	if gm.modal != null:
		gm.fechar_dialogo()
	await _aguardar_livre()
	var chefe = gm.entidades["chefe"]
	chefe.visivel = true
	chefe.oculto = false
	chefe.demanda = null
	gm.tarefas = 2
	gm._criar_demanda(chefe, true)
	await _pausa(0.15)
	var ponto: Vector2 = _tela_mundo(chefe.pos)
	_clicar_tela(ponto)
	var abriu: bool = await _aguardar(2.0, func(): return gm.modal != null)
	_checar(abriu, "clicar no funcionario com demanda abre o dialogo")
	_checar(not bool(hud.pausado()), "o dialogo nao pausa a simulacao")
	var t_conversa: float = gm.tempo
	await _pausa(0.35)
	_checar(float(gm.tempo) > t_conversa, "o posto continua rodando durante a conversa")
	_checar(int(gm.estado) == int(gm.Estado.CONVERSANDO), "o jogador entra no estado conversando")
	if abriu:
		await _pausa(0.15)
		var tarefas_antes: int = gm.tarefas
		_checar(_clicar_botao("dialogo:opcao:0"), "o botao da primeira resposta existe")
		await _pausa(0.2)
		_checar(gm.modal == null, "responder fecha o dialogo")
		_checar(int(gm.tarefas) != tarefas_antes or gm.count("demandas_aceitas") > 0,
			"a resposta produz consequencia")
		_checar(not bool(hud.pausado()), "a simulacao volta a correr depois da conversa")
	# Fechar pelo X.
	chefe.demanda = null
	gm._criar_demanda(chefe, true)
	await _pausa(0.15)
	_clicar_tela(_tela_mundo(chefe.pos))
	var reabriu: bool = await _aguardar(2.0, func(): return gm.modal != null)
	if reabriu:
		await _pausa(0.2)
		_checar(not bool(hud.pausado()), "o segundo dialogo tambem roda com o posto ativo")
	if gm.modal != null:
		_checar(_clicar_botao("dialogo:fechar"), "o X do dialogo existe")
		await _pausa(0.2)
		_checar(gm.modal == null, "o X fecha o dialogo")
	if chefe.demanda != null:
		gm._limpar_demanda(chefe)


# =================================================================== papo de corredor

func _testar_papo() -> void:
	print("[papo de corredor]")
	if gm.modal != null:
		gm.fechar_dialogo()
	await _aguardar_livre()
	var medica = gm.entidades["medica"]
	medica.visivel = true
	medica.oculto = false
	medica.entrou = true
	medica.fase = "no_posto"
	medica.demanda = null
	medica.papo = null
	medica.servindo = ""
	medica.energia = medica.max_energia
	main.camera.position = medica.pos
	main.camera.zoom = Vector2(0.82, 0.82)
	await _pausa(0.1)
	var surgiu: bool = gm._abrir_papo_ambiente(medica)
	_checar(surgiu and medica.papo != null, "o funcionario inicia um papo de corredor")
	await _pausa(0.15)
	_clicar_tela(_tela_mundo(medica.pos))
	var abriu: bool = await _aguardar(2.0, func(): return gm.modal != null)
	_checar(abriu, "clicar no balao abre a janela de papo")
	_checar(abriu and str(gm.modal.get("tipo", "")) == "papo", "a janela e identificada como papo")
	_checar(not bool(hud.pausado()), "o papo tambem roda com o posto ativo")
	var t_papo: float = gm.tempo
	await _pausa(0.3)
	_checar(float(gm.tempo) > t_papo, "o posto continua rodando durante o papo")
	if abriu:
		await _pausa(0.15)
		var tarefas_antes: int = gm.tarefas
		var energia_antes: float = gm.energia
		_checar(_tem_botao("dialogo:opcao:0") and _tem_botao("dialogo:opcao:1"),
			"as duas respostas sociais aparecem")
		_checar(_clicar_botao("dialogo:opcao:0"), "a primeira resposta pode ser clicada")
		await _pausa(0.2)
		_checar(str(gm.modal.get("fase", "")) == "resposta", "a replica do funcionario aparece")
		_checar(not _tem_botao("dialogo:opcao:1") and _tem_botao("dialogo:opcao:0"),
			"a replica tem um botao unico")
		_checar(gm.tarefas == tarefas_antes and absf(gm.energia - energia_antes) < 0.001,
			"o papo nao gasta energia nem cria tarefa")
		_checar(_clicar_botao("dialogo:opcao:0"), "o botao da replica existe")
		await _pausa(0.2)
		_checar(gm.modal == null and medica.papo == null,
			"encerrar o papo fecha a janela e libera o funcionario")
		_checar(not bool(hud.pausado()), "a simulacao volta depois do papo")
		_checar(gm.count("papos_respondidos") >= 1, "a conversa entra nas estatisticas")

	# Fechar pelo X durante o papo.
	medica.demanda = null
	medica.papo = null
	medica.fase = "no_posto"
	medica.servindo = ""
	gm._abrir_papo_ambiente(medica)
	await _pausa(0.15)
	_clicar_tela(_tela_mundo(medica.pos))
	var reabriu: bool = await _aguardar(2.0, func(): return gm.modal != null)
	_checar(reabriu, "o papo pode ser reaberto")
	if reabriu:
		await _pausa(0.15)
		_checar(_clicar_botao("dialogo:fechar"), "o X do papo existe")
		await _pausa(0.2)
		_checar(gm.modal == null and medica.papo == null, "o X encerra o papo sem resposta")
	main.centralizar_jogador()
	await _pausa(0.15)


func _testar_recepcao_e_portas() -> void:
	print("[recepcao e portas]")
	await _aguardar_livre()
	# Congela o sorteio dos PCs para garantir um posto livre durante o teste.
	gm.PC_INTERVALO_MIN = 9000.0
	gm.PC_INTERVALO_MAX = 9000.0
	gm.agenda_pcs = 9000.0
	gm.modo_pcs = "um_de_cada"
	gm._aplicar_modo_pcs()
	await _pausa(0.2)
	var rec = null
	var melhor := -1.0
	for item in gm.pcs:
		if str(item.tipo) != "recepcao" or str(item.ocupante) != "" or bool(item.jogador):
			continue
		var dist := 9999.0
		for p in gm.pessoas:
			if not bool(p.visivel) or bool(p.oculto):
				continue
			dist = minf(dist, (p.pos as Vector2).distance_to(item.pos))
		if dist > melhor:
			melhor = dist
			rec = item
	_checar(rec != null, "ha um PC de recepcao livre")
	_checar(melhor > 30.0, "ha um PC de recepcao sem ninguem na frente")
	if rec == null:
		for item in gm.pcs:
			if str(item.tipo) == "recepcao":
				print("    rec ", str(item.id), " ocupante=", str(item.ocupante),
					" jogador=", bool(item.jogador), " problema=", str(item.problema))
	if rec != null:
		_clicar_tela(_tela_mundo(rec.pos))
		var sentou: bool = await _aguardar(12.0, func(): return int(gm.estado) == int(gm.Estado.NO_PC))
		if not sentou:
			print("    estado=", gm.estado, " atendendo=", gm.atendendo_paciente,
				" modal=", gm.modal != null, " alerta=", gm.alertas.back() if not gm.alertas.is_empty() else {})
		_checar(sentou and gm.foco == rec, "clicar no PC da recepcao senta o jogador")
		if sentou:
			_clicar_tela(_tela_mundo(gm.pos + Vector2(70, 60)))
			await _pausa(0.2)
	await _aguardar_livre()

	gm.alertas.clear()
	var seta: Vector2 = gm._vet(gm.entrada.get("seta_saida", [1462, 170]))
	_clicar_tela(_tela_mundo(seta))
	await _pausa(0.1)
	_checar(not gm.alertas.is_empty(), "clicar na seta de saida mostra um aviso")
	if not gm.alertas.is_empty():
		var aviso := str(gm.alertas.back().get("texto", "")).to_lower()
		_checar("vers" in aviso, "o aviso da saida fala de versao futura")

	gm.alertas.clear()
	var lat: Rect2 = gm._rect_de(gm.porta_lateral.get("rect"), Rect2(1542, 452, 18, 96))
	_clicar_tela(_tela_mundo(lat.get_center()))
	await _pausa(0.1)
	_checar(not gm.alertas.is_empty(), "clicar na porta lateral mostra um aviso")
	if not gm.alertas.is_empty():
		var aviso2 := str(gm.alertas.back().get("texto", "")).to_lower()
		_checar("vers" in aviso2 or "atualiz" in aviso2 or "futur" in aviso2,
			"o aviso da porta lateral fala de versao futura")


func _testar_consertos() -> void:
	print("[consertos e arquivo]")
	if gm.modal != null:
		gm.fechar_dialogo()
	await _aguardar_livre()

	# Atalho do HUD e conserto da impressora.
	gm.impressora.quebrada = true
	hud.queue_redraw()
	await _pausa(0.25)
	_checar(_clicar_botao("impressora:focar"), "o atalho da impressora existe")
	await _pausa(0.35)
	_checar(main.camera.position.distance_to(gm.impressora.pos) < 280.0,
		"o atalho leva a camera ate a impressora")
	_clicar_tela(_tela_mundo(gm.impressora.pos))
	var abriu: bool = await _aguardar(2.0,
		func(): return gm.modal != null and str(gm.modal.get("tipo", "")) == "reparo")
	_checar(abriu, "clicar na impressora quebrada abre o reparo")
	if abriu:
		_checar(not bool(hud.pausado()), "o reparo nao pausa o posto")
		# O modal pode aparecer antes do proximo desenho do HUD; espere os fios
		# serem registrados antes de clicar neles.
		var tem_fios: bool = await _aguardar(1.5, func(): return _tem_botao("minijogo:0"))
		_checar(tem_fios, "os fios do reparo ficam clicaveis")
		var seq: Array = gm.modal.get("sequencia", [])
		for fio in seq:
			var id := "minijogo:%d" % int(fio)
			if not _tem_botao(id):
				print("    fio ausente no HUD: ", id)
				break
			_clicar_botao(id)
			await _pausa(0.12)
		_checar(gm.modal == null and not bool(gm.impressora.quebrada),
			"a sequencia certa conserta a impressora")

	# Arquivo de exames no estilo "onde esta o exame?".
	var abriu_exame: bool = gm.abrir_exame({})
	await _pausa(0.25)
	_checar(abriu_exame and gm.modal != null and str(gm.modal.get("tipo", "")) == "exame",
		"o arquivo de exames abre")
	if gm.modal != null and str(gm.modal.get("tipo", "")) == "exame":
		_checar(not bool(hud.pausado()), "o arquivo de exames tambem roda com o posto ativo")
		var alvo := int(gm.modal.get("alvo", -1))
		_checar(_clicar_botao("exame:%d" % alvo), "a pasta certa esta clicavel")
		await _pausa(0.25)
		_checar(gm.modal == null and not bool(gm.exame_busca.get("ativo", true)),
			"achar a pasta conclui a busca")


# =================================================================== util

func _checar(condicao: bool, nome: String) -> void:
	if condicao:
		ok += 1
		print("  ok    ", nome)
	else:
		falhas += 1
		print("  FALHA ", nome)


func _pausa(seg: float) -> void:
	await create_timer(seg).timeout


func _aguardar(max_t: float, condicao: Callable) -> bool:
	var t := 0.0
	while t < max_t:
		if bool(condicao.call()):
			return true
		await create_timer(0.05).timeout
		t += 0.05
	return bool(condicao.call())


func _aguardar_livre() -> void:
	await _aguardar(8.0, func():
		return int(gm.estado) == int(gm.Estado.LIVRE) and gm.modal == null and gm.atendendo_paciente == "")


func _tela_mundo(p: Vector2) -> Vector2:
	return main.get_viewport().get_canvas_transform() * p


func _clicar_tela(p: Vector2) -> void:
	_tecla_mouse(p, true)
	_tecla_mouse(p, false)


func _clicar_botao(id: String) -> bool:
	for b in hud.botoes:
		if str(b.get("id", "")) == id:
			_clicar_tela((b.rect as Rect2).get_center())
			return true
	return false


func _tem_botao(id: String) -> bool:
	for b in hud.botoes:
		if str(b.get("id", "")) == id:
			return true
	return false


func _tecla_mouse(p: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = p
	get_root().push_input(ev)


func _roda_mouse(p: Vector2, botao: int) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = botao
	ev.pressed = true
	ev.position = p
	get_root().push_input(ev)


func _mover_mouse(p: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = p
	ev.relative = Vector2.ZERO
	get_root().push_input(ev)


func _toque(indice: int, p: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = indice
	ev.position = p
	ev.pressed = pressed
	get_root().push_input(ev)


func _arrastar_toque(indice: int, p: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = indice
	ev.position = p
	ev.relative = Vector2.ZERO
	get_root().push_input(ev)


func _finalizar() -> void:
	terminou = true
	var total: int = ok + falhas
	if falhas == 0:
		print("\nCLIQUES OK: ", total, " verificacoes")
	else:
		print("\nCLIQUES COM FALHAS: ", falhas, " de ", total)
	if main != null and is_instance_valid(main):
		main.queue_free()
		await process_frame
		await process_frame
	if tinha_prefs:
		var arq := FileAccess.open(PREFS_PATH, FileAccess.WRITE)
		if arq != null:
			arq.store_string(prefs_original)
			arq.close()
	else:
		var caminho := ProjectSettings.globalize_path(PREFS_PATH)
		if FileAccess.file_exists(PREFS_PATH):
			DirAccess.remove_absolute(caminho)
	if tinha_sessao:
		var arq_s := FileAccess.open(SESSAO_PATH, FileAccess.WRITE)
		if arq_s != null:
			arq_s.store_buffer(sessao_original)
			arq_s.close()
	elif FileAccess.file_exists(SESSAO_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSAO_PATH))
	quit(0 if falhas == 0 else 1)
