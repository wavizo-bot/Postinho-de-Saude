extends SceneTree
## Testes de regras do Postinho de Saude, sem janela:
##   godot --headless --path . --script res://tests/testes.gd
## Cada verificacao imprime "ok" ou "FALHA".

const VersaoScript = preload("res://scripts/VersaoPostinho.gd")

var falhas := 0
var ok := 0


func _initialize() -> void:
	print("=== TESTES DO POSTINHO ===")
	_testar_versao()
	_testar_dados()
	_testar_entrada_e_movimento()
	_testar_trabalho()
	_testar_esforco_e_aura()
	_testar_cafe()
	_testar_limite()
	_testar_computadores()
	_testar_salas()
	_testar_pacientes_e_criancas()
	_testar_fluxo_de_demanda()
	_testar_abordagem()
	_testar_demandas_dos_funcionarios()
	_testar_papos()
	_testar_sessao_consertos_exames()
	_testar_partida_longa()
	if falhas == 0:
		print("\nTODOS OS ", ok, " TESTES PASSARAM")
		quit(0)
	else:
		print("\n", falhas, " FALHA(S), ", ok, " OK")
		quit(1)


func checar(condicao: bool, nome: String) -> void:
	if condicao:
		ok += 1
		print("  ok    ", nome)
	else:
		falhas += 1
		print("  FALHA ", nome)


func _novo(semente: int = -1, avisar: bool = true) -> Node:
	var gm: Node = load("res://scripts/GameManager.gd").new()
	var carregou: bool = gm.carregar_dados()
	if avisar:
		checar(carregou, "dados carregam: " + str(gm.erros_dados))
	gm.iniciar(semente)
	return gm


func _limpar_pacientes(gm: Node) -> void:
	for p in gm.pessoas.duplicate():
		if str(p.tipo) in ["paciente", "crianca"]:
			gm.pessoas.erase(p)
			gm.entidades.erase(str(p.id))
	gm.fila_guiche.clear()
	gm.fila_recepcao.clear()
	gm.guiche_atendendo = ""
	gm.guiche_timer = 0.0


func _novo_limpo(semente: int) -> Node:
	var gm: Node = _novo(semente, false)
	gm.DEM_MIN = 9000.0
	gm.DEM_MAX = 9000.0
	gm.prox_demanda = 9000.0
	gm.NOVO_PAC_MIN = 9000.0
	gm.NOVO_PAC_MAX = 9000.0
	gm.prox_paciente = 9000.0
	gm.PC_INTERVALO_MIN = 9000.0
	gm.PC_INTERVALO_MAX = 9000.0
	gm.agenda_pcs = 9000.0
	gm.PC_PROBLEMA_CHANCE = 0.0
	gm.agenda_problema = 9000.0
	gm.PC_INTERRUPCAO_CHANCE = 0.0
	gm.PC_ABORDAGEM_CHANCE = 0.0
	gm.cfg["funcionarios"]["chance_passeio_medica_s"] = 0.0
	gm.cfg["funcionarios"]["chance_passeio_enfermeira_s"] = 0.0
	gm.cfg["funcionarios"]["chance_passeio_auxiliar_s"] = 0.0
	gm.cfg["funcionarios"]["chance_passeio_recepcao_s"] = 0.0
	_limpar_pacientes(gm)
	return gm


func _pc_livre(gm: Node, tipo: String):
	for pc in gm.pcs:
		if str(pc.tipo) != tipo:
			continue
		if str(pc.ocupante) != "" or bool(pc.jogador) or str(pc.problema) == "grave":
			continue
		if tipo == "sala" and not gm._pc_disponivel_jogador(pc):
			continue
		return pc
	return null


func _esperar(gm: Node, max_t: float, condicao: Callable, passo: float = 0.1) -> bool:
	var t := 0.0
	while t < max_t:
		if bool(condicao.call()):
			return true
		gm.step(passo)
		t += passo
	return bool(condicao.call())


func _preparar_jogador(gm: Node) -> bool:
	var ok_jogador: bool = _esperar(gm, 12.0, func(): return gm.estado == gm.Estado.LIVRE and gm.jogador().visivel)
	return ok_jogador


func _usar_pc(gm: Node, pc, max_t: float = 25.0) -> bool:
	gm.clicar_pc(str(pc.id))
	return _esperar(gm, max_t, func(): return gm.estado == gm.Estado.NO_PC)


func _testar_versao() -> void:
	print("")
	print("[versao]")
	var info: Dictionary = VersaoScript.info()
	var config := str(ProjectSettings.get_setting("application/config/version", ""))
	checar(FileAccess.file_exists("res://version.json"), "version.json existe no build")
	checar(not str(info.get("versao", "")).is_empty(), "versao exibida nao esta vazia")
	checar(str(info.get("versao", "")) == config,
		"versao exibida igual ao project.godot (%s)" % config)
	checar(int(info.get("codigo", 0)) >= 1, "codigo de build valido")
	checar(str(info.get("windows", "")).begins_with(config),
		"versao Windows carimbada com a mesma base")
	checar(VersaoScript.texto().begins_with("v"),
		"texto curto da versao tem prefixo v")
	checar(VersaoScript.completo().contains(str(info.get("versao", ""))),
		"texto completo mostra a versao do pacote")


func _testar_dados() -> void:
	print("")
	print("[dados]")
	var gm = _novo(1)
	checar(gm.mundo == Vector2(1440, 900), "mundo tem 1440 x 900")
	checar(gm.tela == Vector2(1280, 720), "tela base tem 1280 x 720")
	checar(gm.pcs.size() == 10, "10 computadores")
	checar(gm.salas.size() == 6, "6 salas (5 de atendimento e a copa)")
	checar(gm.cadeiras.size() == 42, "42 cadeiras no saguao")
	checar(gm.espacos_em_pe.size() == 14, "14 lugares em pe")
	checar(gm.tarefas == 0 and absf(gm.energia - gm.E_MAX) < 0.001, "comeca com 0 tarefas e energia cheia")
	var internos := 0
	var recepcao := 0
	var de_sala := 0
	var sala_chefe := false
	for pc in gm.pcs:
		match str(pc.tipo):
			"interno":
				internos += 1
			"recepcao":
				recepcao += 1
			"sala":
				de_sala += 1
				if str(pc.sala) == "A":
					sala_chefe = true
	checar(internos == 3, "3 PCs internos para os ACS")
	checar(recepcao == 3, "3 PCs da recepcao")
	checar(de_sala == 4, "4 PCs nas salas (sem a sala da chefe)")
	checar(not sala_chefe, "a sala da chefe nao tem PC para o jogador")
	var ids := ["chefe", "medica", "enfermeira", "vacina_1", "vacina_2", "proc_1", "proc_2",
		"guiche", "rec_1", "rec_2", "rec_3", "acs_1", "acs_2", "acs_3", "acs_4",
		"acs_5", "acs_6", "acs_7", "acs_8", "acs_9", "jogador"]
	var faltando := 0
	for id in ids:
		if not gm.entidades.has(id):
			faltando += 1
	checar(faltando == 0, "todos os funcionarios e o jogador existem")
	checar(gm.entidades["jogador"].pele.to_upper() == "#FFEB3B", "jogador usa a pele amarela")
	var total_acs := 0
	for p in gm.pessoas:
		if str(p.tipo) == "acs":
			total_acs += 1
	checar(total_acs == 9, "9 ACS alem do jogador (10 no total)")
	var total := 0
	for grupo in ["chefe", "medica", "enfermeira", "funcionarios", "pacientes"]:
		for d in gm.demandas_def.get(grupo, []):
			total += 1
	checar(total >= 40, "demandas carregadas: " + str(total))
	var total_papos := 0
	var papos_ok := true
	for grupo in gm.papos_def.keys():
		for e in gm.papos_def[grupo]:
			total_papos += 1
			var opcoes: Array = e.get("opcoes", [])
			if str(e.get("tipo", "")) not in ["fala", "pergunta"] or str(e.get("texto", "")) == "" or opcoes.size() < 2:
				papos_ok = false
			for op in opcoes:
				if str(op.get("texto", "")) == "" or str(op.get("resposta", "")) == "":
					papos_ok = false
	checar(total_papos == 94, "94 conversas carregadas, incluindo espera e animais")
	checar(papos_ok, "todo papo tem tipo, texto e duas respostas")
	var d_pcs: Dictionary = gm.cfg.get("computadores", {}).get("distribuicao", {})
	checar(absf(float(d_pcs.get("um_interno", 0.0)) - 40.0) < 0.01
		and absf(float(d_pcs.get("uma_recepcao", 0.0)) - 40.0) < 0.01
		and absf(float(d_pcs.get("um_de_cada", 0.0)) - 10.0) < 0.01
		and absf(float(d_pcs.get("nenhum", 0.0)) - 10.0) < 0.01,
		"distribuicao dos PCs: 40/40/10/10")
	checar(absf(gm.PC_PROBLEMA_CHANCE - 0.10) < 0.001
		and absf(gm.PC_PROBLEMA_LEVE - 0.5) < 0.001, "10% de problema, sendo leve ou grave")
	checar(absf(gm.CAFE_TEMPO - 3.0) < 0.001 and absf(gm.CAFE_GANHO - 1.0) < 0.001,
		"cafe leva 3 s e devolve 1 ponto")
	checar(absf(gm.TEMPO_TAREFA - 3.2) < 0.001 and absf(gm.CUSTO_TAREFA - 0.32) < 0.001,
		"tarefa leva 3,2 s e custa 0,32 de energia")
	var energias_ok := true
	for id in ["chefe", "medica", "enfermeira", "vacina_1", "vacina_2", "proc_1", "proc_2", "guiche", "rec_1", "acs_1"]:
		var e := float(gm.entidades[id].energia)
		if e < gm.NPC_E_MIN - 0.001 or e > gm.NPC_E_MAX_INI + 0.001:
			energias_ok = false
	checar(energias_ok, "funcionarios comecam com energia inicial valida")
	checar(gm.jogador_inicio == Vector2(1160, 218), "jogador comeca no saguao compacto")
	var animais := 0
	var equipe := 0
	for p in gm.pessoas:
		if str(p.tipo) == "paciente" or str(p.tipo) == "crianca":
			continue
		equipe += 1
		if bool(p.get("animal", false)):
			animais += 1
	checar(equipe > 0 and float(animais) / float(equipe) >= 0.30,
		"pelo menos 30%% da equipe e animal (%d de %d)" % [animais, equipe])


func _testar_entrada_e_movimento() -> void:
	print("")
	print("[entrada e movimento]")
	var gm = _novo(100)
	var todos_no_spawn := true
	for p in gm.pessoas:
		if p.pos.distance_to(gm._vet(gm.entrada.get("spawn", [1462, 4]))) > 60.0:
			todos_no_spawn = false
	checar(todos_no_spawn, "todos chegam pela entrada")
	checar(not gm.jogador().visivel, "jogador ainda nao apareceu no inicio")
	gm.step(0.7)
	checar(gm.jogador().visivel and gm.estado == gm.Estado.CAMINHANDO, "jogador entra andando")
	var ultimas := {}
	for p in gm.pessoas:
		ultimas[str(p.id)] = p.pos
	var maior_salto := 0.0
	var tempo := 0.7
	while tempo < 8.0:
		gm.step(0.1)
		tempo += 0.1
		for p in gm.pessoas:
			var id := str(p.id)
			if not p.visivel or p.oculto:
				ultimas[id] = p.pos
				continue
			if str(p.fase) in ["aguardando_entrada", "externo", "saindo", "saiu"]:
				ultimas[id] = p.pos
				continue
			if ultimas.has(id):
				var salto: float = p.pos.distance_to(ultimas[id])
				maior_salto = maxf(maior_salto, salto)
			ultimas[id] = p.pos
	checar(maior_salto < 24.0, "ninguem se teletransporta andando (maior salto %.1f)" % maior_salto)
	checar(gm.estado == gm.Estado.LIVRE, "jogador chega ao ponto inicial e fica livre")
	checar(gm.pos.distance_to(gm.jogador_inicio) < 14.0, "jogador para no ponto inicial do saguao")
	var entraram := 0
	for p in gm.pessoas:
		if p.entrou:
			entraram += 1
	checar(entraram >= 20, "funcionarios e os primeiros pacientes entraram")
	var andaram := false
	for p in gm.pessoas:
		if str(p.tipo) in ["funcionario_sala", "guiche", "recepcao", "acs"] and p.pos.distance_to(gm.espacos_em_pe[0]) > 1.0:
			andaram = true
	checar(andaram, "funcionarios saem da entrada e caminham pelo posto")


func _testar_trabalho() -> void:
	print("")
	print("[trabalho]")
	var gm = _novo_limpo(201)
	gm.modo_pcs = "um_de_cada"
	gm._aplicar_modo_pcs()
	checar(_preparar_jogador(gm), "jogador chega ao inicio")
	var pc = _pc_livre(gm, "interno")
	checar(pc != null, "existe PC interno livre")
	if pc == null:
		return
	checar(_usar_pc(gm, pc), "o jogador caminha ate o PC e se senta")
	checar(gm.foco == pc and pc.jogador, "o PC fica marcado para o jogador")
	checar(gm.jogador().sentado and gm.jogador().facing == 1, "o jogador trabalha virado para a direita")
	gm.tarefas = 3
	gm.prog = 0.0
	gm.energia = 4.0
	gm.step(1.0)
	checar(absf(gm.prog - gm.RENDIMENTO) < 0.01, "1 s rende 0,3125 de tarefa")
	checar(absf(gm.energia - (4.0 - gm.CUSTO_TAREFA * gm.RENDIMENTO)) < 0.02,
		"trabalhar gasta a energia correspondente")
	gm.tarefas = 20
	gm.prog = 0.0
	gm.energia = 4.0
	gm.step(10.0)
	checar(gm.tarefas == 17, "10 s concluem 3 tarefas (" + str(20 - gm.tarefas) + ")")
	checar(gm.prog > 0.0 and gm.prog < 1.0, "a tarefa em andamento guarda o progresso")
	gm.clicar_chao(gm.pos + Vector2(80, 50))
	checar(gm.estado == gm.Estado.CAMINHANDO, "clicar no chao tira o jogador do PC")
	checar(not pc.jogador and gm.foco == null, "o PC e liberado ao sair")


func _testar_esforco_e_aura() -> void:
	print("")
	print("[esforco e aura da chefe]")
	var gm = _novo_limpo(202)
	gm.modo_pcs = "um_de_cada"
	gm._aplicar_modo_pcs()
	_preparar_jogador(gm)
	var pc = _pc_livre(gm, "interno")
	if pc == null:
		checar(false, "existe PC interno livre para o teste de esforco")
		return
	_usar_pc(gm, pc)
	gm.tarefas = 20
	gm.prog = 0.0
	gm.energia = 4.5
	gm.step(0.5)
	var prog_normal: float = gm.prog
	var gasto_normal: float = 4.5 - gm.energia
	gm.prog = 0.0
	gm.energia = 4.5
	gm.clique_jogador()
	checar(gm.esforco_manual, "clicar no jogador ativa o esforco manual")
	gm.step(0.5)
	var prog_esforco: float = gm.prog
	var gasto_esforco: float = 4.5 - gm.energia
	checar(absf(prog_esforco - prog_normal * (1.0 + gm.ESP_VEL)) < 0.015, "esforco acelera 25%")
	var custo_normal: float = gasto_normal / maxf(prog_normal, 0.0001)
	var custo_esforco: float = gasto_esforco / maxf(prog_esforco, 0.0001)
	checar(absf(custo_esforco - custo_normal * gm.ESP_GASTO) < 0.01,
		"esforco gasta 25% a mais por tarefa")
	gm.clique_jogador()
	checar(not gm.esforco_manual, "segundo clique desliga o esforco")
	# A chefe perto Tambem acelera, sem clique.
	var chefe = gm.entidades["chefe"]
	chefe.pos = gm.pos + Vector2(30, 0)
	chefe.fase = "no_posto"
	chefe.visivel = true
	chefe.oculto = false
	gm.step(0.05)
	checar(gm.jogador().aura_chefe and gm.jogador().em_esforco, "a presenca da chefe ativa a aura")
	gm.prog = 0.0
	gm.energia = 4.0
	gm.step(0.5)
	checar(gm.prog > prog_normal * 0.95, "a aura acelera o trabalho como o esforco")
	gm.energia = 0.1
	gm.clique_jogador()
	checar(not gm.esforco_manual, "energia baixa demais impede o esforco manual")
	chefe.visivel = false
	gm.esforco_manual = false
	gm.jogador().em_esforco = false
	gm.jogador().energia = gm.E_MAX
	var vel_cheia: float = gm._velocidade_de(gm.jogador())
	gm.jogador().energia = 0.0
	var vel_baixa: float = gm._velocidade_de(gm.jogador())
	checar(vel_baixa < vel_cheia * 0.6, "personagem com energia baixa anda mais devagar")


func _testar_cafe() -> void:
	print("")
	print("[cafe]")
	var gm = _novo_limpo(203)
	_preparar_jogador(gm)
	gm.clicar_copa()
	checar(gm.estado == gm.Estado.CAMINHANDO, "clicar na copa leva o jogador andando")
	checar(_esperar(gm, 25.0, func(): return gm.estado == gm.Estado.NA_COPA), "jogador chega a copa")
	checar(gm.cafe_modo == gm.ModoCafe.ESPERANDO, "nao toma cafe sozinho")
	gm.energia = 1.0
	gm.clicar_copa()
	checar(gm.cafe_modo == gm.ModoCafe.TOMANDO, "segundo clique inicia o cafe")
	gm.step(3.0)
	checar(absf(gm.energia - 2.0) < 0.01, "o cafe de 3 s devolve 1 ponto")
	checar(gm.count("cafes") == 1, "o cafe e contado nas estatisticas")
	gm.step(12.0)
	checar(absf(gm.energia - gm.E_MAX) < 0.01, "o cafe continua ate encher a energia")
	gm.clicar_copa()
	checar(gm.cafe_modo != gm.ModoCafe.TOMANDO, "com energia cheia nao toma cafe")
	var g2 = _novo_limpo(204)
	g2.modo_pcs = "um_de_cada"
	g2._aplicar_modo_pcs()
	_preparar_jogador(g2)
	var pc = _pc_livre(g2, "interno")
	if pc != null:
		_usar_pc(g2, pc)
		g2.tarefas = 3
		g2.energia = 0.2
		var copa := _esperar(g2, 30.0, func(): return g2.estado == g2.Estado.NA_COPA)
		checar(copa, "sem energia o jogador vai sozinho para a copa")
		checar(not pc.jogador and g2.foco == null, "o PC fica livre quando ele sai")
		checar(g2.count("idas_a_copa_sem_energia") > 0, "a ida automatica e contada")
	else:
		checar(false, "existe PC para testar a ida automatica a copa")
	# Capacidade da copa: cinco pessoas.
	var g3 = _novo_limpo(205)
	g3._preparar_entradas()
	var copa_sala = g3._sala_por_id("E")
	var colocadas := 0
	for p in g3.pessoas:
		if colocadas >= 5:
			break
		if str(p.tipo) in ["paciente", "crianca", "jogador"]:
			continue
		p.visivel = true
		p.oculto = false
		p.fase = "na_copa"
		p.pos = copa_sala.rect.get_center()
		p.visita_ate = 9999.0
		colocadas += 1
	checar(colocadas == 5 and not g3._copa_tem_vaga(), "a copa aceita no maximo 5 pessoas")


func _testar_limite() -> void:
	print("")
	print("[limite de 10 trabalhos]")
	var gm = _novo(206)
	if not _esperar(gm, 8.0, func(): return gm.entidades["chefe"].visivel):
		checar(false, "a chefe ficou visivel")
		return
	gm.step(20.0)
	gm.tarefas = 10
	var abriu: bool = gm.levar_pessoa_ao_jogador(gm.entidades["chefe"])
	checar(not abriu and gm.modal == null, "com 10 tarefas ninguem abre dialogo")
	gm.tarefas = 9
	gm._aplicar_consequencia({"tarefas": [3, 3]})
	checar(gm.tarefas == 10, "o teto de 10 nunca e ultrapassado")
	gm._aplicar_consequencia({"tarefas": [3, 3]})
	checar(gm.tarefas == 10, "aceitar outra demanda no teto nao passa de 10")
	gm.tarefas = 9
	var geradas_antes: int = gm.count("demandas_geradas")
	gm.prox_demanda = 0.01
	gm.step(0.2)
	checar(gm.count("demandas_geradas") > geradas_antes, "abaixo de 10 o posto volta a gerar demandas")
	gm.tarefas = 10
	gm.prox_demanda = 0.0
	var geradas_teto: int = gm.count("demandas_geradas")
	gm.step(0.2)
	checar(gm.count("demandas_geradas") == geradas_teto, "com 10 tarefas nao surgem novas demandas")


func _testar_computadores() -> void:
	print("")
	print("[computadores]")
	var gm = _novo(207)
	_preparar_jogador(gm)
	gm.modo_pcs = "um_interno"
	gm._aplicar_modo_pcs()
	checar(gm._contar_livres_por_tipo("interno") == 1 and gm._contar_livres_por_tipo("recepcao") == 0,
		"modo um_interno deixa 1 interno livre")
	gm.modo_pcs = "uma_recepcao"
	gm._aplicar_modo_pcs()
	checar(gm._contar_livres_por_tipo("interno") == 0 and gm._contar_livres_por_tipo("recepcao") == 1,
		"modo uma_recepcao deixa 1 recepcao livre")
	gm.modo_pcs = "um_de_cada"
	gm._aplicar_modo_pcs()
	checar(gm._contar_livres_por_tipo("interno") == 1 and gm._contar_livres_por_tipo("recepcao") == 1,
		"modo um_de_cada deixa 1 de cada livre")
	gm.modo_pcs = "nenhum"
	gm._aplicar_modo_pcs()
	checar(gm._contar_livres_por_tipo("interno") == 0 and gm._contar_livres_por_tipo("recepcao") == 0,
		"modo nenhum deixa todos os PCs ocupados")
	gm.modo_pcs = "um_de_cada"
	gm._aplicar_modo_pcs()
	var pc = _pc_livre(gm, "interno")
	checar(pc != null, "ha um PC interno livre para o teste")
	if pc == null:
		return
	pc.problema = "grave"
	pc.problema_ate = gm.tempo + 30.0
	gm.clicar_pc(str(pc.id))
	gm.step(0.3)
	checar(gm.estado != gm.Estado.NO_PC, "PC com problema grave nao pode ser usado")
	checar(gm.modal != null and str(gm.modal.get("tipo", "")) == "reparo",
		"PC quebrado abre o minijogo de conserto")
	if gm.modal != null:
		gm.fechar_dialogo()
	pc.problema = ""
	checar(_usar_pc(gm, pc), "o jogador ocupa o PC interno")
	gm.tarefas = 3
	gm.prog = 0.0
	gm.energia = 4.5
	pc.problema = "leve"
	pc.problema_ate = gm.tempo + 30.0
	gm.step(1.0)
	checar(absf(gm.prog - gm.RENDIMENTO * gm.PC_PROBLEMA_LEVE) < 0.01, "problema leve corta o rendimento pela metade")
	pc.problema = ""
	gm.prog = 0.0
	gm.energia = 4.5
	gm.step(1.0)
	checar(gm.prog > gm.RENDIMENTO * 0.9, "PC consertado volta ao rendimento normal")
	pc.problema = "grave"
	pc.problema_ate = gm.tempo + 30.0
	gm.step(0.1)
	checar(gm.estado != gm.Estado.NO_PC and not pc.jogador, "problema grave expulsa o jogador do PC")
	pc.problema = ""
	# Recepcao: o jogador pode ser interrompido por um paciente.
	gm.modo_pcs = "um_de_cada"
	gm._aplicar_modo_pcs()
	var rec = _pc_livre(gm, "recepcao")
	if rec == null:
		checar(false, "ha um PC de recepcao livre")
		return
	checar(_usar_pc(gm, rec), "o jogador ocupa o PC da recepcao")
	gm.tarefas = 3
	gm.prog = 0.0
	var paciente = gm._novo_paciente(-1)
	paciente.servicos = []
	paciente.servico_index = 0
	paciente.destino_tipo = "recepcao"
	paciente.fase = "indo_recepcao"
	paciente.pos = rec.atendimento
	paciente.atendimento_restante = 5.0
	paciente.estacao_recepcao = str(rec.id)
	rec.atendimento_id = str(paciente.id)
	gm._ao_chegar_recepcao(paciente)
	checar(gm.atendendo_paciente == str(paciente.id), "paciente interrompe o jogador na recepcao")
	checar(gm.atendimento_timer >= gm.REC_ATEND_MIN - 0.001 and gm.atendimento_timer <= gm.REC_ATEND_MAX + 0.001,
		"atendimento da recepcao dura de 4 a 9 s")
	gm.step(0.5)
	checar(gm.prog == 0.0, "o trabalho fica parado durante o atendimento")
	var antes_rec: int = gm.count("atendidos_recepcao")
	gm.step(gm.atendimento_timer + 0.3)
	checar(gm.count("atendidos_recepcao") > antes_rec, "o atendimento da recepcao e concluido")
	checar(gm.atendendo_paciente == "" and rec.atendimento_id == "", "o atendimento libera a estacao")
	# A ocupacao dos PCs varia com o tempo.
	var g2 = _novo(208)
	var assinatura := _assinatura_pcs(g2)
	var variou := false
	var t := 0.0
	while t < 90.0:
		g2.step(2.0)
		t += 2.0
		if _assinatura_pcs(g2) != assinatura:
			variou = true
			break
	checar(variou, "a ocupacao dos computadores muda com o tempo")


func _assinatura_pcs(gm: Node) -> String:
	var s := ""
	for pc in gm.pcs:
		s += str(pc.id) + "=" + str(pc.ocupante) + ";"
	return s


func _testar_salas() -> void:
	print("")
	print("[salas]")
	var gm = _novo_limpo(209)
	gm.step(30.0)
	var problemas := 0
	for id in ["chefe", "medica", "enfermeira", "vacina_1", "vacina_2", "proc_1", "proc_2"]:
		var p = gm.entidades[id]
		if p.pos.distance_to(p.posto) > 50.0:
			problemas += 1
	checar(problemas == 0, "funcionarios fixos chegam aos seus postos")
	var virados := true
	for id in ["medica", "enfermeira", "vacina_1", "vacina_2", "proc_1", "proc_2"]:
		if int(gm.entidades[id].facing) != 1:
			virados = false
	checar(virados, "funcionarios sentados olham para a direita")
	checar(gm._sala_por_id("D").cadeiras.size() == 2 and gm._sala_por_id("F").cadeiras.size() == 2,
		"vacina e procedimentos tem duas cadeiras de trabalho")
	# A copa fica ao lado de Procedimentos: sem um corredor de verdade, as
	# pessoas eram espremidas contra a parede para chegar à porta da sala F.
	var sala_f = gm._sala_por_id("F")
	var sala_e = gm._sala_por_id("E")
	checar(sala_e.x - (sala_f.x + sala_f.w) >= 48.0,
		"ha corredor livre entre procedimentos e copa")
	var corredor_ok := true
	for py in [700.0, 756.0, 820.0]:
		for px in [336.0, 352.0, 368.0]:
			if not gm.nav.ponto_livre(Vector2(px, py)):
				corredor_ok = false
	checar(corredor_ok, "o corredor ao lado da copa tem passagem livre")
	var pc_sala = gm.pcs_por_id["pcB"]
	gm.modo_pcs = "um_de_cada"
	gm._aplicar_modo_pcs()
	# A medica sai da sala para o jogador poder usar o PC vazio.
	var medica = gm.entidades["medica"]
	medica.pos = Vector2(700, 250)
	medica.posto = Vector2(700, 250)
	medica.fase = "passeando"
	medica.visita_ate = 9999.0
	medica.servindo = ""
	var chegou := _usar_pc(gm, pc_sala, 30.0)
	checar(chegou, "o jogador pode usar o PC de uma sala vazia")
	if chegou:
		var p = gm._novo_paciente(-1)
		p.servicos = [{"tipo": "sala", "sala": "B"}]
		p.servico_index = 0
		p.destino_tipo = "sala"
		p.sala_destino = "B"
		p.fase = "sentado"
		p.pos = Vector2(650, 320)
		p.tolerancia_total = 9999.0
		p.raiva = 0.0
		gm.step(0.2)
		checar(gm.estado != gm.Estado.NO_PC and not pc_sala.jogador,
			"o jogador e expulso quando a sala precisa atender")
		checar(gm.foco == null, "o PC da sala fica livre apos a expulsao")
		p.fase = "na_sala"
		p.spot_sala = 0
		p.pos = Vector2(250, 300)
		p.andando = false
		p.caminho.clear()
		gm._sala_por_id("B").paciente_ocupado[str(p.id)] = true
		var chamada := _esperar(gm, 6.0,
			func(): return str(medica.fase) in ["indo_atender", "atendendo", "voltando_posto", "indo_posto"])
		checar(chamada, "a medica e chamada de volta quando ha paciente")
	# Capacidade de tres pacientes por sala.
	var g2 = _novo_limpo(210)
	g2.step(2.0)
	for i in 5:
		var p = g2._novo_paciente(-1)
		p.servicos = [{"tipo": "sala", "sala": "C"}]
		p.servico_index = 0
		p.destino_tipo = "sala"
		p.sala_destino = "C"
		p.fase = "sentado"
		p.pos = Vector2(650, 300 + i * 20)
		p.tolerancia_total = 9999.0
		p.raiva = 0.0
	g2.step(3.0)
	var sala_c = g2._sala_por_id("C")
	var na_sala := 0
	for p in g2.pessoas:
		if str(p.tipo) == "paciente" and str(p.sala_destino) == "C" and str(p.fase) in ["indo_sala", "na_sala"]:
			na_sala += 1
	checar(sala_c.paciente_ocupado.size() <= 3 and na_sala <= 3,
		"a sala aceita no maximo 3 pacientes por vez")
	g2.step(80.0)
	checar(g2.count("atendidos_sala") > 0, "a equipe atende os pacientes nas salas")


func _testar_pacientes_e_criancas() -> void:
	print("")
	print("[pacientes e criancas]")
	var gm = _novo(211)
	gm.step(120.0)
	var tem_crianca := false
	for p in gm.pessoas:
		if str(p.tipo) == "crianca":
			tem_crianca = true
			break
	if not tem_crianca:
		# Garante o cenario mesmo quando o sorteio nao traz criancas.
		gm.CHANCE_CRIANCA = 1.0
		gm._novo_paciente(-1)
		gm.step(0.1)
	var adultos := 0
	var criancas := 0
	var sentados := 0
	var cadeira_ok := true
	var tolerancia_ok := true
	var limite_fila_ok := true
	for p in gm.pessoas:
		if str(p.tipo) == "paciente" and str(p.fase) not in ["saindo", "saiu"]:
			adultos += 1
			if float(p.tolerancia_total) < gm.PAC_TOL_MIN - 0.01 or float(p.tolerancia_total) > gm.PAC_TOL_MAX + 0.01:
				tolerancia_ok = false
			if int(p.limite_fila) < gm.PAC_LIMITE_FILA_MIN or int(p.limite_fila) > gm.PAC_LIMITE_FILA_MAX:
				limite_fila_ok = false
			if str(p.fase) == "sentado":
				sentados += 1
				if int(p.cadeira) < 0 or int(p.em_pe) != -1:
					cadeira_ok = false
		elif str(p.tipo) == "crianca":
			criancas += 1
	checar(adultos > 0 and adultos <= gm.MAX_ADULTOS, "no maximo 12 adultos simultaneos (" + str(adultos) + ")")
	checar(cadeira_ok, "paciente sentado ocupa uma cadeira e nao um lugar em pe")
	checar(tolerancia_ok, "tolerancia total entre 60 e 300 s")
	checar(limite_fila_ok, "limite da fila do guiche entre 4 e 9")
	checar(gm.fila_guiche.size() <= 9, "a fila do guiche nao passa de 9 pacientes")
	checar(criancas > 0, "criancas acompanham os adultos (" + str(criancas) + ")")
	var nomes_ok := true
	for p in gm.pessoas:
		if str(p.tipo) not in ["paciente", "crianca"]:
			continue
		var nome_p := str(p.nome)
		if nome_p.begins_with("Paciente ") or nome_p.begins_with("Criança ") or nome_p.split(" ", false).size() < 2:
			nomes_ok = false
	checar(nomes_ok, "pacientes e criancas recebem nomes ficticios com sobrenome")
	var regras_criancas := true
	var criancas_por_adulto := {}
	for p in gm.pessoas:
		if str(p.tipo) != "crianca":
			continue
		var adulto = gm.entidades.get(str(p.adulto_id), null)
		if adulto == null or str(adulto.tipo) != "paciente":
			regras_criancas = false
			continue
		if not adulto.criancas.has(str(p.id)):
			regras_criancas = false
		if str(p.fase) in ["fila_guiche", "indo_fila_guiche", "no_guiche", "sentado", "na_sala", "no_recepcao"]:
			regras_criancas = false
		if int(p.cadeira) >= 0 or int(p.em_pe) >= 0 or not p.servicos.is_empty():
			regras_criancas = false
		criancas_por_adulto[str(p.adulto_id)] = int(criancas_por_adulto.get(str(p.adulto_id), 0)) + 1
	for id in criancas_por_adulto:
		if int(criancas_por_adulto[id]) > gm.MAX_CRIANCAS_ADULTO:
			regras_criancas = false
	checar(regras_criancas, "criancas nao sentam, nao passam no guiche e ficam com o adulto")
	var cadeiras_com_crianca := false
	for c in gm.cadeiras:
		var ocupante = gm.entidades.get(str(c.ocupante), null)
		if ocupante != null and str(ocupante.tipo) == "crianca":
			cadeiras_com_crianca = true
	checar(not cadeiras_com_crianca, "criancas nao ocupam cadeiras do saguao")
	# Verificacao direta: em um instante qualquer todos podem estar em atendimento.
	var espera = gm._novo_paciente(-1)
	espera.servicos = []
	espera.servico_index = 0
	espera.fase = "ocioso"
	espera.pos = Vector2(1200, 400)
	espera.tolerancia_total = 9999.0
	gm._ir_esperar(espera)
	var sentou := _esperar(gm, 8.0, func(): return str(espera.fase) == "sentado")
	checar(sentou and int(espera.cadeira) >= 0 and int(espera.em_pe) == -1,
		"paciente em espera senta na cadeira mais proxima")
	checar(gm.count("atendidos_guiche") > 0, "pacientes passam pelo guiche")
	checar(gm.count("atendidos_sala") > 0, "pacientes sao atendidos nas salas")
	# Tempo de guiche entre 2 e 6 s.
	var g2 = _novo(212)
	var iniciou := _esperar(g2, 30.0, func(): return g2.guiche_atendendo != "")
	checar(iniciou, "o guiche chama o primeiro paciente")
	if iniciou:
		var chegou := _esperar(g2, 4.0, func(): return g2.entidades[str(g2.guiche_atendendo)].fase == "no_guiche" if g2.guiche_atendendo != "" else false)
		checar(chegou, "o paciente chega ao guiche")
		if chegou:
			checar(g2.guiche_timer >= g2.GUICHE_MIN - 0.001 and g2.guiche_timer <= g2.GUICHE_MAX + 0.001,
				"guiche atende entre 2 e 6 s")
	# Pacientes mantem a demanda ate irem embora.
	var g3 = _novo_limpo(213)
	var pac = g3._novo_paciente(-1)
	pac.fase = "sentado"
	pac.pos = Vector2(650, 500)
	pac.tolerancia_total = 9999.0
	pac.raiva = 0.0
	g3._criar_demanda(pac)
	checar(pac.demanda != null, "o paciente recebe uma demanda")
	# Seis segundos bastam para provar que a demanda não expira sozinha; com
	# quarenta, a raiva da fila pode fazer o paciente desistir e mascarar o teste.
	g3.step(6.0)
	checar(pac.demanda != null and str(pac.fase) != "saindo", "o paciente mantem a demanda enquanto espera")
	g3._iniciar_saida(pac, false)
	checar(pac.demanda == null, "a demanda some quando o paciente vai embora")
	# Desistencia por raiva.
	var g4 = _novo_limpo(214)
	var bravo = g4._novo_paciente(-1)
	bravo.fase = "sentado"
	bravo.pos = Vector2(650, 500)
	bravo.tolerancia_total = 9999.0
	bravo.raiva = 96.0
	var desistencias_antes: int = g4.count("desistencias")
	g4.step(0.2)
	checar(g4.count("desistencias") > desistencias_antes and str(bravo.fase) == "saindo",
		"paciente muito bravo desiste e vai embora")


func _testar_fluxo_de_demanda() -> void:
	print("")
	print("[fluxo de demanda]")
	var gm = _novo_limpo(215)
	checar(_preparar_jogador(gm), "jogador esta livre para conversar")
	var chefe = gm.entidades["chefe"]
	var medica = gm.entidades["medica"]
	var enfermeira = gm.entidades["enfermeira"]
	var guiche = gm.entidades["guiche"]
	gm.energia = 4.2
	for p in [chefe, medica, enfermeira]:
		var op: Array = gm._opcoes_dialogo(p)
		checar(op.size() == 2 and bool(op[0].aceitar) and bool(op[1].aceitar)
			and not bool(op[0].relutante) and not bool(op[1].relutante),
			"energia > 80%: duas respostas positivas para " + str(p.cargo_key))
	gm.energia = 3.0
	for p in [chefe, medica, enfermeira]:
		var op: Array = gm._opcoes_dialogo(p)
		checar(op.size() == 2 and bool(op[0].aceitar) and not bool(op[0].relutante)
			and bool(op[1].aceitar) and bool(op[1].relutante),
			"energia entre 40% e 80%: positiva + relutante para " + str(p.cargo_key))
	gm.energia = 1.0
	for p in [chefe, medica, enfermeira]:
		var op: Array = gm._opcoes_dialogo(p)
		checar(op.size() == 2 and bool(op[0].aceitar) and bool(op[0].relutante)
			and bool(op[1].aceitar) and bool(op[1].relutante),
			"energia < 40%: duas respostas relutantes para " + str(p.cargo_key))
	gm.energia = 3.0
	for p in [guiche, gm.entidades["rec_1"], gm.entidades["acs_1"], gm.entidades["vacina_1"], gm.entidades["proc_1"]]:
		var op: Array = gm._opcoes_dialogo(p)
		checar(op.size() == 2 and bool(op[0].aceitar) and not bool(op[0].relutante)
			and not bool(op[1].aceitar) and not bool(op[1].relutante),
			"demais com >= 50%: aceitar positivo e negar com desculpa (" + str(p.id) + ")")
	gm.energia = 1.0
	for p in [guiche, gm.entidades["rec_1"], gm.entidades["acs_1"], gm.entidades["vacina_1"], gm.entidades["proc_1"]]:
		var op: Array = gm._opcoes_dialogo(p)
		checar(op.size() == 2 and bool(op[0].aceitar) and bool(op[0].relutante)
			and not bool(op[1].aceitar) and bool(op[1].relutante),
			"demais com < 50%: aceitar relutante e negar por cansaco (" + str(p.id) + ")")
	# Aceitar pelo dialogo real.
	gm.energia = 4.2
	chefe.demanda = null
	gm._criar_demanda(chefe)
	var antes: int = gm.tarefas
	checar(gm.abrir_dialogo(chefe) and gm.modal != null, "o dialogo da chefe abre")
	checar(gm.estado == gm.Estado.CONVERSANDO, "conversar muda o estado")
	checar(gm.modal.opcoes.size() == 2 and str(gm.modal.nome) == str(chefe.nome), "o dialogo mostra nome e duas opcoes")
	checar(str(gm.modal.fundido) == "", "energia alta nao mostra aviso de energia baixa")
	gm.escolher_opcao(1)
	checar(gm.modal == null and gm.estado == gm.Estado.LIVRE, "responder fecha o dialogo e devolve o estado")
	checar(gm.tarefas > antes and gm.tarefas <= gm.TAREFAS_MAX, "aceitar a demanda rende trabalho")
	checar(chefe.demanda == null, "a demanda some depois de respondida")
	checar(gm.energia <= gm.E_MAX and gm.energia >= 0.0, "energia sempre entre 0 e 5")
	# Negar pelo dialogo real.
	gm.energia = 3.0
	guiche.demanda = null
	gm._criar_demanda(guiche)
	var antes_negar: int = gm.tarefas
	var negadas_antes: int = gm.count("demandas_negadas")
	checar(gm.abrir_dialogo(guiche), "o dialogo do guiche abre")
	gm.escolher_opcao(1)
	checar(gm.modal == null and gm.tarefas == antes_negar, "negar nao rende trabalho")
	checar(gm.count("demandas_negadas") > negadas_antes, "a negativa entra nas estatisticas")
	checar(guiche.demanda == null, "a demanda negada tambem some")
	# Energia baixa: aviso e respostas relutantes.
	gm.energia = 1.0
	medica.demanda = null
	gm._criar_demanda(medica)
	checar(gm.abrir_dialogo(medica), "o dialogo da medica abre com energia baixa")
	checar(str(gm.modal.fundido) != "", "energia baixa mostra o aviso no dialogo")
	checar(bool(gm.modal.opcoes[0].relutante) and bool(gm.modal.opcoes[1].relutante), "as opcoes ficam relutantes")
	gm.fechar_dialogo()
	checar(gm.modal == null and gm.estado == gm.Estado.LIVRE, "fechar sem responder volta ao estado livre")
	checar(medica.demanda != null, "fechar sem responder mantem a demanda")
	# Indice de opcao invalido nao quebra o dialogo.
	checar(gm.abrir_dialogo(medica), "o dialogo reabre para testar indice invalido")
	gm.escolher_opcao(99)
	checar(gm.modal != null, "opcao invalida mantem o dialogo aberto")
	gm.escolher_opcao(-1)
	checar(gm.modal != null, "indice negativo mantem o dialogo aberto")
	gm.fechar_dialogo()


func _testar_abordagem() -> void:
	print("")
	print("[abordagem no PC interno]")
	var gm = _novo_limpo(216)
	gm.modo_pcs = "um_de_cada"
	gm._aplicar_modo_pcs()
	_preparar_jogador(gm)
	var pc = _pc_livre(gm, "interno")
	if pc == null:
		checar(false, "ha PC interno livre para a abordagem")
		return
	checar(_usar_pc(gm, pc), "jogador esta no PC interno")
	gm.tarefas = 4
	gm.energia = 5.0
	gm.prog = 0.0
	var medica = gm.entidades["medica"]
	medica.demanda = null
	medica.pos = gm.pos + Vector2(100, 0)
	medica.posto = medica.pos
	medica.fase = "no_posto"
	medica.energia = 4.0
	gm._criar_demanda(medica, true)
	gm.PC_ABORDAGEM_CHANCE = 10.0
	gm.step(0.1)
	checar(str(medica.fase) in ["indo_abordar_jogador", "abordando_jogador"], "funcionario com demanda se aproxima")
	checar(gm._penalidade_abordagem(), "a abordagem reduz o ritmo do jogador")
	gm.prog = 0.0
	gm.step(0.5)
	checar(gm.prog > 0.0 and gm.prog < gm.RENDIMENTO * 0.5 * 0.95,
		"o trabalho fica pela metade durante a abordagem")
	var abriu := _esperar(gm, 5.0, func(): return gm.modal != null)
	checar(abriu, "ao chegar ao lado, o dialogo abre")
	if abriu:
		checar(str(gm.modal.alvo_id) == "medica", "o dialogo e da medica que abordou")
		var opcoes: Array = gm.modal.opcoes
		gm.escolher_opcao(opcoes.size() - 1)
		checar(gm.modal == null, "responder encerra a abordagem")
		checar(not gm._penalidade_abordagem(), "a penalidade termina depois da conversa")
		gm.prog = 0.0
		gm.step(0.5)
		checar(gm.prog > 0.0, "o jogador volta a trabalhar normalmente")
	# Funcionario com menos de 50% de energia nao aborda.
	gm.PC_ABORDAGEM_CHANCE = 10.0
	medica.pos = gm.pos + Vector2(100, 0)
	medica.fase = "no_posto"
	medica.energia = 1.0
	medica.demanda = null
	gm._criar_demanda(medica, true)
	gm.step(1.0)
	checar(str(medica.fase) not in ["indo_abordar_jogador", "abordando_jogador"],
		"funcionario com menos de 50% de energia nao aborda")
	# Ao sair do PC, a abordagem e liberada.
	medica.energia = 4.0
	medica.pos = gm.pos + Vector2(100, 0)
	medica.fase = "no_posto"
	medica.demanda = null
	gm._criar_demanda(medica, true)
	gm.PC_ABORDAGEM_CHANCE = 10.0
	gm.step(0.15)
	gm.clicar_chao(gm.pos + Vector2(-120, 50))
	gm.step(0.2)
	checar(str(medica.fase) not in ["indo_abordar_jogador", "abordando_jogador"],
		"sair do PC libera quem estava abordando")


func _testar_demandas_dos_funcionarios() -> void:
	print("")
	print("[demandas dos funcionarios]")
	var gm = _novo_limpo(217)
	_preparar_jogador(gm)
	var medica = gm.entidades["medica"]
	medica.demanda = null
	var d = gm._criar_demanda(medica, true)
	checar(not d.is_empty() and medica.demanda != null, "funcionario recebe demanda")
	checar(float(d.vida) >= gm.DEM_VIDA_MIN - 0.01 and float(d.vida) <= gm.DEM_VIDA_MAX + 0.01,
		"demanda de funcionario tem tempo de vida")
	var chefe = gm.entidades["chefe"]
	chefe.demanda = null
	var dc = gm._criar_demanda(chefe, true)
	checar(float(dc.vida) == 0.0, "demanda da chefe nao expira")
	gm.DEM_DESISTENCIA = 100.0
	gm.step(0.2)
	checar(chefe.demanda != null, "a chefe nunca desiste da demanda")
	checar(medica.demanda == null, "os outros funcionarios podem desistir da demanda")
	# Uma demanda vencida tambem desaparece.
	var g2 = _novo_limpo(218)
	var enf = g2.entidades["enfermeira"]
	enf.demanda = null
	var d2 = g2._criar_demanda(enf, true)
	d2.vida = 0.1
	var antes: int = g2.count("demandas_desistidas")
	g2.step(0.3)
	checar(enf.demanda == null and g2.count("demandas_desistidas") > antes,
		"demanda com tempo de vida vencido e descartada")


func _preparar_papo(gm: Node, p: Dictionary) -> void:
	p.visivel = true
	p.oculto = false
	p.entrou = true
	p.demanda = null
	p.papo = null
	p.servindo = ""
	p.fase = "no_posto"
	p.energia = p.max_energia
	p.prox_papo = 0.001


func _testar_papos() -> void:
	print("")
	print("[papo de corredor]")
	var gm = _novo_limpo(301)
	_preparar_jogador(gm)
	var cats := {
		"chefe": "chefe", "medica": "medica", "enfermeira": "enfermeira",
		"vacina_1": "vacina", "proc_1": "procedimentos", "guiche": "guiche",
		"rec_1": "recepcao", "acs_1": "acs",
	}
	var cat_ok := true
	for id in cats:
		if gm._categoria_papo(gm.entidades[id]) != cats[id]:
			cat_ok = false
	checar(cat_ok, "cada cargo usa a categoria certa de papo")

	var medica = gm.entidades["medica"]
	_preparar_papo(gm, medica)
	var surgiu: bool = gm._abrir_papo_ambiente(medica)
	checar(surgiu and medica.papo != null, "funcionario pode iniciar papo de corredor")
	checar(str(medica.balao_tipo) in ["fala", "pergunta"], "papo usa balao de fala ou pergunta")
	var texto_chave := str(medica.papo.get("id", ""))
	checar(texto_chave != "" and gm.count("papos_surgidos") > 0, "papo escolhido e registrado")

	var energia_antes: float = gm.energia
	var tarefas_antes: int = gm.tarefas
	var abriu: bool = gm.abrir_papo(medica)
	checar(abriu and gm.modal != null, "abrir papo mostra a janela de conversa")
	checar(str(gm.modal.get("tipo", "")) == "papo" and str(gm.modal.get("fase", "")) == "pergunta",
		"a janela abre na fase de pergunta")
	checar((gm.modal.get("opcoes", []) as Array).size() == 2, "o papo oferece duas respostas sociais")
	checar(int(gm.estado) == int(gm.Estado.CONVERSANDO), "o jogador entra no estado conversando")
	checar(absf(gm.energia - energia_antes) < 0.001 and gm.tarefas == tarefas_antes,
		"abrir papo nao gasta energia nem cria tarefa")

	var respostas: Array = medica.papo.get("opcoes", [])
	var replica_esperada := str((respostas[0] as Dictionary).get("resposta", ""))
	gm.escolher_opcao(0)
	checar(str(gm.modal.get("fase", "")) == "resposta", "responder mostra a replica do funcionario")
	checar(str(gm.modal.get("texto", "")) == replica_esperada, "a replica corresponde a resposta escolhida")
	checar((gm.modal.get("opcoes", []) as Array).size() == 1, "a replica tem um unico botao de encerramento")
	gm.escolher_opcao(0)
	checar(gm.modal == null and medica.papo == null, "encerrar o papo libera o funcionario")
	checar(gm.count("papos_respondidos") == 1, "a conversa entra na estatistica")
	checar(float(medica.prox_papo) > gm.tempo, "depois do papo o funcionario espera antes de outro")
	checar(absf(gm.energia - energia_antes) < 0.001 and gm.tarefas == tarefas_antes,
		"conversa de corredor nao cobra energia")

	var g2 = _novo_limpo(302)
	_preparar_jogador(g2)
	var enf = g2.entidades["enfermeira"]
	_preparar_papo(g2, enf)
	g2._abrir_papo_ambiente(enf)
	enf.papo["ate"] = g2.tempo - 0.01
	var perdidos: int = g2.count("papos_perdidos")
	g2.step(0.1)
	checar(enf.papo == null and g2.count("papos_perdidos") > perdidos, "papo nao respondido expira")

	var g3 = _novo_limpo(303)
	_preparar_jogador(g3)
	for id in ["medica", "enfermeira", "guiche", "rec_1", "acs_1"]:
		_preparar_papo(g3, g3.entidades[id])
	g3.step(0.1)
	var ativos := 0
	for p in g3.pessoas:
		if p.papo != null:
			ativos += 1
	checar(ativos == g3.PAPO_MAX_ATIVOS, "no maximo 3 papos ativos ao mesmo tempo")

	var g5 = _novo_limpo(305)
	_preparar_jogador(g5)
	var paciente = g5._novo_paciente(0.0)
	paciente.fase = "sentado"
	paciente.entrou = true
	paciente.visivel = true
	paciente.oculto = false
	paciente.demanda = null
	paciente.papo = null
	paciente.servindo = ""
	paciente.energia = paciente.max_energia
	paciente.prox_papo = 0.001
	checar(g5._categoria_papo(paciente) == "paciente", "paciente usa a categoria de conversa da espera")
	checar(g5._pode_papo(paciente), "paciente sentado pode puxar conversa")
	checar(g5._abrir_papo_ambiente(paciente) and paciente.papo != null,
		"paciente inicia conversa de espera")
	checar(str(paciente.balao_tipo) in ["fala", "pergunta"],
		"conversa de paciente usa balao de fala ou pergunta")
	var achou_arvore := false
	for e in g5.papos_def.get("paciente", []):
		if str(e.get("id", "")) == "paciente_arvore_azul" and str(e.get("texto", "")).contains("chama azul"):
			achou_arvore = true
	checar(achou_arvore, "a pergunta da arvore com chama azul esta no jogo")
	checar(g5.abrir_papo(paciente) and bool(g5.modal.get("papo_paciente", false)),
		"a janela identifica a conversa como espera de paciente")
	g5.fechar_dialogo()

	var g4 = _novo_limpo(304)
	_preparar_jogador(g4)
	var m4 = g4.entidades["medica"]
	_preparar_papo(g4, m4)
	m4.energia = 0.5
	checar(not g4._pode_papo(m4), "funcionario muito cansado nao puxa papo")
	m4.energia = m4.max_energia
	g4._criar_demanda(m4, true)
	checar(not g4._pode_papo(m4), "funcionario com demanda nao puxa papo")
	g4._limpar_demanda(m4)
	g4._abrir_papo_ambiente(m4)
	g4._criar_demanda(m4, true)
	checar(m4.papo == null and m4.demanda != null and g4.count("papos_interrompidos") > 0,
		"demanda interrompe o papo em andamento")


func _testar_sessao_consertos_exames() -> void:
	print("")
	print("[sessao, consertos e exames]")
	var gm = _novo_limpo(5150)
	var caminho := "user://teste_sessao_postinho.dat"
	if FileAccess.file_exists(caminho):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho))

	# Impressora: quebra, abre o minijogo e so volta com a sequencia correta.
	gm.impressora.quebrada = true
	gm.impressora.estado = "quebrada"
	gm.clicar_impressora()
	checar(gm.modal != null and str(gm.modal.get("tipo", "")) == "reparo",
		"impressora quebrada abre o conserto de fios")
	if gm.modal != null:
		var seq_imp: Array = gm.modal.get("sequencia", [])
		for fio in seq_imp:
			gm.minijogo_escolher(int(fio))
	checar(not bool(gm.impressora.get("quebrada", true)), "sequencia correta conserta a impressora")
	checar(gm.count("impressoras_consertadas") >= 1, "conserto da impressora entra na estatistica")

	# Computador: o mesmo minijogo, com a protecao do ultimo PC interno.
	gm.modo_pcs = "um_interno"
	gm._aplicar_modo_pcs()
	var pc = _pc_livre(gm, "interno")
	checar(pc != null, "ha PC interno livre para o conserto")
	if pc != null:
		pc.problema = "grave"
		gm.clicar_pc(str(pc.id))
		checar(gm.modal != null and str(gm.modal.get("tipo", "")) == "reparo",
			"computador quebrado abre o conserto de fios")
		if gm.modal != null:
			var seq_pc: Array = gm.modal.get("sequencia", [])
			for fio in seq_pc:
				gm.minijogo_escolher(int(fio))
		checar(pc.problema == "", "computador consertado volta a funcionar")
		checar(gm.count("pcs_consertados") >= 1, "conserto do PC entra na estatistica")

	# Exame: uma pasta certa entre trinta, sem resposta certa para as demandas.
	gm.tarefas = 1
	gm.energia = 3.0
	gm.abrir_exame({"texto": "A pasta da dona Zulmira tem uma cruz verde."})
	checar(gm.modal != null and str(gm.modal.get("tipo", "")) == "exame",
		"demanda de exame abre o arquivo de pastas")
	if gm.modal != null:
		var alvo := int(gm.modal.get("alvo", -1))
		gm.exame_escolher(alvo)
	checar(gm.modal == null and gm.tarefas == 0, "achar a pasta conclui um trabalho")
	checar(gm.count("exames_encontrados") >= 1, "exame encontrado entra na estatistica")
	var antes_energia: float = gm.energia
	gm.tarefas = 1
	gm.abrir_exame({})
	if gm.modal != null:
		var alvo2 := int(gm.modal.get("alvo", 0))
		gm.exame_escolher((alvo2 + 1) % int(gm.modal.get("pastas", []).size()))
	checar(gm.modal != null and gm.energia < antes_energia,
		"pasta errada gasta energia e mantem a busca aberta")
	if gm.modal != null:
		gm.fechar_dialogo()

	# Trabalho sem PC: so gasta energia.
	gm.tarefas = 2
	gm.energia = 3.0
	var gerou: int = gm._aplicar_consequencia({"sem_pc": true, "custo_energia": 0.25})
	checar(gerou == 0 and gm.tarefas == 2, "trabalho sem PC nao cria tarefa no computador")
	checar(absf(gm.energia - 2.75) < 0.001 and gm.count("tarefas_sem_pc") >= 1,
		"trabalho sem PC apenas gasta energia")

	# Save unico: grava, informa e retoma o mesmo mundo.
	gm.caminho_sessao = caminho
	gm.tempo = 123.5
	gm.tarefas = 4
	gm.energia = 2.5
	# Um nome no formato antigo deve ser migrado ao continuar a sessão.
	var pac_mig = gm._novo_paciente(-1)
	pac_mig.nome = "Paciente 999"
	pac_mig.fase = "sentado"
	pac_mig.pos = Vector2(650, 500)
	checar(gm.salvar_sessao() and gm.tem_sessao(), "sessao e salva no slot unico")
	var info: Dictionary = gm.info_sessao()
	checar(absf(float(info.get("tempo", 0.0)) - 123.5) < 0.01
		and int(info.get("tarefas", 0)) == 4
		and absf(float(info.get("energia", 0.0)) - 2.5) < 0.01,
		"informacoes do save batem com o estado")
	var g2 = _novo_limpo(5151)
	g2.caminho_sessao = caminho
	checar(g2.carregar_sessao(), "sessao salva pode ser continuada")
	checar(absf(g2.tempo - 123.5) < 0.01 and g2.tarefas == 4
		and absf(g2.energia - 2.5) < 0.01,
		"continuar restaura tempo, tarefas e energia")
	checar(g2.entidades.has("jogador") and g2.pessoas.size() > 0,
		"continuar restaura equipe, pacientes e jogador")
	var mig = g2.entidades.get(str(pac_mig.id), null)
	checar(mig != null and not str(mig.nome).begins_with("Paciente ")
		and str(mig.nome).split(" ", false).size() >= 2,
		"nomes numericos antigos viram nomes ficticios ao continuar")
	checar(g2.apagar_sessao() and not g2.tem_sessao(), "slot unico pode ser apagado")


func _testar_partida_longa() -> void:
	print("")
	print("[partida de 8 minutos]")
	var gm = _novo(4242)
	gm.step(480.0)
	checar(absf(gm.tempo - 480.0) < 0.1, "relogio avancou 480 s")
	checar(gm.count("atendidos_guiche") > 0, "pacientes foram atendidos no guiche")
	checar(gm.count("atendidos_sala") > 0, "pacientes foram atendidos nas salas")
	checar(gm.count("pacientes_atendidos") > 0, "pacientes concluiram seus atendimentos")
	checar(gm.count("demandas_geradas") > 0, "demandas surgiram durante a partida")
	checar(gm.modal == null, "o jogador parado nao e preso em dialogos")
	checar(gm.energia >= 0.0 and gm.energia <= gm.E_MAX, "energia do jogador fica entre 0 e 5")
	var energia_ok := true
	var posicao_ok := true
	for p in gm.pessoas:
		if p.visivel and not p.oculto:
			if float(p.energia) < -0.001 or float(p.energia) > float(p.max_energia) + 0.001:
				energia_ok = false
			if p.pos.x < -50.0 or p.pos.x > gm.mundo.x + 50.0 or p.pos.y < -50.0 or p.pos.y > gm.mundo.y + 50.0:
				posicao_ok = false
	checar(energia_ok, "energia dos personagens nunca fica fora dos limites")
	checar(posicao_ok, "ninguem sai do mundo")
	var adultos := 0
	for p in gm.pessoas:
		if str(p.tipo) == "paciente" and str(p.fase) not in ["saindo", "saiu"]:
			adultos += 1
	checar(adultos <= gm.MAX_ADULTOS, "limite de adultos respeitado no fim da partida")
	print("    estatisticas: guiche=%d salas=%d pacientes=%d reclamacoes=%d desistencias=%d recepcao=%d"
		% [gm.count("atendidos_guiche"), gm.count("atendidos_sala"), gm.count("pacientes_atendidos"),
		gm.count("reclamacoes"), gm.count("desistencias") + gm.count("desistencias_fila") + gm.count("desistencias_tolerancia"),
		gm.count("atendidos_recepcao")])
