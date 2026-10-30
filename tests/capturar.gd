extends SceneTree
## Roteiro visual: joga um pouco, abre paineis e salva capturas.
## godot --path . --script res://tests/capturar.gd -- /caminho/das/imagens

var main: Node2D
var dir := "user://capturas"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		dir = args[0]
	DirAccess.make_dir_recursive_absolute(dir)
	main = load("res://scenes/Main.tscn").instantiate()
	get_root().add_child(main)
	_roteiro()


func _process(_delta: float) -> bool:
	return false


func _salvar(nome: String) -> void:
	await process_frame
	await process_frame
	var img := get_root().get_texture().get_image()
	img.save_png(dir.path_join(nome + ".png"))
	print("captura: ", nome)


func _esperar(seg: float) -> void:
	await create_timer(seg).timeout


func _roteiro() -> void:
	await _esperar(0.4)
	var gm = main.gm
	# O roteiro não pode sobrescrever o save real do jogador: o autosave vai
	# para um arquivo temporário dentro da pasta de capturas.
	gm.caminho_sessao = dir.path_join("sessao_captura.dat")

	# Tela inicial: continuar a sessão salva ou começar uma nova.
	main.hud.tela_inicio = true
	main.hud.queue_redraw()
	await _esperar(0.35)
	await _salvar("00_tela_inicio")
	main.hud.tela_inicio = false
	main.hud.queue_redraw()
	await _esperar(3.0)
	main.camera.position = Vector2(720, 450)
	main.camera.zoom = Vector2(0.80, 0.80)
	await _esperar(0.35)
	await _salvar("01_visao_geral")

	# Coloca o agente em um computador interno e forca esforco manual.
	gm.modo_pcs = "um_interno"
	gm._aplicar_modo_pcs()
	var pc_livre = null
	for pc in gm.pcs:
		if str(pc.tipo) == "interno" and str(pc.ocupante) == "" and not bool(pc.jogador):
			pc_livre = pc
			break
	gm.tarefas = 4
	if pc_livre != null:
		gm.clicar_pc(str(pc_livre.id))
		var limite := 0.0
		while int(gm.estado) != int(gm.Estado.NO_PC) and limite < 10.0:
			await _esperar(0.1)
			limite += 0.1
		main.centralizar_jogador()
		await _esperar(0.4)
		gm.clique_jogador()
		await _esperar(0.8)
		print("trabalhando: estado=", gm.estado, " pc=", gm.foco.id if gm.foco != null else "-",
			" esforco=", gm.esforco_manual)
		await _salvar("02_trabalhando")

	# Dialogo com energia cheia.
	gm.fechar_dialogo()
	var chefe = gm.entidades.get("chefe", null)
	if chefe != null:
		gm.energia = gm.E_MAX
		gm.abrir_dialogo(chefe)
		await _esperar(0.3)
		await _salvar("03_dialogo_energia_alta")
		if gm.modal != null and not (gm.modal.opcoes as Array).is_empty():
			gm.escolher_opcao(0)
		await _esperar(0.2)

	# Dialogo com energia baixa.
	if chefe != null:
		gm.energia = 1.2
		gm.abrir_dialogo(chefe)
		await _esperar(0.3)
		await _salvar("04_dialogo_energia_baixa")
		gm.fechar_dialogo()
		gm.energia = gm.E_MAX

	# Menu e subpaginas.
	main.hud.menu_aberto = true
	main.hud.pagina = "home"
	await _esperar(0.2)
	await _salvar("05_menu")
	main.hud.pagina = "personalizar"
	await _esperar(0.2)
	await _salvar("06_personalizar")
	main.hud.pagina = "aparencia"
	await _esperar(0.2)
	await _salvar("07_aparencia")
	main.hud.pagina = "regras"
	await _esperar(0.2)
	await _salvar("08_regras")
	main.hud.pagina = "sons"
	await _esperar(0.2)
	await _salvar("09_sons")
	main.hud.pagina = "info"
	await _esperar(0.2)
	await _salvar("10_info")
	main.hud.pagina = "fechar"
	await _esperar(0.2)
	await _salvar("11_fechar")
	main.hud.menu_aberto = false

	# Visao ampla do posto inteiro, com as paredes em volume.
	main.camera.position = Vector2(720, 450)
	main.camera.zoom = Vector2(0.8, 0.8)
	await _esperar(0.4)
	await _salvar("12_visao_ampla")

	# Papo de corredor: balao, pergunta e replica.
	var medica = gm.entidades.get("medica", null)
	if medica != null:
		medica.visivel = true
		medica.oculto = false
		medica.entrou = true
		medica.demanda = null
		medica.papo = null
		medica.servindo = ""
		medica.fase = "no_posto"
		medica.energia = medica.max_energia
		gm._abrir_papo_ambiente(medica)
		main.camera.position = medica.pos + Vector2(30, -10)
		main.camera.zoom = Vector2(1.15, 1.15)
		await _esperar(0.5)
		await _salvar("13_papo_balao")
		gm.abrir_papo(medica)
		await _esperar(0.3)
		await _salvar("14_papo_conversa")
		if gm.modal != null:
			gm.escolher_opcao(0)
			await _esperar(0.25)
			await _salvar("15_papo_replica")
			if gm.modal != null:
				gm.escolher_opcao(0)

	# Salas de vacina e procedimentos, com carrinhos, poltronas e biombo.
	main.camera.position = Vector2(360, 640)
	main.camera.zoom = Vector2(1.15, 1.15)
	await _esperar(0.45)
	await _salvar("16_salas_vacina_procedimentos")

	# Corredor entre Procedimentos e a Copa, agora com passagem de verdade.
	main.camera.position = Vector2(440, 760)
	main.camera.zoom = Vector2(1.25, 1.25)
	await _esperar(0.45)
	await _salvar("17_corredor_copa")

	# Minijogo de conserto da impressora.
	if gm.modal != null:
		gm.fechar_dialogo()
	gm.impressora.quebrada = true
	gm.impressora.estado = "quebrada"
	gm.clicar_impressora()
	await _esperar(0.45)
	await _salvar("18_reparo_impressora")
	gm.fechar_dialogo()

	# Arquivo de exames, no estilo "onde está o exame?".
	gm.abrir_exame({})
	await _esperar(0.45)
	await _salvar("19_arquivo_exames")
	gm.fechar_dialogo()

	# Um retrato do HUD sem contador de PCs e sem relógio de sessão.
	main.camera.position = Vector2(980, 430)
	main.camera.zoom = Vector2(1.0, 1.0)
	await _esperar(0.45)
	await _salvar("20_hud_sem_relogio")

	# Fecha sem deixar o _exit_tree gravar uma sessao de captura no lugar do save real.
	main.hud.tela_inicio = true
	var sessao_tmp := dir.path_join("sessao_captura.dat")
	if FileAccess.file_exists(sessao_tmp):
		DirAccess.remove_absolute(sessao_tmp)
	print("roteiro concluido")
	quit(0)
