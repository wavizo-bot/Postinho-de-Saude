extends Node
## Motor de regras do Postinho de Saude.
## Nao desenha nada. Avanca o mundo em passos fixos e recebe comandos da tela.
## As regras de balanceamento ficam em data/*.json.

enum Estado { LIVRE, CAMINHANDO, NO_PC, NA_COPA, CONVERSANDO }
enum ModoCafe { NENHUM, ESPERANDO, TOMANDO, ESPERANDO_VAGA }

const PASSO: float = 0.05
const EPS: float = 0.0001
const PathfinderScript = preload("res://scripts/Pathfinder.gd")
const SESSAO_VERSAO: int = 1

# Dados brutos
var cfg: Dictionary = {}
var layout: Dictionary = {}
var dnpcs: Dictionary = {}
var demandas_def: Dictionary = {}
var papos_def: Dictionary = {}
var textos: Dictionary = {}
var erros_dados: PackedStringArray = []

# Mundo
var mundo: Vector2 = Vector2(1440, 900)
var tela: Vector2 = Vector2(1280, 720)
var construcao: Rect2 = Rect2(24, 24, 1392, 852)
var lobby: Rect2 = Rect2(520, 34, 872, 832)
var salas: Array = []
var guiche: Dictionary = {}
var pcs: Array = []
var pcs_por_id: Dictionary = {}
var cadeiras: Array = []
var espacos_em_pe: Array = []
var copa_spots: Array = []
var zona_cadeiras: Rect2 = Rect2()
var entrada: Dictionary = {}
var porta_lateral: Dictionary = {}
var jogador_inicio: Vector2 = Vector2(1160, 218)
var nav = PathfinderScript.new()

# Pessoas
var pessoas: Array = []
var entidades: Dictionary = {}
var proximo_id: int = 0
var ordem_chegada: int = 0

# Jogador
var tempo: float = 0.0
var energia: float = 5.0
var tarefas: int = 0
var prog: float = 0.0
var esforco_manual: bool = false
var estado: int = Estado.LIVRE
var pos: Vector2 = Vector2.ZERO
var foco = null
var modal = null
var cafe_modo: int = ModoCafe.NENHUM
var cafe_timer: float = 0.0
var acao_pendente: Dictionary = {}
var atendendo_paciente: String = ""
var atendimento_timer: float = 0.0
var aproximacao_pc: String = ""

# Relogios e filas
var prox_demanda: float = 8.0
var prox_paciente: float = 14.0
var fila_guiche: Array = []
var guiche_atendendo: String = ""
var guiche_timer: float = 0.0
var fila_recepcao: Array = []
var fila_chefe: Array = []
var agenda_pcs: float = 0.0
var agenda_problema: float = 0.0
var modo_pcs: String = "ambos"
var alertas: Array = []
var popup: Dictionary = {}
var contadores: Dictionary = {}
var sons: Array = []
var regras: Dictionary = {}

# Objetos e sessão
var impressora: Dictionary = {}
var exame_busca: Dictionary = {}
var caminho_sessao: String = "user://sessao_postinho.dat"
var nomes_usados: Dictionary = {}
var ultimo_erro_sessao: String = ""
var exame_pendente: bool = false

# Balanceamento
var E_MAX: float = 5.0
var TAREFAS_MAX: int = 10
var TEMPO_TAREFA: float = 3.2
var CUSTO_TAREFA: float = 0.32
var RENDIMENTO: float = 0.3125
var ESP_VEL: float = 0.25
var ESP_GASTO: float = 1.25
var ESP_ENERGIA_MIN: float = 0.15
var AURA_RAIO: float = 150.0
var PAPO_MIN: float = 80.0
var PAPO_MAX: float = 170.0
var PAPO_DURACAO: float = 22.0
var PAPO_MAX_ATIVOS: int = 3
var CAFE_TEMPO: float = 3.0
var CAFE_GANHO: float = 1.0
var DEM_MIN: float = 7.0
var DEM_MAX: float = 14.0
var DEM_VIDA_MIN: float = 55.0
var DEM_VIDA_MAX: float = 115.0
var DEM_VIDA_CHEFE: float = 0.0
var DEM_DESISTENCIA: float = 0.01
var GUICHE_MIN: float = 2.0
var GUICHE_MAX: float = 6.0
var REC_ATEND_MIN: float = 4.0
var REC_ATEND_MAX: float = 9.0
var SALA_MIN: float = 18.0
var SALA_MAX: float = 40.0
var CHEFE_MIN: float = 12.0
var CHEFE_MAX: float = 24.0
var PRIMEIRO_PACIENTE: float = 14.0
var NOVO_PAC_MIN: float = 9.0
var NOVO_PAC_MAX: float = 16.0
var MAX_FILA_GUICHE: int = 8
var VEL_FUNC: float = 92.0
var VEL_JOG: float = 105.0
var VEL_CRIANCA: float = 108.0
var FATOR_ENERGIA_MIN: float = 0.55
var RAIO_CHEGADA: float = 5.0
var DISTANCIA_LADO: float = 28.0
var NPC_E_MAX: float = 5.0
var NPC_E_MIN: float = 3.4
var NPC_E_MAX_INI: float = 5.0
var NPC_CUSTO_ATEND: float = 0.34
var NPC_CUSTO_PC: float = 0.018
var LIM_LOW: float = 1.25
var LIM_HIGH: float = 3.5
var MAX_ADULTOS: int = 12
var CHANCE_CRIANCA: float = 0.22
var CHANCE_ANIMAL: float = 0.34
var MAX_CRIANCAS_ADULTO: int = 6
var CHANCE_SEGUNDO: float = 0.18
var PAC_TOL_MIN: float = 60.0
var PAC_TOL_MAX: float = 300.0
var PAC_FILA_MIN: float = 22.0
var PAC_FILA_MAX: float = 75.0
var PAC_LIMITE_FILA_MIN: int = 4
var PAC_LIMITE_FILA_MAX: int = 9
var RAIVA_ESPERA: float = 1.4
var RAIVA_FILA: float = 2.4
var RAIVA_BOM: float = -18.0
var RAIVA_RUIM: float = 22.0
var RAIVA_RECLAMAR: float = 62.0
var RAIVA_ABANDONO: float = 92.0
var RAIVA_ENERGIA: float = 0.38
var RAIVA_ABORDAGEM: float = 0.035
var DIST_ABORDAGEM: float = 120.0
var TEMPO_RECLAMACAO: float = 9.0
var PC_INTERVALO_MIN: float = 12.0
var PC_INTERVALO_MAX: float = 28.0
var PC_PROBLEMA_CHANCE: float = 0.10
var PC_PROBLEMA_MIN: float = 12.0
var PC_PROBLEMA_MAX: float = 30.0
var PC_PROBLEMA_LEVE: float = 0.5
var PC_INTERRUPCAO_CHANCE: float = 0.035
var PC_ABORDAGEM_CHANCE: float = 0.035
var CRIANCA_RAIO: float = 58.0
var CRIANCA_VEL: float = 55.0
var CRIANCA_DIST: float = 34.0
var IMP_MIN: float = 38.0
var IMP_MAX: float = 78.0
var IMP_CHANCE: float = 0.88
var IMP_FIOS: int = 3
var EXAME_PASTAS: int = 30
var EXAME_ERRO: float = 0.04
var SAVE_A_CADA: float = 20.0
var ANIMAIS_MIN: int = 8
var ANIMAL_EXTRA: float = 0.18
var DISTR_SALAS: Array = []
var links: Dictionary = {}

# Coeficientes alteráveis pelo menu
var mult_demandas: float = 1.0
var mult_pacientes: float = 1.0
var mult_paciencia: float = 1.0
var tema: String = "classico"
var sons_ligados: bool = true
var ri := RandomNumberGenerator.new()


# =================================================================== dados

func carregar_dados() -> bool:
	var dm = load("res://scripts/DataManager.gd").new()
	var ok: bool = dm.carregar()
	erros_dados = dm.erros
	if not ok:
		return false
	cfg = dm.config
	layout = dm.layout
	dnpcs = dm.npcs
	demandas_def = dm.demandas
	papos_def = dm.papos
	textos = dm.textos
	_extrair_config()
	return true


func _num(secao: Dictionary, chave: String, padrao: float) -> float:
	var v = secao.get(chave, padrao)
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
		return float(v)
	return padrao


func _int(secao: Dictionary, chave: String, padrao: int) -> int:
	return int(_num(secao, chave, float(padrao)))


func _txt(secao: String, chave: String, padrao: String) -> String:
	var s: Dictionary = textos.get(secao, {})
	return str(s.get(chave, padrao))


func _extrair_config() -> void:
	var r: Dictionary = cfg.get("recurso", {})
	E_MAX = _num(r, "energia_max", 5.0)
	TAREFAS_MAX = _int(r, "tarefas_max", 10)
	TEMPO_TAREFA = _num(r, "tempo_tarefa_s", 3.2)
	CUSTO_TAREFA = _num(r, "custo_tarefa", 0.32)
	RENDIMENTO = _num(r, "rendimento_trabalho_por_segundo", CUSTO_TAREFA / TEMPO_TAREFA)
	var e: Dictionary = cfg.get("esforco", {})
	ESP_VEL = _num(e, "bonus_velocidade", 0.25)
	ESP_GASTO = 1.0 + _num(e, "bonus_custo", 0.25)
	ESP_ENERGIA_MIN = _num(e, "energia_minima_para_ativar", 0.15)
	AURA_RAIO = _num(e, "raio_aura_chefe", 150.0)
	var pp: Dictionary = cfg.get("papo", {})
	PAPO_MIN = _num(pp, "intervalo_min_s", 80.0)
	PAPO_MAX = _num(pp, "intervalo_max_s", 170.0)
	PAPO_DURACAO = _num(pp, "duracao_s", 22.0)
	PAPO_MAX_ATIVOS = _int(pp, "max_ativos", 3)
	var c: Dictionary = cfg.get("copa", {})
	CAFE_TEMPO = _num(c, "tempo_cafe_s", 3.0)
	CAFE_GANHO = _num(c, "ganho_cafe", 1.0)
	var d: Dictionary = cfg.get("demandas", {})
	DEM_MIN = _num(d, "intervalo_min_s", 7.0)
	DEM_MAX = _num(d, "intervalo_max_s", 14.0)
	DEM_VIDA_MIN = _num(d, "tempo_vida_min_s", 55.0)
	DEM_VIDA_MAX = _num(d, "tempo_vida_max_s", 115.0)
	DEM_VIDA_CHEFE = _num(d, "tempo_vida_chefe_s", 0.0)
	DEM_DESISTENCIA = _num(d, "chance_desistencia_por_segundo", 0.01)
	var p: Dictionary = cfg.get("presenca", {})
	PRIMEIRO_PACIENTE = _num(p, "primeiro_paciente_em_s", 14.0)
	NOVO_PAC_MIN = _num(p, "novo_paciente_min_s", 9.0)
	NOVO_PAC_MAX = _num(p, "novo_paciente_max_s", 16.0)
	GUICHE_MIN = _num(p, "tempo_guiche_min_s", 2.0)
	GUICHE_MAX = _num(p, "tempo_guiche_max_s", 6.0)
	REC_ATEND_MIN = _num(p, "tempo_recepcao_min_s", 4.0)
	REC_ATEND_MAX = _num(p, "tempo_recepcao_max_s", 9.0)
	SALA_MIN = _num(p, "tempo_sala_min_s", 18.0)
	SALA_MAX = _num(p, "tempo_sala_max_s", 40.0)
	CHEFE_MIN = _num(p, "tempo_chefe_min_s", 12.0)
	CHEFE_MAX = _num(p, "tempo_chefe_max_s", 24.0)
	MAX_FILA_GUICHE = _int(p, "max_fila_guiche", 8)
	var m: Dictionary = cfg.get("movimento", {})
	VEL_FUNC = _num(m, "velocidade_funcionario", 92.0)
	VEL_JOG = _num(m, "velocidade_jogador", 105.0)
	VEL_CRIANCA = _num(m, "velocidade_crianca", 108.0)
	FATOR_ENERGIA_MIN = _num(m, "fator_energia_minima", 0.55)
	RAIO_CHEGADA = _num(m, "raio_chegada", 5.0)
	DISTANCIA_LADO = _num(m, "distancia_ao_lado", 28.0)
	var f: Dictionary = cfg.get("funcionarios", {})
	NPC_E_MAX = _num(f, "energia_max", 5.0)
	NPC_E_MIN = _num(f, "energia_inicial_min", 3.4)
	NPC_E_MAX_INI = _num(f, "energia_inicial_max", 5.0)
	NPC_CUSTO_ATEND = _num(f, "custo_atendimento", 0.34)
	NPC_CUSTO_PC = _num(f, "custo_trabalho_pc_por_s", 0.018)
	LIM_LOW = _num(f, "limiar_energia_baixa", 1.25)
	LIM_HIGH = _num(f, "limiar_energia_alta", 3.5)
	var pac: Dictionary = dnpcs.get("pacientes", {})
	MAX_ADULTOS = _int(pac, "max_adultos", 12)
	CHANCE_CRIANCA = _num(pac, "chance_crianca", 0.22)
	MAX_CRIANCAS_ADULTO = _int(pac, "max_criancas_por_adulto", 6)
	CHANCE_SEGUNDO = _num(pac, "chance_segundo_atendimento", 0.18)
	PAC_TOL_MIN = _num(pac, "tempo_minimo_espera_s", 60.0)
	PAC_TOL_MAX = _num(pac, "tempo_maximo_espera_s", 300.0)
	PAC_FILA_MIN = _num(pac, "tolerancia_fila_min_s", 22.0)
	PAC_FILA_MAX = _num(pac, "tolerancia_fila_max_s", 75.0)
	PAC_LIMITE_FILA_MIN = _int(pac, "limite_fila_min", 4)
	PAC_LIMITE_FILA_MAX = _int(pac, "limite_fila_max", 9)
	var pa: Dictionary = cfg.get("pacientes", {})
	RAIVA_ESPERA = _num(pa, "raiva_espera_por_s", 1.4)
	RAIVA_FILA = _num(pa, "raiva_fila_longa_por_s", 2.4)
	RAIVA_BOM = _num(pa, "raiva_bom_atendimento", -18.0)
	RAIVA_RUIM = _num(pa, "raiva_atendimento_ruim", 22.0)
	RAIVA_RECLAMAR = _num(pa, "raiva_limiar_reclamar", 62.0)
	RAIVA_ABANDONO = _num(pa, "raiva_limiar_abandono", 92.0)
	RAIVA_ENERGIA = _num(pa, "energia_reduzida_por_reclamacao", 0.38)
	RAIVA_ABORDAGEM = _num(pa, "chance_abordagem_raivosa_s", 0.035)
	DIST_ABORDAGEM = _num(pa, "distancia_abordagem", 120.0)
	TEMPO_RECLAMACAO = _num(pa, "tempo_reclamacao_s", 9.0)
	var pc: Dictionary = cfg.get("computadores", {})
	PC_INTERVALO_MIN = _num(pc, "intervalo_sorteio_min_s", 12.0)
	PC_INTERVALO_MAX = _num(pc, "intervalo_sorteio_max_s", 28.0)
	PC_PROBLEMA_CHANCE = _num(pc, "chance_problema", 0.10)
	PC_PROBLEMA_MIN = _num(pc, "problema_min_s", 12.0)
	PC_PROBLEMA_MAX = _num(pc, "problema_max_s", 30.0)
	PC_PROBLEMA_LEVE = _num(pc, "fator_problema_leve", 0.5)
	PC_INTERRUPCAO_CHANCE = _num(pc, "chance_interrupcao_recepcao_por_s", 0.035)
	PC_ABORDAGEM_CHANCE = _num(pc, "chance_abordagem_interno_por_s", 0.035)
	var cr: Dictionary = cfg.get("criancas", {})
	CRIANCA_RAIO = _num(cr, "raio_passeio", 58.0)
	CRIANCA_VEL = _num(cr, "velocidade_passeio", 55.0)
	CRIANCA_DIST = _num(cr, "distancia_adulto", 34.0)
	var imp: Dictionary = cfg.get("impressora", {})
	IMP_MIN = _num(imp, "intervalo_min_s", 38.0)
	IMP_MAX = _num(imp, "intervalo_max_s", 78.0)
	IMP_CHANCE = _num(imp, "chance_quebra", 0.88)
	IMP_FIOS = maxi(2, _int(imp, "fios", 3))
	var ex: Dictionary = cfg.get("exame", {})
	EXAME_PASTAS = maxi(12, _int(ex, "pastas", 30))
	EXAME_ERRO = _num(ex, "energia_erro", 0.04)
	var se: Dictionary = cfg.get("sessao", {})
	SAVE_A_CADA = maxf(5.0, _num(se, "salvar_a_cada_s", 20.0))
	var eq: Dictionary = cfg.get("equipe", {})
	ANIMAIS_MIN = maxi(1, _int(eq, "animais_minimos", 8))
	ANIMAL_EXTRA = _num(eq, "chance_animal_extra", 0.18)
	CHANCE_ANIMAL = _num(pac, "chance_animal", 0.34)
	links = cfg.get("links", {})
	sons_ligados = bool(cfg.get("audio", {}).get("ativo_padrao", true))
	DISTR_SALAS.clear()
	var por: Dictionary = pac.get("porcentagem_por_sala", {})
	for sala_id in por:
		var chave := str(sala_id)
		DISTR_SALAS.append({
			"tipo": "recepcao" if chave == "recepcao" else "sala",
			"sala": "" if chave == "recepcao" else chave,
			"peso": float(por[sala_id]),
		})
	if DISTR_SALAS.is_empty():
		DISTR_SALAS.append({"tipo": "sala", "sala": "B", "peso": 100.0})


# =================================================================== util

func _vet(v) -> Vector2:
	if v is Array and v.size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	if v is Vector2:
		return v
	if v is Dictionary:
		if v.has("largura") and v.has("altura"):
			return Vector2(float(v["largura"]), float(v["altura"]))
		if v.has("x") and v.has("y"):
			return Vector2(float(v["x"]), float(v["y"]))
	return Vector2.ZERO


func _vet_ou_nulo(v):
	if v is Array and v.size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	return null


func _cor(v, padrao: String = "#ffffff") -> String:
	if v == null:
		return padrao
	return str(v)


func _sala_por_id(id: String):
	for sala in salas:
		if sala.id == id:
			return sala
	return null


func _pessoa(id: String):
	return entidades.get(id, null)


func jogador() -> Dictionary:
	return entidades["jogador"]


func inc(chave: String) -> void:
	contadores[chave] = int(contadores.get(chave, 0)) + 1


func count(chave: String) -> int:
	return int(contadores.get(chave, 0))


func alerta(texto: String, dur: float = 3.0) -> void:
	alertas.append({"texto": texto, "t": dur})
	while alertas.size() > 4:
		alertas.pop_front()


func som(nome: String) -> void:
	if sons_ligados:
		sons.append(nome)


func _escolher_por_peso(lista: Array, pesos: Array):
	var total := 0.0
	for p in pesos:
		total += maxf(0.0, float(p))
	if total <= 0.0:
		return lista[0]
	var alvo := ri.randf() * total
	var acc := 0.0
	for i in lista.size():
		acc += maxf(0.0, float(pesos[i]))
		if alvo <= acc:
			return lista[i]
	return lista[lista.size() - 1]


func _embaralhar(lista: Array) -> void:
	var i := lista.size() - 1
	while i > 0:
		var j := ri.randi_range(0, i)
		var tmp = lista[i]
		lista[i] = lista[j]
		lista[j] = tmp
		i -= 1


# =================================================================== mundo

func _montar_mundo() -> void:
	pessoas.clear()
	entidades.clear()
	salas.clear()
	pcs.clear()
	pcs_por_id.clear()
	cadeiras.clear()
	espacos_em_pe.clear()
	copa_spots.clear()
	alertas.clear()
	popup = {}
	contadores.clear()
	sons.clear()
	fila_guiche.clear()
	fila_recepcao.clear()
	fila_chefe.clear()
	guiche_atendendo = ""
	guiche_timer = 0.0
	proximo_id = 0
	ordem_chegada = 0
	nomes_usados.clear()
	exame_busca = {}
	modal = null
	tela = _vet(layout.get("tela", {"largura": 1280, "altura": 720}))
	mundo = Vector2(_num(layout.get("mundo", {}), "largura", 1440.0), _num(layout.get("mundo", {}), "altura", 900.0))
	var c: Dictionary = layout.get("construcao", {})
	construcao = Rect2(_num(c, "x", 24.0), _num(c, "y", 24.0), _num(c, "w", 1392.0), _num(c, "h", 852.0))
	var l: Dictionary = layout.get("lobby", {})
	lobby = Rect2(_num(l, "x", 520.0), _num(l, "y", 34.0), _num(l, "w", 872.0), _num(l, "h", 832.0))
	entrada = layout.get("entrada", {}).duplicate(true)
	porta_lateral = layout.get("porta_lateral", {}).duplicate(true)
	jogador_inicio = _vet(layout.get("jogador_inicio", [1160, 218]))
	var impd: Dictionary = layout.get("impressora", {})
	impressora = {
		"pos": _vet([impd.get("x", 856), impd.get("y", 96)]),
		"estado": "ok", "quebrada": false, "trocas": 0,
		"proxima": 0.0,
	}
	for d in layout.get("salas", []):
		var sala := {
			"id": str(d.get("id", "")), "nome": str(d.get("nome", "")), "tipo": str(d.get("tipo", "sala")),
			"x": _num(d, "x", 0), "y": _num(d, "y", 0), "w": _num(d, "w", 0), "h": _num(d, "h", 0),
			"cor": str(d.get("cor", "#e8e2d3")), "cadeira": _vet_ou_nulo(d.get("cadeira")),
			"cadeiras": [], "paciente_spots": [], "paciente_ocupado": {},
			"capacidade": _int(d, "capacidade", 3), "tipo_movel": str(d.get("movel", "")),
			"porta": d.get("porta", {}), "cafe": _vet_ou_nulo(d.get("cafe")),
		}
		for cadeira in d.get("cadeiras", []):
			sala.cadeiras.append(_vet(cadeira))
		if sala.cadeiras.is_empty() and sala.cadeira != null:
			sala.cadeiras.append(sala.cadeira)
		for spot in d.get("paciente_spots", []):
			sala.paciente_spots.append(_vet(spot))
		sala.rect = Rect2(sala.x, sala.y, sala.w, sala.h)
		salas.append(sala)
		if sala.tipo == "copa" and sala.cafe != null:
			_montar_spots_copa(sala)
	guiche = layout.get("guiche", {}).duplicate(true)
	for pc_d in layout.get("pcs", []):
		var pc := {
			"id": str(pc_d.get("id", "")), "tipo": str(pc_d.get("tipo", "recepcao")),
			"sala": str(pc_d.get("sala", "")), "pos": _vet([pc_d.get("x", 0), pc_d.get("y", 0)]),
			"assento": _vet(pc_d.get("assento", [pc_d.get("x", 0), pc_d.get("y", 0)])),
			"mesa": _rect_de(pc_d.get("mesa"), Rect2(-38, -18, 76, 36)),
			"atendimento": _vet_ou_nulo(pc_d.get("atendimento")),
			"ocupante": "", "jogador": false, "problema": "", "problema_ate": 0.0,
			"atendimento_id": "", "reservado": "",
		}
		pcs.append(pc)
		pcs_por_id[pc.id] = pc
	_gerar_cadeiras()
	for p in layout.get("em_pe", []):
		espacos_em_pe.append(_vet(p))
	if espacos_em_pe.is_empty():
		espacos_em_pe.append(Vector2(610, 340))
	_montar_navegacao()


func _rect_de(v, padrao: Rect2) -> Rect2:
	if v is Array and v.size() >= 4:
		return Rect2(float(v[0]), float(v[1]), float(v[2]), float(v[3]))
	return padrao


func _gerar_cadeiras() -> void:
	var g: Dictionary = layout.get("cadeiras_grade", {})
	if g.is_empty():
		return
	var x0 := _num(g, "x", 670.0)
	var y0 := _num(g, "y", 340.0)
	var cols := _int(g, "cols", 13)
	var rows := _int(g, "rows", 12)
	var dx := _num(g, "dx", 68.0)
	var dy := _num(g, "dy", 50.0)
	var cor_cols: Array = []
	for c in g.get("corredor_cols", []):
		cor_cols.append(int(c))
	var cor_rows: Array = []
	for r in g.get("corredor_rows", []):
		cor_rows.append(int(r))
	for row in rows:
		if row in cor_rows:
			continue
		for col in cols:
			if col in cor_cols:
				continue
			var p := Vector2(x0 + col * dx, y0 + row * dy)
			if not _cadeira_valida(p):
				continue
			cadeiras.append({"pos": p, "ocupante": ""})
	if not cadeiras.is_empty():
		var minp: Vector2 = cadeiras[0].pos
		var maxp: Vector2 = cadeiras[0].pos
		for c in cadeiras:
			minp.x = minf(minp.x, c.pos.x)
			minp.y = minf(minp.y, c.pos.y)
			maxp.x = maxf(maxp.x, c.pos.x)
			maxp.y = maxf(maxp.y, c.pos.y)
		zona_cadeiras = Rect2(minp - Vector2(26, 24), (maxp - minp) + Vector2(52, 48))


func _cadeira_valida(p: Vector2) -> bool:
	if not lobby.grow(18).has_point(p):
		return false
	for pc in pcs:
		if pc.atendimento != null and p.distance_to(pc.atendimento) < 48.0:
			return false
	var fila: Array = guiche.get("fila", [])
	for f in fila:
		if p.distance_to(_vet(f)) < 30.0:
			return false
	var seta: Vector2 = _vet(layout.get("entrada", {}).get("seta_saida", [1462, 170]))
	if p.distance_to(seta) < 55.0:
		return false
	var lateral: Vector2 = _vet(porta_lateral.get("seta", [1494, 500]))
	if p.distance_to(lateral) < 48.0:
		return false
	return true


func _montar_spots_copa(sala: Dictionary) -> void:
	var c: Vector2 = sala.cafe
	copa_spots = [
		c + Vector2(-55, -12), c + Vector2(-20, -10), c + Vector2(20, 18),
		c + Vector2(-45, 32), c + Vector2(8, -2), c + Vector2(48, 34),
		c + Vector2(-70, 35), c + Vector2(55, -16),
	]


func _montar_navegacao() -> void:
	var areas: Array = []
	var p := _num(layout.get("construcao", {}), "parede", 10.0)
	areas.append(Rect2(construcao.position + Vector2(p, p), construcao.size - Vector2(p * 2, p * 2)))
	var porta: Vector2 = _vet(entrada.get("porta", [1462, 42]))
	areas.append(Rect2(porta.x - 46, 0, 92, 70))
	var bloqueios: Array = []
	bloqueios.append(Rect2(construcao.position.x, construcao.position.y, p, construcao.size.y))
	bloqueios.append(Rect2(construcao.end.x - p, construcao.position.y, p, construcao.size.y))
	bloqueios.append(Rect2(construcao.position.x, construcao.end.y - p, construcao.size.x, p))
	var vao := 44.0
	bloqueios.append(Rect2(construcao.position.x, construcao.position.y, porta.x - vao, p))
	bloqueios.append(Rect2(porta.x + vao, construcao.position.y, construcao.end.x - porta.x - vao, p))
	for sala in salas:
		var r := Rect2(sala.x, sala.y, sala.w, sala.h)
		bloqueios.append(Rect2(r.position.x, r.position.y, r.size.x, p))
		bloqueios.append(Rect2(r.position.x, r.end.y - p, r.size.x, p))
		bloqueios.append(Rect2(r.position.x, r.position.y, p, r.size.y))
		var porta_sala: Dictionary = sala.porta
		var centro := _num(porta_sala, "centro", r.position.y + r.size.y * 0.5)
		var largura := _num(porta_sala, "largura", 48.0)
		var topo := centro - largura * 0.5
		var base := centro + largura * 0.5
		if topo > r.position.y:
			bloqueios.append(Rect2(r.end.x - p, r.position.y, p, topo - r.position.y))
		if base < r.end.y:
			bloqueios.append(Rect2(r.end.x - p, base, p, r.end.y - base))
		if sala.tipo == "chefe":
			bloqueios.append(Rect2(r.position.x + 58, r.position.y + 60, 108, 40))
		if sala.tipo == "copa" and sala.cafe != null:
			bloqueios.append(Rect2(sala.cafe.x - 22, sala.cafe.y - 24, 48, 45))
	for pc in pcs:
		bloqueios.append(pc.mesa)
	if not guiche.is_empty():
		bloqueios.append(Rect2(_num(guiche, "x", 862), _num(guiche, "y", 118), _num(guiche, "w", 226), _num(guiche, "h", 46)))
	if not impressora.is_empty():
		bloqueios.append(Rect2((impressora.pos as Vector2) + Vector2(-20, -18), Vector2(40, 34)))
	for d in layout.get("decoracao", []):
		if str(d.get("tipo", "")) in ["planta", "bebedouro", "lixeira"]:
			var q := _vet([d.get("x", 0), d.get("y", 0)])
			bloqueios.append(Rect2(q - Vector2(10, 8), Vector2(20, 16)))
	nav.configurar(mundo, areas, bloqueios, 16.0)


# =================================================================== inicio

func iniciar(semente: int = -1) -> void:
	if semente >= 0:
		ri.seed = semente
	else:
		ri.randomize()
	if not cfg.is_empty():
		_extrair_config()
	_montar_mundo()
	tempo = 0.0
	energia = E_MAX
	tarefas = 0
	prog = 0.0
	esforco_manual = false
	estado = Estado.LIVRE
	cafe_modo = ModoCafe.NENHUM
	cafe_timer = 0.0
	foco = null
	modal = null
	acao_pendente = {}
	atendendo_paciente = ""
	atendimento_timer = 0.0
	aproximacao_pc = ""
	exame_pendente = false
	prox_demanda = ri.randf_range(DEM_MIN, DEM_MAX) * mult_demandas
	prox_paciente = PRIMEIRO_PACIENTE * mult_pacientes
	agenda_pcs = tempo + ri.randf_range(PC_INTERVALO_MIN, PC_INTERVALO_MAX)
	agenda_problema = tempo + ri.randf_range(8.0, 16.0)
	impressora.proxima = ri.randf_range(IMP_MIN, IMP_MAX)
	_criar_pessoas()
	_sortear_modo_pcs(true)
	_preparar_entradas()
	for i in 2:
		_novo_paciente(tempo + 2.4 + i * 1.1)
	alerta(_txt("hud", "dica_inicio", "A equipe está chegando."), 4.0)
	som("porta")


func _criar_pessoas() -> void:
	var indice := 0
	var sala_defs: Array = dnpcs.get("funcionarios_sala", [])
	for d in sala_defs:
		var sala = _sala_por_id(str(d.get("sala", "")))
		if sala == null:
			continue
		var chave := str(d.get("cargo_key", sala.tipo))
		var dados := _dados_funcionario(str(d.get("id", "")), str(d.get("cargo", sala.nome)), chave, sala, indice)
		var p := _criar_funcionario(dados, "funcionario_sala", sala)
		p.spot_index = _int(d, "spot", 0)
		p.posto = sala.cadeiras[mini(p.spot_index, sala.cadeiras.size() - 1)] if not sala.cadeiras.is_empty() else sala.rect.get_center()
		p.posto_tipo = "sala"
		p.entrada_em = 0.8 + indice * 0.16
		indice += 1
	var g: Dictionary = dnpcs.get("funcionario_guiche", {})
	if not g.is_empty():
		var dados_g := _dados_funcionario(str(g.get("id", "guiche")), "Guichê", "guiche", null, indice)
		var pg := _criar_funcionario(dados_g, "guiche", null)
		pg.posto = _vet(guiche.get("funcionario", [655, 50]))
		pg.posto_tipo = "guiche"
		pg.entrada_em = 0.8 + indice * 0.16
		indice += 1
	var rr: Dictionary = dnpcs.get("funcionarios_recepcao", {})
	var personagens_rec: Array = rr.get("personagens", [])
	for i in _int(rr, "quantidade", 3):
		var id_rec := str(personagens_rec[i].get("id", "rec_%d" % (i + 1))) if i < personagens_rec.size() else "rec_%d" % (i + 1)
		var dados_r := _dados_funcionario(id_rec, "Recepção", "recepcao", null, indice)
		var pr := _criar_funcionario(dados_r, "recepcao", null)
		pr.posto_tipo = "pc"
		pr.entrada_em = 0.8 + indice * 0.16
		indice += 1
	var aa: Dictionary = dnpcs.get("funcionarios_acs", {})
	var personagens_acs: Array = aa.get("personagens", [])
	for i in _int(aa, "quantidade", 9):
		var id_acs := str(personagens_acs[i].get("id", "acs_%d" % (i + 1))) if i < personagens_acs.size() else "acs_%d" % (i + 1)
		var dados_a := _dados_funcionario(id_acs, "ACS", "acs", null, indice)
		var pa := _criar_funcionario(dados_a, "acs", null)
		pa.posto_tipo = "pc"
		pa.entrada_em = 0.8 + indice * 0.16
		indice += 1
	var j: Dictionary = dnpcs.get("jogador", {})
	var pj := _criar_pessoa("jogador", "jogador", str(j.get("nome", "Agente")), j)
	pj.posto = jogador_inicio
	pj.posto_tipo = "livre"
	pj.entrada_em = 0.55
	pj.visivel = false
	pj.fase = "aguardando_entrada"
	pos = _vet(entrada.get("spawn", [1320, 2]))
	pj.pos = pos
	_garantir_animais()


func _dados_funcionario(id: String, cargo: String, chave: String, sala, indice: int) -> Dictionary:
	var ap: Dictionary = dnpcs.get("aparencia", {})
	var uniforme: Dictionary = ap.get("uniformes", {}).get(chave, {})
	var genero := "feminino" if ri.randf() < 0.54 else "masculino"
	var animal := (indice % 5 == 0 or indice % 5 == 2) or ri.randf() < ANIMAL_EXTRA
	var d := _aparencia_pessoa(animal, genero)
	d["id"] = id
	d["nome"] = _sortear_nome(genero)
	d["cargo"] = cargo
	d["cargo_key"] = chave
	d["genero"] = genero
	d["roupa"] = str(uniforme.get("roupa", "#4f6e6a"))
	d["roupa2"] = str(uniforme.get("roupa2", "#eef4ef"))
	d["calca"] = str(uniforme.get("calca", "#2b4a35"))
	d["sapato"] = "#2b2d42"
	d["estilo_cabelo"] = _aleatorio(ap.get("estilos_cabelo", ["curto"]), "curto")
	d["chapeu"] = _aleatorio(["nenhum", "nenhum", "nenhum", "touca", "boina"], "nenhum")
	d["acessorio"] = _aleatorio(["nenhum", "nenhum", "oculos", "mascara"], "nenhum")
	if animal:
		# Animais usam o pelo como cor de rosto; o uniforme continua profissional.
		d["pele"] = _aleatorio(ap.get("pelos_animais", ["#c9a27e"]), "#c9a27e")
	if sala != null:
		d["sala"] = str(sala.id)
	return d


func _sortear_nome(genero: String, sobrenome_fixo: String = "") -> String:
	var ap: Dictionary = dnpcs.get("aparencia", {})
	var pool: Array = ap.get("nomes_femininos", ["Mara"]) if genero == "feminino" else ap.get("nomes_masculinos", ["Caio"])
	if ri.randf() < 0.10:
		pool = ap.get("nomes_neutros", pool)
	var sobrenomes: Array = ap.get("sobrenomes", ["Silva"])
	for tentativa in 60:
		var nome := _aleatorio(pool, "Alex")
		var sobrenome := sobrenome_fixo
		if sobrenome == "":
			sobrenome = _aleatorio(sobrenomes, "Silva")
		if sobrenome != "":
			nome += " " + sobrenome
		if not nomes_usados.has(nome):
			nomes_usados[nome] = true
			return nome
	return "%s %s" % [_aleatorio(pool, "Alex"), _aleatorio(sobrenomes, "Silva")]


func _sobrenome_de(nome: String) -> String:
	var partes := nome.split(" ", false)
	if partes.size() <= 1:
		return ""
	return str(partes[partes.size() - 1])


func _aparencia_pessoa(animal: bool, genero: String) -> Dictionary:
	var ap: Dictionary = dnpcs.get("aparencia", {})
	var especie := "humano"
	var pele := _aleatorio(ap.get("tons_pele", ["#D69F7E"]), "#D69F7E")
	if animal:
		especie = _aleatorio(ap.get("especies_animais", ["capivara"]), "capivara")
		pele = _aleatorio(ap.get("pelos_animais", ["#c9a27e"]), "#c9a27e")
	return {
		"pele": pele,
		"especie": especie,
		"animal": animal,
		"roupa": _aleatorio(ap.get("cores_roupa", ["#e76f51"]), "#e76f51"),
		"roupa2": _aleatorio(ap.get("cores_roupa", ["#f4a261"]), "#f4a261"),
		"calca": _aleatorio(ap.get("cores_calca", ["#3d405b"]), "#3d405b"),
		"cabelo": _aleatorio(ap.get("cores_cabelo", ["#2b1b17"]), "#2b1b17"),
		"estilo_cabelo": _aleatorio(ap.get("estilos_cabelo", ["curto"]), "curto"),
		"chapeu": _aleatorio(ap.get("chapeus", ["nenhum"]), "nenhum"),
		"acessorio": _aleatorio(ap.get("acessorios", ["nenhum"]), "nenhum"),
		"sapato": _aleatorio(ap.get("cores_sapato", ["#2b2d42"]), "#2b2d42"),
		"genero": genero,
	}


func _garantir_animais() -> void:
	var total := 0
	var animais := 0
	var humanos: Array = []
	for p in pessoas:
		if str(p.tipo) == "jogador":
			continue
		total += 1
		if bool(p.get("animal", false)):
			animais += 1
		elif str(p.tipo) in ["funcionario_sala", "guiche", "recepcao", "acs"]:
			humanos.append(p)
	while animais < ANIMAIS_MIN and not humanos.is_empty():
		var p: Dictionary = humanos.pop_back()
		var ap: Dictionary = dnpcs.get("aparencia", {})
		p.especie = _aleatorio(ap.get("especies_animais", ["capivara"]), "capivara")
		p.animal = true
		p.pele = _aleatorio(ap.get("pelos_animais", ["#c9a27e"]), "#c9a27e")
		animais += 1


func _deve_ser_animal() -> bool:
	var total := 0
	var animais := 0
	for p in pessoas:
		if str(p.tipo) == "jogador":
			continue
		total += 1
		if bool(p.get("animal", false)):
			animais += 1
	if total >= 5 and float(animais) / float(total) < 0.30:
		return true
	return ri.randf() < CHANCE_ANIMAL


func _criar_funcionario(d: Dictionary, tipo: String, sala) -> Dictionary:
	var p := _criar_pessoa(str(d.get("id", tipo + str(proximo_id))), tipo, str(d.get("nome", "Funcionário")), d)
	p.cargo_key = str(d.get("cargo_key", sala.tipo if sala != null else tipo))
	if sala != null:
		p.sala = sala.id
		p.cargo = sala.nome
	elif tipo == "guiche":
		p.cargo = "Guichê"
	elif tipo == "recepcao":
		p.cargo = "Recepção"
	elif tipo == "acs":
		p.cargo = "ACS"
	p.energia = ri.randf_range(NPC_E_MIN, NPC_E_MAX_INI)
	p.max_energia = NPC_E_MAX
	p.em_esforco = false
	p.aura_chefe = false
	return p


func _criar_pessoa(id: String, tipo: String, nome: String, d: Dictionary) -> Dictionary:
	var ap: Dictionary = dnpcs.get("aparencia", {})
	var pele := str(d.get("pele", ap.get("tons_pele", ["#D69F7E"])[ri.randi_range(0, 9)]))
	var p := {
		"id": id, "tipo": tipo, "nome": nome, "cargo": str(d.get("cargo", "")),
		"pele": pele, "roupa": str(d.get("roupa", "#8a8a8a")),
		"roupa2": str(d.get("roupa2", "#eeeeee")), "calca": str(d.get("calca", "#3d405b")),
		"cabelo": str(d.get("cabelo", "#2b1b17")), "estilo_cabelo": str(d.get("estilo_cabelo", "curto")),
		"chapeu": str(d.get("chapeu", "nenhum")), "acessorio": str(d.get("acessorio", "nenhum")),
		"genero": str(d.get("genero", "feminino")), "sapato": str(d.get("sapato", "#2b2d42")),
		"especie": str(d.get("especie", "humano")), "animal": bool(d.get("animal", str(d.get("especie", "humano")) != "humano")),
		"pos": _vet(entrada.get("spawn", [1320, 2])), "destino": _vet(entrada.get("spawn", [1320, 2])),
		"caminho": [], "andando": false, "sentado": false, "facing": 1, "walk_phase": 0.0, "anim_t": 0.0,
		"visivel": true, "oculto": false, "fase": "ocioso", "acao_chegada": {},
		"energia": E_MAX, "max_energia": E_MAX, "em_esforco": false, "aura_chefe": false,
		"sala": "", "cargo_key": "", "posto": Vector2.ZERO, "posto_tipo": "livre", "spot_index": 0,
		"no_pc": "", "pc_alvo": "", "servindo": "", "atendimento_restante": 0.0, "paciente_atual": "",
		"funcionario_atendendo": "", "prox_reclamacao": 0.0, "escala": 1.0,
		"demanda": null, "cooldown_demanda": 0.0, "balao_tipo": "", "balao_ate": 0.0,
		"papo": null, "prox_papo": 0.0, "ultimo_papo": "",
		"prox_passeio": 0.0, "passeio_ate": 0.0, "visita_ate": 0.0, "visita_sala": "", "externo_ate": 0.0,
		"entrada_em": 0.0, "entrou": false, "cadeira": -1, "em_pe": -1, "adulto_id": "", "criancas": [],
		"tolerancia_total": 0.0, "tolerancia_fila": 0.0, "tempo_no_postinho": 0.0, "tempo_espera": 0.0,
		"limite_fila": 99, "raiva": 0.0, "quer_reclamar": false, "reclamou": false, "retorno_fase": "",
		"servicos": [], "servico_index": 0, "admitido": false, "precisa_recepcao": false,
		"destino_tipo": "", "sala_destino": "", "fila_indice": -1, "ordem": 0,
		"estacao_recepcao": "", "funcionario_recepcao": "", "spot_sala": -1,
		"alvo_abordagem": "", "abordagem_ate": 0.0, "avisos": {},
	}
	p.nome = str(d.get("nome", nome))
	p.cargo = str(d.get("cargo", p.cargo))
	entidades[id] = p
	pessoas.append(p)
	return p


func _preparar_entradas() -> void:
	for p in pessoas:
		p.visivel = false
		p.fase = "aguardando_entrada"
		p.pos = _spawn_entrada(p)
		p.destino = p.pos
		p.caminho.clear()
		p.andando = false
	for p in pessoas:
		if p.tipo == "jogador":
			continue
		if p.posto_tipo == "pc" and p.no_pc == "":
			p.posto_tipo = "livre"
		p.prox_passeio = ri.randf_range(25.0, 65.0)
		p.papo = null
		p.ultimo_papo = ""
		p.balao_tipo = ""
		p.balao_ate = 0.0
		p.prox_papo = ri.randf_range(PAPO_MIN, PAPO_MAX) if _pessoa_de_papo(p) else 0.0
	jogador().pos = _spawn_entrada(jogador())
	pos = jogador().pos


func _spawn_entrada(p: Dictionary) -> Vector2:
	var base := _vet(entrada.get("spawn", [1462, 4]))
	var n := float(abs(hash(p.id)) % 7) - 3.0
	return base + Vector2(n * 9.0, n * 3.0)
# =================================================================== computadores

func _sortear_modo_pcs(primeiro: bool = false) -> void:
	var d: Dictionary = cfg.get("computadores", {}).get("distribuicao", {})
	var chaves := ["um_interno", "uma_recepcao", "um_de_cada", "nenhum"]
	var pesos: Array = []
	for k in chaves:
		pesos.append(_num(d, k, 25.0))
	var escolhido = _escolher_por_peso(chaves, pesos)
	if primeiro or modo_pcs == "":
		modo_pcs = str(escolhido)
	else:
		modo_pcs = str(escolhido)
	_aplicar_modo_pcs(primeiro)


func _contar_livres_por_tipo(tipo: String) -> int:
	var n := 0
	for pc in pcs:
		if pc.tipo == tipo and pc.ocupante == "" and not pc.jogador and pc.problema != "grave":
			n += 1
	return n


func _aplicar_modo_pcs(primeiro: bool = false) -> void:
	var livres_int := 0
	var livres_rec := 0
	match modo_pcs:
		"um_interno":
			livres_int = 1
		"uma_recepcao":
			livres_rec = 1
		"um_de_cada":
			livres_int = 1
			livres_rec = 1
		_:
			pass
	var pcs_int: Array = []
	var pcs_rec: Array = []
	for pc in pcs:
		if pc.tipo == "interno":
			pcs_int.append(pc)
		elif pc.tipo == "recepcao":
			pcs_rec.append(pc)
	var jog_int := 0
	var jog_rec := 0
	if estado == Estado.NO_PC and foco != null:
		if foco.tipo == "interno":
			jog_int = 1
		elif foco.tipo == "recepcao":
			jog_rec = 1
	var alvo_int: int = maxi(0, pcs_int.size() - livres_int - jog_int)
	var alvo_rec: int = maxi(0, pcs_rec.size() - livres_rec - jog_rec)
	var recep: Array = []
	var acs: Array = []
	for p in pessoas:
		if p.tipo == "recepcao":
			recep.append(p)
		elif p.tipo == "acs":
			acs.append(p)
	_reorganizar_coluna(pcs_int, acs, alvo_int, "interno", primeiro)
	_reorganizar_coluna(pcs_rec, recep, alvo_rec, "recepcao", primeiro)


func _reorganizar_coluna(lista_pcs: Array, funcionarios: Array, alvo: int, tipo: String, primeiro: bool) -> void:
	# Mantem quem ja esta sentado para evitar gente levantando toda hora.
	var ocupados: Array = []
	for pc in lista_pcs:
		if pc.jogador:
			continue
		if pc.ocupante != "":
			var p = _pessoa(str(pc.ocupante))
			if p != null and p.tipo in (["recepcao"] if tipo == "recepcao" else ["acs"]) and not p.oculto:
				ocupados.append({"pc": pc, "p": p})
				continue
		pc.ocupante = ""
		pc.atendimento_id = ""
	var manter: Array = ocupados.duplicate()
	while manter.size() > alvo:
		var item = manter.pop_back()
		item.pc.ocupante = ""
		item.p.no_pc = ""
	var ja: Dictionary = {}
	for item in manter:
		ja[item.p.id] = true
	var candidatos: Array = []
	for p in funcionarios:
		if p.oculto or p.fase == "externo":
			continue
		if not ja.has(p.id):
			candidatos.append(p)
	_embaralhar(candidatos)
	for pc in lista_pcs:
		if manter.size() >= alvo:
			break
		if pc.jogador or pc.ocupante != "" or pc.problema == "grave":
			continue
		if candidatos.is_empty():
			break
		var p = candidatos.pop_back()
		pc.ocupante = p.id
		p.no_pc = pc.id
		p.posto = pc.assento
		p.posto_tipo = "pc"
		manter.append({"pc": pc, "p": p})
	for item in manter:
		item.p.no_pc = item.pc.id
		item.p.posto = item.pc.assento
		item.p.posto_tipo = "pc"
	for p in funcionarios:
		if p.no_pc == "" and p.tipo in (["recepcao"] if tipo == "recepcao" else ["acs"]):
			p.posto_tipo = "livre"
			if not p.oculto and p.fase not in ["externo", "aguardando_entrada", "na_copa", "esperando_copa", "passeando"]:
				if p.fase in ["trabalhando", "no_posto", "ocioso"] and p.andando == false:
					_ir_para_posto_livre(p)
	# Atualiza posicoes de quem esta no posto.
	for item in manter:
		var p = item.p
		if p.oculto or p.fase in ["aguardando_entrada", "externo", "na_copa", "esperando_copa", "passeando"]:
			continue
		if p.pos.distance_to(item.pc.assento) > 8.0 and not p.andando:
			p.fase = "indo_posto"
			_mover_para(p, item.pc.assento, {"tipo": "posto"})


func _ir_para_posto_livre(p: Dictionary) -> void:
	var vaga := _vaga_em_pe(p)
	if vaga >= 0:
		p.em_pe = vaga
		p.fase = "indo_posto"
		_mover_para(p, espacos_em_pe[vaga], {"tipo": "posto_livre"})


func _vaga_em_pe(p: Dictionary) -> int:
	var i := 0
	while i < espacos_em_pe.size():
		var ocupado := false
		for q in pessoas:
			if q != p and q.em_pe == i and q.visivel and q.fase not in ["saindo", "externo", "aguardando_entrada"]:
				ocupado = true
				break
		if not ocupado:
			return i
		i += 1
	return -1


# =================================================================== passo

func step(dt: float) -> void:
	if dt <= 0.0:
		return
	var n := int(floor(dt / PASSO + 0.000001))
	var i := 0
	while i < n:
		_tick(PASSO)
		i += 1
	var resto: float = dt - float(n) * PASSO
	if resto > 0.00001:
		_tick(resto)


func _tick(dt: float) -> void:
	tempo += dt
	_atualizar_entradas()
	for p in pessoas:
		_atualizar_movimento(p, dt)
	_atualizar_esforco()
	_atualizar_jogador(dt)
	_atualizar_funcionarios(dt)
	_atualizar_pacientes(dt)
	_atualizar_criancas(dt)
	_atualizar_guiche(dt)
	_atualizar_recepcao(dt)
	_atualizar_salas(dt)
	_atualizar_abordagens(dt)
	_atualizar_demandas(dt)
	_atualizar_raiva(dt)
	_atualizar_computadores(dt)
	_atualizar_impressora(dt)
	_atualizar_papos(dt)
	_atualizar_baloes(dt)
	var k := alertas.size() - 1
	while k >= 0:
		alertas[k].t -= dt
		if alertas[k].t <= 0.0:
			alertas.remove_at(k)
		k -= 1


func _atualizar_entradas() -> void:
	for p in pessoas:
		if p.fase != "aguardando_entrada":
			continue
		if tempo < p.entrada_em:
			continue
		p.visivel = true
		p.oculto = false
		p.entrou = true
		p.pos = _spawn_entrada(p)
		p.fase = "entrando"
		som("porta")
		if p.tipo == "jogador":
			estado = Estado.CAMINHANDO
			acao_pendente = {"tipo": "chegada_livre"}
			_mover_para(p, jogador_inicio, {"tipo": "jogador_inicio"})
		elif p.tipo == "crianca":
			var adulto = _pessoa(str(p.adulto_id))
			p.fase = "seguindo"
			if adulto != null:
				_mover_para(p, adulto.pos + Vector2(ri.randf_range(-20, 20), 20), {}, true)
		elif p.tipo == "paciente":
			p.fase = "entrando"
			_mover_para(p, _vet(entrada.get("dentro", [1462, 92])), {"tipo": "entrar_paciente"})
		else:
			if p.tipo == "acs" and p.posto_tipo == "livre" and ri.randf() < 0.45:
				p.fase = "indo_externo"
				_mover_para(p, _ponto_saida(), {"tipo": "externo"})
			else:
				if p.posto == Vector2.ZERO:
					var vaga := _vaga_em_pe(p)
					if vaga >= 0:
						p.em_pe = vaga
						p.posto = espacos_em_pe[vaga]
						p.posto_tipo = "livre"
				_mover_para(p, p.posto, {"tipo": "posto"})


# =================================================================== movimento

func _mover_para(p: Dictionary, destino: Vector2, acao: Dictionary = {}, forcar: bool = false) -> void:
	if not forcar and p.destino.distance_to(destino) < 10.0 and not p.caminho.is_empty() and p.acao_chegada == acao:
		return
	p.destino = destino
	p.acao_chegada = acao
	p.caminho = nav.caminho(p.pos, destino)
	p.andando = true
	p.sentado = false
	p.facing = 1 if destino.x >= p.pos.x else -1
	if p.caminho.is_empty():
		p.andando = false
		_executar_chegada(p)


func _velocidade_de(p: Dictionary) -> float:
	var base := VEL_FUNC
	if p.tipo == "jogador":
		base = VEL_JOG
	elif p.tipo == "crianca":
		base = VEL_CRIANCA
	elif p.tipo == "paciente":
		base = VEL_FUNC * 0.94
	var fator := 1.0
	if p.tipo in ["funcionario_sala", "guiche", "recepcao", "acs", "jogador"]:
		var ratio: float = clampf(float(p.energia) / maxf(0.001, float(p.max_energia)), 0.0, 1.0)
		fator = FATOR_ENERGIA_MIN + (1.0 - FATOR_ENERGIA_MIN) * ratio
	if p.em_esforco:
		fator *= 1.0 + ESP_VEL
	return base * fator


func _atualizar_movimento(p: Dictionary, dt: float) -> void:
	if not p.visivel or p.oculto:
		return
	p.anim_t += dt
	if p.caminho.is_empty():
		if p.andando:
			p.andando = false
			_executar_chegada(p)
		return
	if p.sentado:
		p.sentado = false
	var orcamento: float = _velocidade_de(p) * dt
	var movido := 0.0
	while orcamento > 0.0 and not p.caminho.is_empty():
		var alvo: Vector2 = p.caminho[0]
		var d: float = p.pos.distance_to(alvo)
		if d <= RAIO_CHEGADA or d <= orcamento:
			p.pos = alvo
			movido += d
			orcamento -= d
			p.caminho.pop_front()
		else:
			var dir: Vector2 = (alvo - p.pos).normalized()
			p.pos += dir * orcamento
			movido += orcamento
			if absf(dir.x) > 0.08:
				p.facing = 1 if dir.x > 0.0 else -1
			orcamento = 0.0
		if p.tipo == "jogador":
			pos = p.pos
	if movido > 0.0:
		p.walk_phase += movido * 0.16
		p.andando = true
		if p.tipo == "jogador":
			pos = p.pos
	if p.caminho.is_empty():
		p.andando = false
		_executar_chegada(p)


func _executar_chegada(p: Dictionary) -> void:
	var acao: Dictionary = p.acao_chegada
	p.acao_chegada = {}
	var tipo := str(acao.get("tipo", ""))
	match tipo:
		"posto":
			_assumir_posto(p)
		"posto_livre":
			p.fase = "ocioso"
			p.sentado = false
		"jogador_inicio", "chegada_livre":
			if p.tipo == "jogador":
				estado = Estado.LIVRE
				pos = p.pos
		"pc":
			if p.tipo == "jogador":
				_assumir_pc_jogador(str(acao.get("id", "")))
		"copa":
			if p.tipo == "jogador":
				estado = Estado.NA_COPA
				cafe_modo = ModoCafe.ESPERANDO
				pos = p.pos
			else:
				_npc_na_copa(p)
		"copa_auto":
			if p.tipo == "jogador":
				estado = Estado.NA_COPA
				cafe_modo = ModoCafe.TOMANDO
				cafe_timer = CAFE_TEMPO
				pos = p.pos
		"fila_guiche":
			_ao_chegar_fila_guiche(p)
		"guiche_atendimento":
			_ao_chegar_guiche(p)
		"recepcao":
			_ao_chegar_recepcao(p)
		"sala":
			_ao_chegar_sala(p)
		"sala_visita":
			_ao_chegar_visita(p)
		"atender_sala", "auxiliar_sala":
			_ao_chegar_atender(p, acao)
		"entrar_paciente":
			_entrar_fila_guiche(p)
		"cadeira":
			_ao_chegar_cadeira(p)
		"em_pe":
			_ao_chegar_em_pe(p)
		"passeio":
			_ao_chegar_passeio(p)
		"voltar_posto":
			_assumir_posto(p)
		"reclamar":
			_ao_chegar_reclamar(p)
		"abordar":
			_ao_chegar_abordagem(p)
		"abordar_jogador":
			_ao_chegar_abordagem_jogador(p)
		"externo":
			_ao_chegar_externo(p)
		"sair":
			_ao_chegar_saida(p)
		"expulsar_sala":
			_sair_do_pc()
			p.fase = "ocioso"
		_:
			pass


func _assumir_posto(p: Dictionary) -> void:
	p.andando = false
	if p.posto_tipo == "pc" and p.no_pc != "":
		var pc = pcs_por_id.get(p.no_pc)
		if pc != null and not pc.jogador:
			pc.ocupante = p.id
			p.sentado = true
			p.fase = "trabalhando"
			p.facing = 1
			return
	if p.posto_tipo == "sala":
		p.sentado = true
		p.facing = 1
		p.fase = "no_posto"
		return
	if p.posto_tipo == "guiche":
		p.sentado = false
		p.fase = "no_posto"
		p.facing = 1
		return
	p.sentado = false
	p.fase = "ocioso"


func _atualizar_esforco() -> void:
	var chefe = entidades.get("chefe", null)
	var chefe_ok: bool = chefe != null and chefe.visivel and not chefe.oculto
	for p in pessoas:
		if p.tipo == "crianca" or p.tipo == "paciente":
			continue
		p.aura_chefe = false
		if chefe_ok and p != chefe:
			var mesma_sala: bool = p.sala != "" and p.sala == "A" and _dentro_da_sala(p, _sala_por_id("A"))
			if p.pos.distance_to(chefe.pos) <= AURA_RAIO or mesma_sala:
				p.aura_chefe = true
		if p.tipo == "jogador":
			p.em_esforco = p.aura_chefe or esforco_manual
		else:
			p.em_esforco = p.aura_chefe


func _dentro_da_sala(p: Dictionary, sala) -> bool:
	if sala == null:
		return false
	var r: Rect2 = Rect2(sala.x, sala.y, sala.w, sala.h)
	return r.has_point(p.pos)
# =================================================================== jogador

func _atualizar_jogador(dt: float) -> void:
	var p := jogador()
	p.pos = pos
	if atendendo_paciente != "":
		atendimento_timer -= dt
		if atendimento_timer <= 0.0:
			var pac = _pessoa(atendendo_paciente)
			if foco != null:
				foco.atendimento_id = ""
			if pac != null and pac.fase not in ["saindo", "saiu"]:
				pac.atendimento_restante = 0.0
				var ratio := energia / maxf(0.001, E_MAX)
				pac.raiva = clampf(pac.raiva + (RAIVA_BOM if ratio > 0.5 else RAIVA_RUIM * 0.8), 0.0, 100.0)
				pac.fase = "saindo_recepcao"
				pac.funcionario_recepcao = "jogador"
				_proximo_servico(pac)
			inc("atendidos_recepcao")
			energia = maxf(0.0, energia - 0.08)
			som("atendimento")
			alerta("Atendimento concluído. Você pode voltar ao trabalho.", 2.5)
			atendendo_paciente = ""
			atendimento_timer = 0.0
	if estado == Estado.NO_PC and foco != null:
		var pc = pcs_por_id.get(foco.id, null)
		if pc != null and pc.problema == "grave":
			alerta(_txt("avisos", "pc_quebrado", "Este computador está com problema grave."), 2.5)
			_sair_do_pc()
		elif modal != null or atendendo_paciente != "":
			pass
		elif tarefas > 0 and energia > EPS:
			var mult := 1.0 + ESP_VEL if esforco_manual or p.aura_chefe else 1.0
			var lento := 1.0
			if pc != null and pc.problema == "leve":
				lento = PC_PROBLEMA_LEVE
			if _penalidade_abordagem():
				lento *= 0.5
			var ritmo: float = RENDIMENTO * mult * lento
			var gasto: float = CUSTO_TAREFA * ritmo * (ESP_GASTO if (esforco_manual or p.aura_chefe) else 1.0)
			var passo: float = minf(dt, (1.0 - prog) / maxf(ritmo, 0.0001))
			prog += ritmo * passo
			energia = maxf(0.0, energia - gasto * passo)
			if prog >= 1.0 - 0.000001:
				prog = 0.0
				tarefas = maxi(0, tarefas - 1)
				inc("tarefas_concluidas")
				som("tarefa")
				if tarefas == 0:
					alerta(_txt("avisos", "sem_trabalhos", "Nenhum trabalho pendente."), 2.0)
			if energia <= EPS:
				_ir_para_copa(true)
		if estado == Estado.NO_PC and esforco_manual and energia < ESP_ENERGIA_MIN:
			esforco_manual = false
	elif estado == Estado.NA_COPA:
		if cafe_modo == ModoCafe.TOMANDO:
			cafe_timer -= dt
			if cafe_timer <= 0.00001:
				energia = minf(E_MAX, energia + CAFE_GANHO)
				inc("cafes")
				som("cafe")
				if energia < E_MAX - EPS:
					if cafe_modo == ModoCafe.TOMANDO:
						cafe_timer = CAFE_TEMPO
				else:
					cafe_modo = ModoCafe.ESPERANDO
					alerta(_txt("avisos", "cafe_cheio", "A energia já está cheia."), 2.0)
		elif cafe_modo == ModoCafe.ESPERANDO_VAGA:
			if _copa_tem_vaga():
				var spot := _ponto_copa_livre()
				estado = Estado.CAMINHANDO
				cafe_modo = ModoCafe.NENHUM
				_mover_para(p, spot, {"tipo": "copa_auto"})
	p.energia = energia
	p.em_esforco = esforco_manual or p.aura_chefe
	pos = p.pos


func _penalidade_abordagem() -> bool:
	if estado != Estado.NO_PC or foco == null or foco.tipo != "interno":
		return false
	for p in pessoas:
		if p.fase in ["indo_abordar_jogador", "abordando_jogador"] and p.demanda != null:
			return true
	return false


func _assumir_pc_jogador(id: String) -> void:
	var pc = pcs_por_id.get(id, null)
	if pc == null:
		estado = Estado.LIVRE
		return
	if not _pc_disponivel_jogador(pc):
		alerta(_txt("avisos", "pc_ocupado", "Este computador está ocupado."), 2.0)
		estado = Estado.LIVRE
		return
	estado = Estado.NO_PC
	foco = pc
	pc.jogador = true
	pc.ocupante = ""
	pc.atendimento_id = ""
	acao_pendente = {}
	var p := jogador()
	p.pos = pc.assento
	p.sentado = true
	p.facing = 1
	pos = pc.assento
	inc("computadores_usados")
	if tarefas <= 0:
		alerta(_txt("avisos", "sem_trabalhos", "Nenhum trabalho pendente."), 2.3)
	elif tarefas >= TAREFAS_MAX:
		alerta("Trabalhe para reduzir seus %d trabalhos pendentes." % tarefas, 2.5)


func _pc_disponivel_jogador(pc: Dictionary) -> bool:
	if pc.ocupante != "" and not pc.jogador:
		return false
	if pc.problema == "grave":
		return false
	if pc.tipo == "sala":
		var sala = _sala_por_id(pc.sala)
		if sala == null or sala.tipo == "chefe":
			return false
		if not _sala_vazia_para_jogador(pc.sala):
			return false
	return true


func _sair_do_pc() -> void:
	if atendendo_paciente != "":
		var pac = _pessoa(atendendo_paciente)
		if pac != null and pac.fase not in ["saindo", "saiu"]:
			pac.fase = "sentado"
			pac.atendimento_restante = 0.0
			if not fila_recepcao.has(pac.id):
				fila_recepcao.append(pac.id)
			_ir_esperar(pac)
		atendendo_paciente = ""
		atendimento_timer = 0.0
	if foco != null:
		foco.jogador = false
		foco.atendimento_id = ""
		foco = null
	esforco_manual = false
	if estado == Estado.NO_PC or estado == Estado.CONVERSANDO:
		estado = Estado.LIVRE
	var p := jogador()
	p.sentado = false
	p.no_pc = ""


func _expulsar_jogador_sala(id_sala: String) -> void:
	if estado == Estado.NO_PC and foco != null and foco.tipo == "sala" and foco.sala == id_sala:
		alerta(_txt("avisos", "expulso_sala", "O profissional precisa da sala."), 3.0)
		_sair_do_pc()
		var p := jogador()
		var sala = _sala_por_id(id_sala)
		var alvo := Vector2(sala.x + sala.w + 40, sala.y + sala.h * 0.5)
		_mover_para(p, alvo, {"tipo": "chegada_livre"})
		estado = Estado.CAMINHANDO


func _ir_para_copa(automatico: bool = false) -> void:
	if _copa_tem_vaga():
		_sair_do_pc()
		var target := _ponto_copa_livre()
		estado = Estado.CAMINHANDO
		cafe_modo = ModoCafe.NENHUM
		_mover_para(jogador(), target, {"tipo": "copa_auto" if automatico else "copa"})
		if automatico:
			alerta(_txt("avisos", "sem_energia", "Energia zerada. Indo à copa."), 3.0)
			inc("idas_a_copa_sem_energia")
	else:
		if automatico:
			_sair_do_pc()
			var espera := _ponto_espera_copa()
			estado = Estado.CAMINHANDO
			cafe_modo = ModoCafe.ESPERANDO_VAGA
			_mover_para(jogador(), espera, {"tipo": "esperar_copa"})
			alerta("A copa está cheia. Aguardando uma vaga.", 2.5)
		else:
			alerta(_txt("avisos", "sala_cheia", "A copa está cheia."), 2.0)


func _iniciar_cafe() -> void:
	if estado != Estado.NA_COPA:
		return
	if energia >= E_MAX - EPS:
		alerta(_txt("avisos", "cafe_cheio", "A energia já está cheia."), 2.0)
		return
	if cafe_modo == ModoCafe.TOMANDO:
		return
	cafe_modo = ModoCafe.TOMANDO
	cafe_timer = CAFE_TEMPO
	alerta(_txt("avisos", "cafe_iniciado", "Tomando café..."), 1.2)


func _copa_tem_vaga() -> bool:
	var sala = _sala_por_id("E")
	if sala == null:
		return true
	var n := 0
	for p in pessoas:
		if p.tipo == "crianca" or p.tipo == "jogador":
			continue
		if p.visivel and _dentro_da_sala(p, sala):
			n += 1
	return n < 5


func _ponto_copa_livre() -> Vector2:
	for spot in copa_spots:
		var livre := true
		for p in pessoas:
			if p.visivel and p.tipo != "jogador" and p.pos.distance_to(spot) < 24.0:
				livre = false
				break
		if livre:
			return spot
	return copa_spots[ri.randi_range(0, copa_spots.size() - 1)]


func _ponto_espera_copa() -> Vector2:
	var sala = _sala_por_id("E")
	if sala == null:
		return Vector2.ZERO
	return Vector2(sala.x + sala.w + 35, sala.y + sala.h * 0.5)


func _ponto_saida() -> Vector2:
	return _vet(entrada.get("spawn", [1462, 4])) + Vector2(0, 8)


# =================================================================== cliques

func clicar_pc(id: String) -> void:
	if modal != null:
		return
	var pc = pcs_por_id.get(id, null)
	if pc == null:
		return
	if estado == Estado.NO_PC and foco == pc:
		return
	if pc.tipo == "sala" and pc.sala == "A":
		alerta(_txt("avisos", "sala_chefe_fechada", "O computador da chefe é de uso exclusivo dela."), 2.5)
		return
	if pc.problema != "":
		if pc.ocupante != "" or pc.jogador:
			alerta("Este computador está em uso. Conserte quando estiver livre.", 2.5)
			return
		if estado == Estado.NO_PC:
			_sair_do_pc()
			estado = Estado.LIVRE
		_abrir_reparo("pc", id)
		return
	if not _pc_disponivel_jogador(pc):
		if pc.tipo == "sala" and not _sala_vazia_para_jogador(pc.sala):
			alerta(_txt("avisos", "sala_ocupada", "A sala está ocupada agora."), 2.2)
		elif pc.problema == "grave":
			alerta(_txt("avisos", "pc_quebrado", "Este computador está com problema grave."), 2.2)
		else:
			alerta(_txt("avisos", "pc_ocupado", "Este computador está ocupado."), 2.2)
		return
	if atendendo_paciente != "":
		alerta("Termine o atendimento do paciente primeiro.", 2.2)
		return
	_sair_do_pc()
	var p := jogador()
	estado = Estado.CAMINHANDO
	acao_pendente = {"tipo": "pc", "id": id}
	_mover_para(p, pc.assento, {"tipo": "pc", "id": id})


func clicar_pessoa(id: String) -> void:
	if modal != null:
		return
	if id == "jogador":
		clique_jogador()
		return
	var p = _pessoa(id)
	if p == null or not p.visivel or p.oculto:
		return
	if p.tipo == "crianca":
		alerta(_txt("avisos", "crianca", "As crianças precisam ficar perto do adulto."), 2.0)
		_forcar_balao(p, "coracao", 2.0)
		return
	if p.demanda != null:
		if tarefas >= TAREFAS_MAX:
			alerta(_txt("dialogo", "limite_trabalhos", "Você já tem 10 trabalhos pendentes."), 3.2)
			_forcar_balao(p, "exclamacao", 2.0)
			return
		abrir_dialogo(p)
		return
	if p.papo != null:
		abrir_papo(p)
		return
	_forcar_balao(p, _balao_para(p), 2.4)


func clique_jogador() -> void:
	if estado == Estado.NO_PC and foco != null:
		if energia <= EPS:
			_ir_para_copa(true)
			return
		if energia < ESP_ENERGIA_MIN:
			alerta("Energia baixa demais para se esforçar.", 2.0)
			return
		esforco_manual = not esforco_manual
		inc("esforcos")
		_forcar_balao(jogador(), "raiva" if esforco_manual else "coracao", 1.4)
		return
	if estado == Estado.NA_COPA:
		_iniciar_cafe()
		return
	_forcar_balao(jogador(), "duvida", 1.5)


func clicar_copa() -> void:
	if modal != null:
		return
	if estado == Estado.NA_COPA:
		_iniciar_cafe()
		return
	if atendendo_paciente != "":
		alerta("Termine o atendimento do paciente primeiro.", 2.2)
		return
	if not _copa_tem_vaga():
		alerta(_txt("avisos", "sala_cheia", "A copa está cheia."), 2.0)
		return
	_sair_do_pc()
	estado = Estado.CAMINHANDO
	cafe_modo = ModoCafe.NENHUM
	_mover_para(jogador(), _ponto_copa_livre(), {"tipo": "copa"})


func clicar_sala(id: String) -> void:
	if modal != null:
		return
	var sala = _sala_por_id(id)
	if sala == null:
		return
	if sala.tipo == "copa":
		clicar_copa()
		return
	if atendendo_paciente != "":
		alerta("Termine o atendimento do paciente primeiro.", 2.2)
		return
	_sair_do_pc()
	var alvo: Vector2 = Vector2(sala.x + sala.w - 48, sala.y + sala.h * 0.5)
	estado = Estado.CAMINHANDO
	_mover_para(jogador(), alvo, {"tipo": "chegada_livre"})


func clicar_chao(ponto: Vector2) -> void:
	if modal != null or atendendo_paciente != "":
		return
	if estado == Estado.NO_PC or estado == Estado.NA_COPA:
		_sair_do_pc()
	estado = Estado.CAMINHANDO
	cafe_modo = ModoCafe.NENHUM
	_mover_para(jogador(), ponto, {"tipo": "chegada_livre"})


func clicar_saida() -> void:
	alerta(_txt("avisos", "saida_futura", "O trabalho externo será introduzido em uma próxima versão."), 4.0)
	som("alerta")


func clicar_porta_lateral() -> void:
	alerta(_txt("avisos", "lateral_futura", "A outra parte do postinho ainda não está pronta."), 4.0)
	som("alerta")


# =================================================================== consertos e exames

func clicar_impressora() -> void:
	if modal != null:
		return
	if not bool(impressora.get("quebrada", false)):
		alerta("A impressora está funcionando. Ainda. Não provoque.", 2.5)
		_forcar_balao(jogador(), "sorriso", 1.5)
		return
	if estado == Estado.NO_PC:
		_sair_do_pc()
		estado = Estado.LIVRE
	_abrir_reparo("impressora", "")


func _abrir_reparo(alvo: String, id: String) -> bool:
	if modal != null:
		return false
	var nomes := ["Vermelho", "Azul", "Amarelo", "Verde", "Roxo"]
	var cores := ["#e74c3c", "#3498db", "#f1c40f", "#2ecc71", "#9b59b6"]
	var ordem: Array = [0, 1, 2, 3, 4]
	_embaralhar(ordem)
	var sequencia: Array = []
	var n: int = mini(maxi(2, IMP_FIOS), ordem.size())
	for i in n:
		sequencia.append(int(ordem[i]))
	var antes := estado
	estado = Estado.CONVERSANDO
	modal = {
		"tipo": "reparo", "alvo": alvo, "id": id, "sequencia": sequencia,
		"progresso": [], "cores": cores, "nomes": nomes, "estado_antes": antes,
		"titulo": "Conserto de emergência", "fase": "fios",
		"texto": "Ligue os fios na ordem em que as luzes acendem. Sem chutar o balcão.",
	}
	inc("reparos_iniciados")
	som("alerta")
	return true


func minijogo_escolher(indice: int) -> void:
	if modal == null or str(modal.get("tipo", "")) != "reparo":
		return
	var seq: Array = modal.get("sequencia", [])
	var prog: Array = modal.get("progresso", [])
	if prog.size() >= seq.size():
		return
	if indice == int(seq[prog.size()]):
		prog.append(indice)
		modal["progresso"] = prog
		som("tarefa")
		if prog.size() >= seq.size():
			_concluir_reparo()
	else:
		energia = maxf(0.0, energia - 0.05)
		modal["progresso"] = []
		alerta("Fio errado. A sequência recomeçou do zero.", 2.2)
		som("negar")


func _concluir_reparo() -> void:
	if modal == null:
		return
	var alvo := str(modal.get("alvo", ""))
	var id := str(modal.get("id", ""))
	var antes := int(modal.get("estado_antes", Estado.LIVRE))
	modal = null
	estado = antes if antes != Estado.CONVERSANDO else Estado.LIVRE
	if alvo == "impressora":
		impressora.quebrada = false
		impressora.estado = "ok"
		impressora.trocas = int(impressora.get("trocas", 0)) + 1
		impressora.proxima = tempo + ri.randf_range(IMP_MIN, IMP_MAX)
		inc("impressoras_consertadas")
		alerta("Impressora consertada. Ela prometeu se comportar por alguns minutos.", 3.5)
		som("aceitar")
	elif alvo == "pc":
		var pc = pcs_por_id.get(id, null)
		if pc != null:
			pc.problema = ""
			pc.problema_ate = 0.0
		inc("pcs_consertados")
		alerta("Computador consertado. Não foi o cabo, mas quase sempre é.", 3.2)
		som("aceitar")


func abrir_exame(d: Dictionary = {}) -> bool:
	if modal != null:
		return false
	var n: int = maxi(12, EXAME_PASTAS)
	var paleta := ["#c98a5b", "#b96a4b", "#d9a15f", "#a96b52", "#c47a63", "#d7b27a", "#8f5b45", "#bf8d68"]
	var pastas: Array = []
	for i in n:
		pastas.append({
			"cor": paleta[i % paleta.size()],
			"sinal": str(["", "", "ponto", "linha", "estrela"][ri.randi_range(0, 4)]),
			"girada": ri.randf_range(-0.05, 0.05),
			"alvo": false,
		})
	var alvo := ri.randi_range(0, n - 1)
	pastas[alvo]["alvo"] = true
	pastas[alvo]["sinal"] = "cruz"
	pastas[alvo]["cor"] = "#f4e7c8"
	exame_busca = {"ativo": true, "alvo": alvo, "pastas": pastas, "tentativas": 0}
	var antes := estado
	estado = Estado.CONVERSANDO
	modal = {
		"tipo": "exame", "alvo": alvo, "pastas": pastas, "exame": exame_busca,
		"estado_antes": antes, "fase": "busca", "alvo_id": "",
		"titulo": "Arquivo de exames", "opcoes": [],
		"texto": "A pasta da dona Zulmira tem uma cruz verde na etiqueta. Ache entre as pastas do arquivo.",
		"fonte": str(d.get("texto", "")),
	}
	inc("exames_iniciados")
	som("papo")
	return true


func exame_escolher(i: int) -> void:
	if modal == null or str(modal.get("tipo", "")) != "exame":
		return
	var alvo := int(modal.get("alvo", -1))
	modal["tentativas"] = int(modal.get("tentativas", 0)) + 1
	if i == alvo:
		var antes := int(modal.get("estado_antes", Estado.LIVRE))
		modal = null
		estado = antes if antes != Estado.CONVERSANDO else Estado.LIVRE
		exame_busca["ativo"] = false
		tarefas = maxi(0, tarefas - 1)
		inc("tarefas_concluidas")
		inc("exames_encontrados")
		alerta("Pasta encontrada! O exame estava entre duas receitas de bolo.", 3.5)
		som("tarefa")
	else:
		energia = maxf(0.0, energia - EXAME_ERRO)
		inc("exames_erros")
		alerta("Essa pasta é de outro paciente. Olhe a etiqueta com calma.", 2.0)
		som("negar")


func _atualizar_impressora(dt: float) -> void:
	if impressora.is_empty():
		return
	if bool(impressora.get("quebrada", false)):
		return
	impressora.proxima = float(impressora.get("proxima", 0.0)) - dt
	if float(impressora.proxima) <= 0.0:
		impressora.proxima = tempo + ri.randf_range(IMP_MIN, IMP_MAX)
		if ri.randf() < IMP_CHANCE:
			impressora.quebrada = true
			impressora.estado = "quebrada"
			inc("impressoras_quebradas")
			alerta("A impressora travou de novo. Ela tem opinião própria.", 3.5)
			som("alerta")


# =================================================================== sessão

func tem_sessao() -> bool:
	return FileAccess.file_exists(caminho_sessao)


func info_sessao() -> Dictionary:
	if not tem_sessao():
		return {}
	var f := FileAccess.open(caminho_sessao, FileAccess.READ)
	if f == null:
		return {}
	var dados = f.get_var()
	if not (dados is Dictionary):
		return {}
	var pessoas_salvas: Array = dados.get("pessoas", [])
	var quando := float(dados.get("salvo_em", 0.0))
	return {
		"versao": int(dados.get("versao", 0)),
		"tempo": float(dados.get("tempo", 0.0)),
		"energia": float(dados.get("energia", 0.0)),
		"tarefas": int(dados.get("tarefas", 0)),
		"pessoas": pessoas_salvas.size(),
		"salvo_em": quando,
	}


func salvar_sessao() -> bool:
	ultimo_erro_sessao = ""
	if pessoas.is_empty() or not entidades.has("jogador"):
		ultimo_erro_sessao = "Nada para salvar."
		return false
	var dados := {
		"versao": SESSAO_VERSAO,
		"salvo_em": Time.get_unix_time_from_system(),
		"tempo": tempo, "energia": energia, "tarefas": tarefas, "prog": prog,
		"esforco_manual": esforco_manual, "estado": estado, "pos": pos,
		"cafe_modo": cafe_modo, "cafe_timer": cafe_timer,
		"acao_pendente": acao_pendente, "atendendo_paciente": atendendo_paciente,
		"atendimento_timer": atendimento_timer, "aproximacao_pc": aproximacao_pc,
		"prox_demanda": prox_demanda, "prox_paciente": prox_paciente,
		"fila_guiche": fila_guiche, "guiche_atendendo": guiche_atendendo,
		"guiche_timer": guiche_timer, "fila_recepcao": fila_recepcao,
		"fila_chefe": fila_chefe, "agenda_pcs": agenda_pcs,
		"agenda_problema": agenda_problema, "modo_pcs": modo_pcs,
		"contadores": contadores, "pessoas": pessoas, "pcs": pcs,
		"cadeiras": cadeiras, "salas": salas, "espacos_em_pe": espacos_em_pe,
		"impressora": impressora, "exame_busca": exame_busca,
		"proximo_id": proximo_id, "ordem_chegada": ordem_chegada,
		"nomes_usados": nomes_usados,
		"foco_id": str(foco.id) if foco != null else "",
		"modal": modal,
	}
	var f := FileAccess.open(caminho_sessao, FileAccess.WRITE)
	if f == null:
		ultimo_erro_sessao = "Não foi possível abrir o arquivo de sessão."
		return false
	f.store_var(dados)
	f.close()
	return true


func carregar_sessao() -> bool:
	ultimo_erro_sessao = ""
	if not tem_sessao():
		ultimo_erro_sessao = "Nenhuma sessão salva."
		return false
	var f := FileAccess.open(caminho_sessao, FileAccess.READ)
	if f == null:
		ultimo_erro_sessao = "Não foi possível abrir a sessão salva."
		return false
	var dados = f.get_var()
	if not (dados is Dictionary) or int(dados.get("versao", 0)) != SESSAO_VERSAO:
		ultimo_erro_sessao = "A sessão salva é de outra versão."
		return false
	_montar_mundo()
	pessoas = dados.get("pessoas", [])
	entidades.clear()
	for p in pessoas:
		if p is Dictionary:
			entidades[str(p.get("id", ""))] = p
	if not entidades.has("jogador"):
		ultimo_erro_sessao = "A sessão salva está incompleta."
		return false
	pcs = dados.get("pcs", pcs)
	pcs_por_id.clear()
	for pc in pcs:
		pcs_por_id[str(pc.get("id", ""))] = pc
	cadeiras = dados.get("cadeiras", cadeiras)
	salas = dados.get("salas", salas)
	espacos_em_pe = dados.get("espacos_em_pe", espacos_em_pe)
	impressora = dados.get("impressora", impressora)
	exame_busca = dados.get("exame_busca", exame_busca)
	proximo_id = int(dados.get("proximo_id", proximo_id))
	ordem_chegada = int(dados.get("ordem_chegada", ordem_chegada))
	nomes_usados = dados.get("nomes_usados", nomes_usados)
	# Sessões antigas rotulavam pacientes e crianças com números; ao continuar,
	# eles recebem nomes fictícios como o resto das pessoas do posto.
	for p in pessoas:
		if not (p is Dictionary) or str(p.get("tipo", "")) not in ["paciente", "crianca"]:
			continue
		var nome_antigo := str(p.get("nome", ""))
		if nome_antigo.begins_with("Paciente ") or nome_antigo.begins_with("Criança "):
			p["nome"] = _sortear_nome(str(p.get("genero", "feminino")))
	tempo = float(dados.get("tempo", 0.0))
	energia = float(dados.get("energia", E_MAX))
	tarefas = int(dados.get("tarefas", 0))
	prog = float(dados.get("prog", 0.0))
	esforco_manual = bool(dados.get("esforco_manual", false))
	estado = int(dados.get("estado", Estado.LIVRE))
	pos = _vet(dados.get("pos", jogador().pos))
	cafe_modo = int(dados.get("cafe_modo", ModoCafe.NENHUM))
	cafe_timer = float(dados.get("cafe_timer", 0.0))
	acao_pendente = dados.get("acao_pendente", {})
	atendendo_paciente = str(dados.get("atendendo_paciente", ""))
	atendimento_timer = float(dados.get("atendimento_timer", 0.0))
	aproximacao_pc = str(dados.get("aproximacao_pc", ""))
	prox_demanda = float(dados.get("prox_demanda", 8.0))
	prox_paciente = float(dados.get("prox_paciente", 14.0))
	fila_guiche = dados.get("fila_guiche", [])
	guiche_atendendo = str(dados.get("guiche_atendendo", ""))
	guiche_timer = float(dados.get("guiche_timer", 0.0))
	fila_recepcao = dados.get("fila_recepcao", [])
	fila_chefe = dados.get("fila_chefe", [])
	agenda_pcs = float(dados.get("agenda_pcs", 0.0))
	agenda_problema = float(dados.get("agenda_problema", 0.0))
	modo_pcs = str(dados.get("modo_pcs", "ambos"))
	contadores = dados.get("contadores", {})
	foco = pcs_por_id.get(str(dados.get("foco_id", "")), null)
	if estado == Estado.NO_PC and foco == null:
		estado = Estado.LIVRE
	modal = dados.get("modal", null)
	if modal != null and not (modal is Dictionary):
		modal = null
	if modal != null and str(modal.get("tipo", "")) in ["reparo", "exame"]:
		exame_pendente = false
	_montar_navegacao()
	var pj := jogador()
	pj.pos = pos
	pj.visivel = true
	pj.oculto = false
	pj.entrou = true
	alerta("Sessão retomada. A fila não esperou, mas está quase do mesmo tamanho.", 3.5)
	return true


func apagar_sessao() -> bool:
	if not tem_sessao():
		return true
	var ok := DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho_sessao)) == OK
	if not ok:
		ultimo_erro_sessao = "Não foi possível apagar a sessão salva."
	return ok


# =================================================================== pacientes

func _aleatorio(lista: Array, padrao: String = "#ffffff") -> String:
	if lista.is_empty():
		return padrao
	return str(lista[ri.randi_range(0, lista.size() - 1)])


func _novo_paciente(entrada_em: float = -1.0) -> Dictionary:
	proximo_id += 1
	var genero := "feminino" if ri.randf() < 0.55 else "masculino"
	var d := _aparencia_pessoa(_deve_ser_animal(), genero)
	d["nome"] = _sortear_nome(genero)
	var p := _criar_pessoa("pac_%d" % proximo_id, "paciente", str(d.nome), d)
	p.pos = _spawn_entrada(p)
	p.destino = p.pos
	p.tolerancia_total = ri.randf_range(PAC_TOL_MIN, PAC_TOL_MAX) * mult_paciencia
	p.tolerancia_fila = ri.randf_range(PAC_FILA_MIN, PAC_FILA_MAX) * mult_paciencia
	p.limite_fila = ri.randi_range(PAC_LIMITE_FILA_MIN, PAC_LIMITE_FILA_MAX)
	p.raiva = ri.randf_range(0.0, 8.0)
	p.prox_papo = tempo + ri.randf_range(30.0, 85.0)
	p.adulto_id = ""
	p.ordem = ordem_chegada
	ordem_chegada += 1
	if entrada_em >= 0.0:
		p.fase = "aguardando_entrada"
		p.visivel = false
		p.entrada_em = entrada_em
	else:
		p.visivel = true
		p.fase = "entrando"
		_mover_para(p, _vet(entrada.get("dentro", [1462, 92])), {"tipo": "entrar_paciente"})
	_criar_criancas(p)
	return p


func _criar_criancas(adulto: Dictionary) -> void:
	if ri.randf() > CHANCE_CRIANCA:
		return
	var n := ri.randi_range(1, MAX_CRIANCAS_ADULTO)
	for i in n:
		proximo_id += 1
		var herda := bool(adulto.get("animal", false)) and ri.randf() < 0.62
		var genero_crianca := "feminino" if ri.randf() < 0.5 else "masculino"
		var d := _aparencia_pessoa(herda or _deve_ser_animal(), genero_crianca)
		if herda:
			d["especie"] = str(adulto.get("especie", "humano"))
			d["pele"] = str(adulto.get("pele", d["pele"]))
			d["animal"] = true
		d["nome"] = _sortear_nome(genero_crianca, _sobrenome_de(str(adulto.get("nome", ""))))
		d["acessorio"] = "nenhum"
		var c := _criar_pessoa("cri_%d" % proximo_id, "crianca", str(d.nome), d)
		c.adulto_id = adulto.id
		c.escala = 0.66
		c.pos = adulto.pos + Vector2(ri.randf_range(-18, 18), ri.randf_range(6, 22))
		c.destino = c.pos
		c.tolerancia_total = 1e9
		c.fase = "seguindo"
		c.visivel = adulto.visivel
		c.entrada_em = adulto.entrada_em
		c.oculto = adulto.oculto
		c.criancas = []
		adulto.criancas.append(c.id)


func _contar_adultos() -> int:
	var n := 0
	for p in pessoas:
		if p.tipo == "paciente" and p.fase not in ["saindo", "saiu"]:
			n += 1
	return n


func _remover_filas(p: Dictionary) -> void:
	fila_guiche.erase(p.id)
	fila_recepcao.erase(p.id)
	if guiche_atendendo == p.id:
		guiche_atendendo = ""
		guiche_timer = 0.0
	_posicionar_fila_guiche()


func _liberar_assento(p: Dictionary) -> void:
	if p.cadeira >= 0 and p.cadeira < cadeiras.size():
		cadeiras[p.cadeira].ocupante = ""
	p.cadeira = -1
	p.em_pe = -1
	p.sentado = false


func _cadeira_livre(perto: Vector2 = Vector2.ZERO) -> int:
	var melhor := -1
	var dist := 1e20
	for i in cadeiras.size():
		if cadeiras[i].ocupante != "":
			continue
		var d: float = cadeiras[i].pos.distance_squared_to(perto)
		if d < dist:
			dist = d
			melhor = i
	return melhor


func _em_pe_livre(p: Dictionary) -> int:
	var i := 0
	while i < espacos_em_pe.size():
		var ocupado := false
		for q in pessoas:
			if q != p and q.em_pe == i and q.visivel and q.fase not in ["saindo", "saiu", "externo", "aguardando_entrada"]:
				ocupado = true
				break
		if not ocupado:
			return i
		i += 1
	return -1


func _ir_esperar(p: Dictionary) -> void:
	_liberar_assento(p)
	var idx := _cadeira_livre(p.pos)
	if idx >= 0:
		cadeiras[idx].ocupante = p.id
		p.cadeira = idx
		p.fase = "indo_cadeira"
		_mover_para(p, cadeiras[idx].pos, {"tipo": "cadeira"})
		return
	idx = _em_pe_livre(p)
	if idx >= 0:
		p.em_pe = idx
		p.fase = "indo_em_pe"
		_mover_para(p, espacos_em_pe[idx], {"tipo": "em_pe"})
	else:
		p.fase = "em_pe"
		p.sentado = false


func _contar_na_sala(sala: Dictionary) -> int:
	var n := 0
	for id in sala.paciente_ocupado.keys():
		var q = _pessoa(str(id))
		if q != null and q.fase not in ["saindo", "saiu"] and q.visivel:
			n += 1
	return n


func _spot_sala_livre(sala: Dictionary) -> int:
	var usados := {}
	for id in sala.paciente_ocupado.keys():
		var q = _pessoa(str(id))
		if q != null:
			usados[int(q.spot_sala)] = true
	for i in sala.paciente_spots.size():
		if not usados.has(i):
			return i
	return -1


func _soltar_sala(p: Dictionary) -> void:
	var sala = _sala_por_id(str(p.sala_destino))
	if sala != null:
		sala.paciente_ocupado.erase(p.id)
	else:
		for s in salas:
			s.paciente_ocupado.erase(p.id)
	p.spot_sala = -1
	p.sala_destino = ""
	p.destino_tipo = ""
	p.atendimento_restante = 0.0
	p.funcionario_atendendo = ""
func _sortear_servicos(p: Dictionary) -> void:
	p.servicos.clear()
	var opcoes_base: Array = []
	var pesos_base: Array = []
	for d in DISTR_SALAS:
		opcoes_base.append({"tipo": str(d.tipo), "sala": str(d.sala)})
		pesos_base.append(float(d.peso))
	var principal = _escolher_por_peso(opcoes_base, pesos_base)
	p.servicos.append(principal.duplicate())
	if ri.randf() < CHANCE_SEGUNDO:
		var opcoes: Array = []
		var pesos: Array = []
		for d in DISTR_SALAS:
			if str(d.tipo) != "sala":
				continue
			if d.sala != principal.sala or principal.tipo == "recepcao":
				opcoes.append({"tipo": "sala", "sala": str(d.sala)})
				pesos.append(float(d.peso))
		if not opcoes.is_empty():
			p.servicos.append(_escolher_por_peso(opcoes, pesos).duplicate())
	p.servico_index = 0


func _servico_atual(p: Dictionary) -> Dictionary:
	if p.servico_index >= 0 and p.servico_index < p.servicos.size():
		return p.servicos[p.servico_index]
	return {}


func _iniciar_servico_atual(p: Dictionary) -> void:
	if p.servico_index < 0 or p.servico_index >= p.servicos.size():
		return
	if p.papo != null:
		inc("papos_interrompidos")
		_encerrar_papo(p, false)
	var s := _servico_atual(p)
	if str(s.get("tipo", "sala")) == "recepcao":
		p.destino_tipo = "recepcao"
		p.sala_destino = ""
		if not fila_recepcao.has(p.id):
			fila_recepcao.append(p.id)
		_ir_esperar(p)
	else:
		p.destino_tipo = "sala"
		p.sala_destino = str(s.get("sala", "B"))
		_ir_esperar(p)


func _proximo_servico(p: Dictionary) -> void:
	p.servico_index += 1
	_liberar_assento(p)
	if p.servico_index >= p.servicos.size():
		p.admitido = true
		p.destino_tipo = ""
		p.sala_destino = ""
		inc("pacientes_atendidos")
		_iniciar_saida(p, false)
		return
	_iniciar_servico_atual(p)


func _entrar_fila_guiche(p: Dictionary) -> void:
	if p.fase in ["saindo", "saiu"]:
		return
	if fila_guiche.size() >= p.limite_fila:
		p.raiva = maxf(p.raiva, RAIVA_ABANDONO)
		alerta("Fila do guichê cheia. Um paciente desistiu.", 3.0)
		inc("desistencias_fila")
		_iniciar_saida(p, true)
		return
	fila_guiche.append(p.id)
	p.fase = "indo_fila_guiche"
	_posicionar_fila_guiche()


func _posicionar_fila_guiche() -> void:
	var fila: Array = guiche.get("fila", [])
	var i := 0
	for id in fila_guiche:
		var p = _pessoa(str(id))
		if p == null:
			i += 1
			continue
		if i >= fila.size():
			i += 1
			continue
		if p.fase not in ["no_guiche", "saindo", "saiu", "atendimento_guiche"]:
			var alvo := _vet(fila[i])
			if p.pos.distance_to(alvo) > 6.0:
				p.fase = "indo_fila_guiche"
				_mover_para(p, alvo, {"tipo": "fila_guiche"})
			else:
				p.fase = "fila_guiche"
		i += 1


func _depois_guiche(p: Dictionary) -> void:
	inc("atendidos_guiche")
	p.admitido = true
	p.raiva = maxf(0.0, p.raiva + RAIVA_BOM * 0.5)
	_sortear_servicos(p)
	_iniciar_servico_atual(p)


func _iniciar_saida(p: Dictionary, desistiu: bool = false) -> void:
	if p.fase in ["saindo", "saiu"]:
		return
	if p.papo != null:
		_encerrar_papo(p, false)
	_liberar_assento(p)
	_remover_filas(p)
	if str(p.sala_destino) != "":
		_soltar_sala(p)
	if p.funcionario_atendendo != "":
		_liberar_funcionario(str(p.funcionario_atendendo))
	if p.demanda != null:
		p.demanda = null
	p.balao_tipo = ""
	p.balao_ate = 0.0
	p.fase = "saindo"
	p.andando = false
	p.destino_tipo = ""
	p.atendimento_restante = 0.0
	if desistiu:
		inc("desistencias")
		alerta("%s foi embora sem ser atendido." % p.nome, 3.5)
		som("alerta")
	_mover_para(p, _ponto_saida(), {"tipo": "sair", "desistiu": desistiu})
	for cid in p.criancas:
		var c = _pessoa(str(cid))
		if c != null and c.fase not in ["saindo", "saiu"]:
			c.fase = "saindo"
			c.andando = false
			_mover_para(c, _ponto_saida(), {"tipo": "sair"})


func _ao_chegar_saida(p: Dictionary) -> void:
	p.visivel = false
	p.oculto = true
	p.andando = false
	p.sentado = false
	p.fase = "saiu"
	if p.tipo == "crianca":
		return
	if p.tipo == "paciente":
		inc("saidas")
	if p.tipo == "acs":
		p.fase = "externo"


func _ao_chegar_fila_guiche(p: Dictionary) -> void:
	if p.fase in ["saindo", "saiu", "no_guiche"]:
		return
	p.fase = "fila_guiche"
	p.sentado = false


func _ao_chegar_guiche(p: Dictionary) -> void:
	if p.fase in ["saindo", "saiu"]:
		return
	p.fase = "no_guiche"
	p.sentado = false
	p.facing = -1
	guiche_timer = ri.randf_range(GUICHE_MIN, GUICHE_MAX)
	var g = entidades.get("guiche", null)
	if g != null:
		g.fase = "atendendo"
		g.facing = -1


func _ao_chegar_cadeira(p: Dictionary) -> void:
	if p.fase in ["saindo", "saiu"]:
		return
	p.pos = cadeiras[p.cadeira].pos if p.cadeira >= 0 else p.pos
	p.sentado = true
	p.andando = false
	p.fase = "sentado"
	p.facing = 1


func _ao_chegar_em_pe(p: Dictionary) -> void:
	if p.fase in ["saindo", "saiu"]:
		return
	if p.em_pe >= 0:
		p.pos = espacos_em_pe[p.em_pe]
	p.sentado = false
	p.andando = false
	p.fase = "em_pe"


func _ao_chegar_recepcao(p: Dictionary) -> void:
	if p.fase in ["saindo", "saiu"]:
		return
	var pc = pcs_por_id.get(str(p.estacao_recepcao), null)
	if pc == null:
		p.fase = "sentado"
		return
	p.pos = pc.atendimento if pc.atendimento != null else p.pos
	p.sentado = false
	p.facing = -1
	p.atendimento_restante = ri.randf_range(REC_ATEND_MIN, REC_ATEND_MAX)
	p.fase = "no_recepcao"
	if pc.jogador:
		p.fase = "no_recepcao_player"
		atendendo_paciente = p.id
		atendimento_timer = p.atendimento_restante
		alerta(_txt("avisos", "interrupcao_recepcao", "Um paciente chegou para ser atendido no seu computador."), 3.0)
		som("alerta")
	else:
		p.funcionario_recepcao = str(pc.ocupante)


func _ao_chegar_sala(p: Dictionary) -> void:
	if p.fase in ["saindo", "saiu"]:
		return
	var sala = _sala_por_id(str(p.sala_destino))
	if sala == null or p.spot_sala < 0 or p.spot_sala >= sala.paciente_spots.size():
		p.fase = "sentado"
		return
	p.pos = sala.paciente_spots[p.spot_sala]
	p.sentado = true
	p.andando = false
	p.fase = "na_sala"
	p.facing = -1
	_expulsar_jogador_sala(sala.id)


func _ao_chegar_passeio(p: Dictionary) -> void:
	p.fase = "passeando"
	if p.visita_ate <= 0.0:
		p.visita_ate = tempo + ri.randf_range(6.0, 14.0)


func _ao_chegar_visita(p: Dictionary) -> void:
	p.fase = "passeando"
	p.visita_ate = tempo + ri.randf_range(5.0, 10.0)
# =================================================================== rotinas

func _atualizar_pacientes(dt: float) -> void:
	prox_paciente -= dt
	if prox_paciente <= 0.0:
		if _contar_adultos() < MAX_ADULTOS:
			_novo_paciente()
			prox_paciente = ri.randf_range(NOVO_PAC_MIN, NOVO_PAC_MAX) * mult_pacientes
		else:
			prox_paciente = 3.0
	for p in pessoas:
		if p.tipo not in ["paciente", "crianca"] or p.fase in ["saiu"]:
			continue
		if p.tipo == "crianca":
			continue
		if not p.visivel or p.oculto:
			continue
		p.tempo_no_postinho += dt
		var esperando: bool = p.fase in ["fila_guiche", "indo_fila_guiche", "sentado", "em_pe", "indo_cadeira", "indo_em_pe", "na_sala"]
		if esperando:
			p.tempo_espera += dt
		if p.fase == "saindo":
			continue
		if p.fase in ["fila_guiche", "indo_fila_guiche"] and p.tempo_espera > p.tolerancia_fila:
			inc("desistencias_fila")
			_iniciar_saida(p, true)
			continue
		if p.fase != "no_guiche" and p.fase != "no_recepcao" and p.fase != "no_recepcao_player" and p.atendimento_restante <= 0.0:
			if p.tempo_no_postinho > p.tolerancia_total:
				inc("desistencias_tolerancia")
				_iniciar_saida(p, true)
				continue
		if p.demanda == null and tarefas < TAREFAS_MAX and esperando and p.fase != "saindo":
			if ri.randf() < 0.018 * dt:
				_criar_demanda(p, false)


func _atualizar_guiche(dt: float) -> void:
	var g = entidades.get("guiche", null)
	if guiche_atendendo == "":
		while not fila_guiche.is_empty():
			var pid := str(fila_guiche[0])
			var p = _pessoa(pid)
			if p == null or p.fase in ["saindo", "saiu"]:
				fila_guiche.pop_front()
				continue
			var alvo := _vet(guiche.get("atendimento", [975, 205]))
			if p.pos.distance_to(alvo) <= 52.0:
				fila_guiche.pop_front()
				guiche_atendendo = pid
				p.fase = "indo_guiche"
				_liberar_assento(p)
				_mover_para(p, alvo, {"tipo": "guiche_atendimento"})
				_posicionar_fila_guiche()
				if g != null:
					g.fase = "atendendo"
					g.facing = -1
			break
	else:
		var p = _pessoa(str(guiche_atendendo))
		if p == null or p.fase in ["saindo", "saiu"]:
			guiche_atendendo = ""
			guiche_timer = 0.0
			if g != null:
				g.fase = "no_posto"
		elif p.fase == "no_guiche":
			guiche_timer -= dt
			if guiche_timer <= 0.0:
				guiche_atendendo = ""
				if g != null:
					g.fase = "no_posto"
					g.energia = maxf(0.0, g.energia - NPC_CUSTO_ATEND)
					g.facing = -1
				p.fase = "saindo_guiche"
				_depois_guiche(p)
				som("atendimento")


func _atualizar_recepcao(dt: float) -> void:
	# Recepcionistas chamam quem está esperando.
	for i in range(fila_recepcao.size() - 1, -1, -1):
		var p = _pessoa(str(fila_recepcao[i]))
		if p == null or p.fase in ["saindo", "saiu", "no_recepcao", "indo_recepcao", "no_recepcao_player"] or str(p.destino_tipo) != "recepcao":
			fila_recepcao.remove_at(i)
	for pc in pcs:
		if pc.tipo != "recepcao" or pc.jogador or pc.atendimento_id != "" or pc.ocupante == "":
			continue
		var recepcionista = _pessoa(str(pc.ocupante))
		if recepcionista == null or recepcionista.tipo != "recepcao" or recepcionista.oculto or recepcionista.fase in ["externo", "passeando", "na_copa", "indo_copa"]:
			continue
		if recepcionista.pos.distance_to(pc.assento) > 22.0:
			continue
		if fila_recepcao.is_empty():
			continue
		var p = _pessoa(str(fila_recepcao.pop_front()))
		if p == null or p.fase in ["saindo", "saiu"]:
			continue
		p.estacao_recepcao = pc.id
		p.funcionario_recepcao = recepcionista.id
		p.fase = "indo_recepcao"
		_liberar_assento(p)
		pc.atendimento_id = p.id
		_mover_para(p, pc.atendimento, {"tipo": "recepcao"})
		recepcionista.fase = "chamando"
		recepcionista.facing = 1
	# Jogador sentado na recepção pode ser interrompido.
	if estado == Estado.NO_PC and foco != null and foco.tipo == "recepcao" and atendendo_paciente == "" and foco.atendimento_id == "" and not fila_recepcao.is_empty():
		if ri.randf() < PC_INTERRUPCAO_CHANCE * dt:
			var p = _pessoa(str(fila_recepcao.pop_front()))
			if p != null and p.fase not in ["saindo", "saiu"]:
				_liberar_assento(p)
				p.estacao_recepcao = foco.id
				p.fase = "indo_recepcao"
				foco.atendimento_id = p.id
				_mover_para(p, foco.atendimento, {"tipo": "recepcao"})
				alerta(_txt("avisos", "interrupcao_recepcao", "Um paciente chegou para ser atendido no seu computador."), 3.0)
	# Conta o tempo dos atendimentos feitos pelos recepcionistas.
	for p in pessoas:
		if p.tipo != "paciente" or p.fase != "no_recepcao":
			continue
		var pc = pcs_por_id.get(str(p.estacao_recepcao), null)
		if pc == null:
			p.fase = "sentado"
			continue
		p.atendimento_restante -= dt
		if p.atendimento_restante <= 0.0:
			p.atendimento_restante = 0.0
			pc.atendimento_id = ""
			var recepcionista = _pessoa(str(p.funcionario_recepcao))
			if recepcionista != null:
				recepcionista.fase = "trabalhando"
				recepcionista.facing = 1
				var ratio: float = float(recepcionista.energia) / maxf(0.001, float(recepcionista.max_energia))
				p.raiva = clampf(p.raiva + (RAIVA_BOM if ratio > 0.45 else RAIVA_RUIM * 0.6), 0.0, 100.0)
				recepcionista.energia = maxf(0.0, float(recepcionista.energia) - NPC_CUSTO_ATEND * 0.5)
			inc("atendidos_recepcao")
			som("atendimento")
			_proximo_servico(p)


func _atualizar_criancas(dt: float) -> void:
	for p in pessoas:
		if p.tipo != "crianca" or p.fase in ["saiu"]:
			continue
		if not p.visivel or p.oculto:
			continue
		var adulto = _pessoa(str(p.adulto_id))
		if adulto == null or adulto.fase in ["saindo", "saiu"]:
			if p.fase != "saindo":
				p.fase = "saindo"
				_mover_para(p, _ponto_saida(), {"tipo": "sair"})
			continue
		if p.fase == "saindo":
			continue
		if p.andando:
			continue
		var alvo: Vector2 = adulto.pos + Vector2(ri.randf_range(-CRIANCA_DIST, CRIANCA_DIST), ri.randf_range(8.0, CRIANCA_DIST))
		if p.pos.distance_to(adulto.pos) > 78.0:
			p.fase = "seguindo"
			_mover_para(p, alvo, {}, true)
			p.visita_ate = tempo + 0.6
		elif tempo >= p.visita_ate:
			p.visita_ate = tempo + ri.randf_range(1.8, 4.5)
			var raio := CRIANCA_RAIO
			var passeio: Vector2 = adulto.pos + Vector2(ri.randf_range(-raio, raio), ri.randf_range(-raio * 0.5, raio * 0.5))
			if nav.ponto_livre(passeio):
				p.fase = "passeando"
				_mover_para(p, passeio, {}, true)
		p.facing = 1 if p.pos.x >= adulto.pos.x else -1
# =================================================================== salas

func _sala_tem_espera(id: String) -> bool:
	for p in pessoas:
		if p.tipo != "paciente" or p.fase in ["saindo", "saiu"]:
			continue
		if str(p.destino_tipo) == "sala" and str(p.sala_destino) == id and p.fase in ["sentado", "em_pe", "indo_cadeira", "indo_em_pe", "indo_sala", "na_sala"]:
			return true
	return false


func _sala_vazia_para_jogador(id: String) -> bool:
	var sala = _sala_por_id(id)
	if sala == null or sala.tipo == "chefe":
		return false
	if estado == Estado.NO_PC and foco != null and foco.tipo == "sala" and str(foco.sala) == id:
		return true
	if _contar_na_sala(sala) > 0:
		return false
	for p in pessoas:
		if p.tipo == "funcionario_sala" and str(p.sala) == id and p.visivel and not p.oculto:
			if str(p.fase) not in ["aguardando_entrada", "indo_externo", "externo", "saindo", "saiu"] and _dentro_da_sala(p, sala):
				return false
		if p.tipo == "funcionario_sala" and str(p.sala) == id and p.servindo != "":
			return false
		if p.tipo == "paciente" and p.fase == "indo_sala" and str(p.sala_destino) == id:
			return false
	return true


func _funcionarios_da_sala(sala: Dictionary) -> Array:
	var lista: Array = []
	for p in pessoas:
		if p.tipo == "funcionario_sala" and str(p.sala) == sala.id and not p.oculto:
			lista.append(p)
	return lista


func _chamar_funcionario_sala(f: Dictionary, sala: Dictionary) -> void:
	if f == null or f.oculto or f.servindo != "":
		return
	if f.fase in ["indo_atender", "atendendo", "auxiliando", "indo_posto", "entrando"]:
		return
	var spot: Vector2 = f.posto
	if spot == Vector2.ZERO and not sala.cadeiras.is_empty():
		spot = sala.cadeiras[0]
	f.fase = "voltando_posto"
	f.visita_sala = ""
	_mover_para(f, spot, {"tipo": "voltar_posto"}, true)


func _chamar_paciente_sala(sala: Dictionary) -> void:
	if _contar_na_sala(sala) >= int(sala.capacidade):
		return
	var spot := _spot_sala_livre(sala)
	if spot < 0:
		return
	var escolhido = null
	for p in pessoas:
		if p.tipo != "paciente" or p.fase in ["saindo", "saiu"]:
			continue
		if str(p.destino_tipo) != "sala" or str(p.sala_destino) != sala.id:
			continue
		if p.fase not in ["sentado", "em_pe", "indo_cadeira", "indo_em_pe"]:
			continue
		if escolhido == null or int(p.ordem) < int(escolhido.ordem):
			escolhido = p
	if escolhido == null:
		return
	_expulsar_jogador_sala(sala.id)
	escolhido.spot_sala = spot
	escolhido.fase = "indo_sala"
	_liberar_assento(escolhido)
	sala.paciente_ocupado[escolhido.id] = true
	_mover_para(escolhido, sala.paciente_spots[spot], {"tipo": "sala"})
	escolhido.facing = 1 if sala.paciente_spots[spot].x > escolhido.pos.x else -1


func _ponto_ao_lado_paciente(p: Dictionary, sala: Dictionary) -> Vector2:
	var alvo: Vector2 = p.pos
	if p.spot_sala >= 0 and p.spot_sala < sala.paciente_spots.size():
		alvo = sala.paciente_spots[p.spot_sala]
	return alvo + Vector2(-DISTANCIA_LADO, 0)


func _atualizar_salas(dt: float) -> void:
	for sala in salas:
		if sala.tipo == "copa":
			continue
		# Libera funcionários presos em atendimentos cujo paciente já saiu.
		for f in _funcionarios_da_sala(sala):
			if f.servindo != "":
				var pf = _pessoa(str(f.servindo))
				if pf == null or pf.fase in ["saindo", "saiu"]:
					_liberar_funcionario(f.id)
		_chamar_paciente_sala(sala)
		var principal = null
		var auxiliar = null
		for f in _funcionarios_da_sala(sala):
			if f.servindo != "":
				if principal == null:
					principal = f
				else:
					auxiliar = f
			elif principal == null and f.servindo == "" and f.fase not in ["indo_atender", "atendendo", "auxiliando"]:
				principal = f
			elif f.servindo == "" and f.fase not in ["indo_atender", "atendendo", "auxiliando"]:
				auxiliar = f
		# Paciente dentro da sala esperando atendimento.
		for p in pessoas:
			if p.tipo != "paciente" or str(p.sala_destino) != sala.id or p.fase != "na_sala":
				continue
			if p.atendimento_restante > 0.0:
				var chefe_atende = _pessoa(str(p.funcionario_atendendo))
				if chefe_atende != null and chefe_atende.fase == "atendendo":
					p.atendimento_restante -= dt
					if p.atendimento_restante <= 0.0:
						_finalizar_sala(sala, p, chefe_atende)
				continue
			if p.funcionario_atendendo != "":
				continue
			if principal == null:
				continue
			if principal.servindo != "" and principal.servindo != p.id:
				continue
			if principal.servindo == "":
				if principal.fase in ["passeando", "na_copa", "indo_copa", "externo"] or principal.pos.distance_to(principal.posto) > 42.0:
					_chamar_funcionario_sala(principal, sala)
					continue
				if principal.andando:
					continue
				principal.servindo = p.id
				p.funcionario_atendendo = principal.id
				principal.fase = "indo_atender"
				principal.facing = 1 if p.pos.x > principal.pos.x else -1
				_mover_para(principal, _ponto_ao_lado_paciente(p, sala), {"tipo": "atender_sala", "paciente": p.id}, true)
				if auxiliar != null and auxiliar.servindo == "" and sala.tipo in ["vacina", "procedimentos"]:
					auxiliar.servindo = p.id
					auxiliar.fase = "indo_atender"
					auxiliar.facing = principal.facing
					_mover_para(auxiliar, _ponto_ao_lado_paciente(p, sala) + Vector2(0, 20), {"tipo": "auxiliar_sala", "paciente": p.id}, true)
			if principal.servindo == p.id and principal.fase == "atendendo":
				if p.atendimento_restante <= 0.0:
					p.atendimento_restante = ri.randf_range(SALA_MIN, SALA_MAX) if sala.tipo != "chefe" else ri.randf_range(CHEFE_MIN, CHEFE_MAX)
			# Só um paciente por sala é atendido por vez.
			break


func _ao_chegar_atender(p: Dictionary, acao: Dictionary) -> void:
	var pac = _pessoa(str(acao.get("paciente", "")))
	if pac == null or pac.fase in ["saindo", "saiu"]:
		_liberar_funcionario(p.id)
		return
	if str(pac.funcionario_atendendo) == p.id:
		p.fase = "atendendo"
		p.facing = 1 if pac.pos.x > p.pos.x else -1
		if pac.atendimento_restante <= 0.0:
			var sala = _sala_por_id(str(pac.sala_destino))
			pac.atendimento_restante = ri.randf_range(SALA_MIN, SALA_MAX) if sala == null or sala.tipo != "chefe" else ri.randf_range(CHEFE_MIN, CHEFE_MAX)
	else:
		p.fase = "auxiliando"
		p.facing = 1 if pac.pos.x > p.pos.x else -1


func _finalizar_sala(sala: Dictionary, p: Dictionary, f: Dictionary) -> void:
	var ratio: float = float(f.energia) / maxf(0.001, float(f.max_energia))
	var ajuste := RAIVA_BOM if ratio > 0.45 else RAIVA_RUIM * 0.7
	p.raiva = clampf(p.raiva + ajuste, 0.0, 100.0)
	f.energia = maxf(0.0, float(f.energia) - NPC_CUSTO_ATEND * (1.15 if sala.tipo in ["vacina", "procedimentos"] else 1.0))
	var aux = null
	for g in _funcionarios_da_sala(sala):
		if g != f and str(g.servindo) == p.id:
			aux = g
			g.energia = maxf(0.0, float(g.energia) - NPC_CUSTO_ATEND * 0.55)
			break
	sala.paciente_ocupado.erase(p.id)
	p.spot_sala = -1
	p.atendimento_restante = 0.0
	p.funcionario_atendendo = ""
	p.sentado = false
	p.fase = "saindo_sala"
	inc("atendidos_sala")
	som("atendimento")
	_liberar_funcionario(f.id)
	if aux != null:
		_liberar_funcionario(aux.id)
	p.raiva = clampf(p.raiva, 0.0, 100.0)
	_proximo_servico(p)


func _liberar_funcionario(id: String) -> void:
	var f = _pessoa(id)
	if f == null:
		return
	f.servindo = ""
	if f.tipo == "funcionario_sala" and f.sala != "":
		var sala = _sala_por_id(str(f.sala))
		if sala != null and not f.oculto:
			f.fase = "voltando_posto"
			_mover_para(f, f.posto, {"tipo": "voltar_posto"}, true)
	else:
		if f.fase not in ["externo", "aguardando_entrada", "saindo", "saiu"]:
			f.fase = "ocioso"
# =================================================================== funcionarios

func _chance_passeio(p: Dictionary) -> float:
	var f: Dictionary = cfg.get("funcionarios", {})
	match str(p.cargo_key):
		"medica":
			return _num(f, "chance_passeio_medica_s", 0.012)
		"enfermeira":
			return _num(f, "chance_passeio_enfermeira_s", 0.024)
		"vacina", "procedimentos":
			return _num(f, "chance_passeio_auxiliar_s", 0.03)
		"recepcao":
			return _num(f, "chance_passeio_recepcao_s", 0.018)
	return 0.0


func _ponto_passeio(p: Dictionary) -> Dictionary:
	var opcoes: Array = []
	opcoes.append({"pos": _ponto_copa_livre(), "acao": "copa"})
	opcoes.append({"pos": Vector2(612, 330), "acao": "passeio"})
	opcoes.append({"pos": Vector2(660, 220), "acao": "passeio"})
	if jogador().visivel:
		opcoes.append({"pos": jogador().pos + Vector2(34, 20), "acao": "passeio"})
	for q in pessoas:
		if q.tipo == "acs" and q.no_pc != "" and q != p:
			opcoes.append({"pos": q.pos + Vector2(30, 16), "acao": "passeio"})
			if opcoes.size() > 7:
				break
	for sala in salas:
		if sala.id != str(p.sala) and sala.tipo != "copa":
			opcoes.append({"pos": Vector2(sala.x + sala.w - 50, sala.y + sala.h * 0.55), "acao": "passeio"})
	var validas: Array = []
	for o in opcoes:
		if nav.ponto_livre(o.pos):
			validas.append(o)
	if validas.is_empty():
		return {"pos": _ponto_copa_livre(), "acao": "copa"}
	return validas[ri.randi_range(0, validas.size() - 1)]


func _iniciar_passeio(p: Dictionary) -> void:
	var o := _ponto_passeio(p)
	p.fase = "indo_passeio"
	p.visita_ate = tempo + ri.randf_range(6.0, 12.0)
	_mover_para(p, o.pos, {"tipo": str(o.acao)}, true)


func _voltar_ao_posto(p: Dictionary) -> void:
	if p.posto_tipo == "sala" and p.posto != Vector2.ZERO:
		p.fase = "voltando_posto"
		_mover_para(p, p.posto, {"tipo": "voltar_posto"}, true)
	elif p.posto_tipo == "guiche" and p.posto != Vector2.ZERO:
		p.fase = "voltando_posto"
		_mover_para(p, p.posto, {"tipo": "voltar_posto"}, true)
	elif p.posto_tipo == "pc" and p.no_pc != "":
		var pc = pcs_por_id.get(str(p.no_pc), null)
		if pc != null:
			p.posto = pc.assento
			p.fase = "indo_posto"
			_mover_para(p, pc.assento, {"tipo": "posto"}, true)
	else:
		var vaga := _vaga_em_pe(p)
		if vaga >= 0:
			p.em_pe = vaga
			p.fase = "indo_posto"
			_mover_para(p, espacos_em_pe[vaga], {"tipo": "posto_livre"}, true)
		else:
			p.fase = "ocioso"


func _iniciar_externo(p: Dictionary) -> void:
	if p.fase in ["indo_externo", "externo", "saindo", "saiu"]:
		return
	if p.demanda != null:
		_limpar_demanda(p)
	p.fase = "indo_externo"
	p.servindo = ""
	_mover_para(p, _ponto_saida(), {"tipo": "externo"}, true)


func _ao_chegar_externo(p: Dictionary) -> void:
	inc("trabalhos_externos")
	p.visivel = false
	p.oculto = true
	p.andando = false
	p.fase = "externo"
	p.externo_ate = tempo + ri.randf_range(35.0, 80.0)


func _npc_na_copa(p: Dictionary) -> void:
	p.fase = "na_copa"
	p.sentado = false
	p.visita_ate = tempo + ri.randf_range(4.0, 8.0)


func _atualizar_funcionarios(dt: float) -> void:
	var fcfg: Dictionary = cfg.get("funcionarios", {})
	for p in pessoas:
		if p.tipo not in ["funcionario_sala", "guiche", "recepcao", "acs"]:
			continue
		if p.oculto and p.fase != "externo":
			continue
		if p.fase == "externo":
			if tempo >= p.externo_ate:
				p.oculto = false
				p.visivel = true
				p.pos = _spawn_entrada(p)
				p.fase = "entrando"
				_voltar_ao_posto(p)
			continue
		if not p.visivel:
			continue
		if p.fase == "na_copa":
			p.energia = minf(p.max_energia, p.energia + 0.7 * dt)
			if tempo >= p.visita_ate:
				_voltar_ao_posto(p)
			continue
		if p.fase == "passeando":
			if tempo >= p.visita_ate:
				_voltar_ao_posto(p)
			continue
		if p.fase in ["indo_passeio", "indo_copa", "voltando_posto", "indo_posto", "indo_atender", "auxiliando", "atendendo", "indo_externo", "entrando", "chamando", "indo_abordar_jogador", "abordando_jogador", "voltando_externo"]:
			pass
		elif p.fase in ["trabalhando", "no_posto", "ocioso"] and not p.andando:
			if p.tipo == "acs" and p.energia > 0.5 and p.servindo == "" and p.demanda == null:
				if ri.randf() < 0.01 * dt:
					_iniciar_externo(p)
					continue
			if p.energia <= 0.15:
				if p.fase != "na_copa":
					p.fase = "indo_copa"
					_mover_para(p, _ponto_copa_livre(), {"tipo": "copa"}, true)
				continue
			if p.tipo == "funcionario_sala" and p.sala != "":
				var sala = _sala_por_id(str(p.sala))
				if sala != null and not _sala_tem_espera(sala.id) and p.servindo == "":
					var chance := _chance_passeio(p)
					if chance > 0.0 and ri.randf() < chance * dt:
						_iniciar_passeio(p)
						continue
				if p.energia < 1.0 and not _sala_tem_espera(sala.id) and p.servindo == "":
					if ri.randf() < 0.02 * dt:
						p.fase = "indo_copa"
						_mover_para(p, _ponto_copa_livre(), {"tipo": "copa"}, true)
						continue
			if p.fase == "trabalhando":
				p.energia = maxf(0.0, p.energia - NPC_CUSTO_PC * dt)
		if p.demanda != null and p.tipo != "funcionario_sala":
			p.cooldown_demanda = 0.0
	# Retorno de demandas expiradas e trabalho do guichê.
	if not fcfg.is_empty():
		pass


func _atualizar_abordagens(dt: float) -> void:
	var pj := jogador()
	if estado != Estado.NO_PC or foco == null or foco.tipo != "interno" or not pj.visivel:
		for p in pessoas:
			if p.fase in ["indo_abordar_jogador", "abordando_jogador"] and p.tipo != "paciente":
				_liberar_abordagem(p)
		return
	var tem_abordagem := false
	for p in pessoas:
		if p.fase == "abordando_jogador":
			tem_abordagem = true
			if modal == null and p.demanda != null and tarefas < TAREFAS_MAX and tempo - p.abordagem_ate > 0.8:
				if abrir_dialogo(p):
					som("alerta")
			break
	if tem_abordagem:
		return
	for p in pessoas:
		if p.tipo == "jogador" or p.tipo == "paciente" or p.tipo == "crianca":
			continue
		if p.demanda == null or p.oculto or not p.visivel:
			continue
		if float(p.energia) / maxf(0.001, float(p.max_energia)) < 0.5:
			continue
		if p.fase in ["externo", "saindo", "saiu", "entrando", "aguardando_entrada", "atendendo", "auxiliando", "indo_atender", "servindo"]:
			continue
		if p.servindo != "":
			continue
		if ri.randf() < PC_ABORDAGEM_CHANCE * dt:
			var alvo: Vector2 = pj.pos + Vector2(-DISTANCIA_LADO, 0)
			if not nav.ponto_livre(alvo):
				alvo = pj.pos + Vector2(0, DISTANCIA_LADO)
			p.fase = "indo_abordar_jogador"
			p.abordagem_ate = 0.0
			_mover_para(p, alvo, {"tipo": "abordar_jogador"}, true)
			alerta("Alguém quer falar com você.", 2.0)
			break


func _ao_chegar_abordagem(p: Dictionary) -> void:
	p.fase = "abordando_jogador"
	p.abordagem_ate = tempo
	p.sentado = false
	_forcar_balao(p, "exclamacao", 3.0)


func _ao_chegar_abordagem_jogador(p: Dictionary) -> void:
	_ao_chegar_abordagem(p)


func _liberar_abordagem(p: Dictionary) -> void:
	if p.fase not in ["indo_abordar_jogador", "abordando_jogador"]:
		return
	p.abordagem_ate = 0.0
	if p.tipo != "jogador" and p.tipo != "paciente" and p.tipo != "crianca":
		_voltar_ao_posto(p)
# =================================================================== demandas

func _chave_demanda(p: Dictionary) -> String:
	if p.tipo == "paciente":
		return "pacientes"
	match str(p.cargo_key):
		"chefe", "medica", "enfermeira":
			return str(p.cargo_key)
	return "funcionarios"


func _criar_demanda(p: Dictionary, forcada: bool = false) -> Dictionary:
	if p == null or p.tipo == "crianca" or p.tipo == "jogador":
		return {}
	if p.demanda != null:
		return p.demanda
	if p.papo != null:
		inc("papos_interrompidos")
		_encerrar_papo(p, false)
	var chave := _chave_demanda(p)
	var lista: Array = demandas_def.get(chave, [])
	if lista.is_empty():
		return {}
	var pesos: Array = []
	for d in lista:
		pesos.append(float(d.get("peso", 1.0)))
	var base = _escolher_por_peso(lista, pesos)
	var d: Dictionary = base.duplicate(true)
	d["vida"] = 0.0 if (str(p.cargo_key) == "chefe" or p.tipo == "paciente") else ri.randf_range(DEM_VIDA_MIN, DEM_VIDA_MAX)
	d["tipo"] = chave
	p.demanda = d
	p.balao_tipo = "exclamacao"
	p.balao_ate = tempo + 999.0
	if forcada:
		som("alerta")
	return d


func _limpar_demanda(p: Dictionary) -> void:
	p.demanda = null
	p.balao_ate = 0.0
	if p.balao_tipo == "exclamacao":
		p.balao_tipo = ""


func _atualizar_demandas(dt: float) -> void:
	prox_demanda -= dt
	if prox_demanda <= 0.0:
		prox_demanda = ri.randf_range(DEM_MIN, DEM_MAX) * mult_demandas
		if tarefas < TAREFAS_MAX and modal == null:
			var candidatos: Array = []
			for p in pessoas:
				if p.tipo in ["jogador", "paciente", "crianca"] or p.oculto or not p.visivel:
					continue
				if p.demanda != null or p.fase in ["saindo", "saiu", "externo", "entrando", "aguardando_entrada", "atendendo", "auxiliando", "indo_atender"]:
					continue
				if p.servindo != "":
					continue
				candidatos.append(p)
			if not candidatos.is_empty():
				var escolhido = null
				var chefe = entidades.get("chefe", null)
				if chefe != null and chefe.demanda == null and ri.randf() < 0.45:
					escolhido = chefe
				else:
					escolhido = candidatos[ri.randi_range(0, candidatos.size() - 1)]
				_criar_demanda(escolhido, false)
				inc("demandas_geradas")
	for p in pessoas:
		if p.demanda == null:
			continue
		if p.tipo == "paciente" or p.tipo == "crianca":
			continue
		if str(p.cargo_key) == "chefe":
			continue
		var d: Dictionary = p.demanda
		if ri.randf() < DEM_DESISTENCIA * dt:
			_limpar_demanda(p)
			inc("demandas_desistidas")
			continue
		if float(d.get("vida", 0.0)) > 0.0:
			d["vida"] = float(d.vida) - dt
			if float(d.vida) <= 0.0:
				_limpar_demanda(p)
				inc("demandas_desistidas")


func _opcoes_dialogo(p: Dictionary) -> Array:
	var alto := energia / maxf(0.001, E_MAX) > 0.8
	var medio := energia / maxf(0.001, E_MAX) >= 0.4
	var poderoso: bool = str(p.cargo_key) in ["chefe", "medica", "enfermeira"]
	var opcoes: Array = []
	if poderoso:
		if alto:
			opcoes.append({"texto": _txt("dialogo", "aceitar_positivo_1", "Claro, pode contar comigo."), "aceitar": true, "relutante": false})
			opcoes.append({"texto": _txt("dialogo", "aceitar_positivo_2", "Com prazer. Já vou resolver isso."), "aceitar": true, "relutante": false})
		elif medio:
			opcoes.append({"texto": _txt("dialogo", "aceitar_positivo_1", "Claro, pode contar comigo."), "aceitar": true, "relutante": false})
			opcoes.append({"texto": _txt("dialogo", "aceitar_relutante_1", "Tudo bem... eu dou um jeito."), "aceitar": true, "relutante": true})
		else:
			opcoes.append({"texto": _txt("dialogo", "aceitar_relutante_1", "Tudo bem... eu dou um jeito."), "aceitar": true, "relutante": true})
			opcoes.append({"texto": _txt("dialogo", "aceitar_relutante_2", "Se precisa, eu faço."), "aceitar": true, "relutante": true})
	else:
		if energia / maxf(0.001, E_MAX) >= 0.5:
			opcoes.append({"texto": _txt("dialogo", "aceitar_positivo_1", "Claro, pode contar comigo."), "aceitar": true, "relutante": false})
			opcoes.append({"texto": _txt("dialogo", "negar_educado_1", "Agora não consigo, desculpe."), "aceitar": false, "relutante": false})
		else:
			opcoes.append({"texto": _txt("dialogo", "aceitar_relutante_1", "Tudo bem... eu dou um jeito."), "aceitar": true, "relutante": true})
			opcoes.append({"texto": _txt("dialogo", "negar_cansado_1", "Estou exausto. Não consigo assumir mais nada."), "aceitar": false, "relutante": true})
	return opcoes


func abrir_dialogo(p: Dictionary) -> bool:
	if p == null or not p.visivel or p.oculto:
		return false
	if modal != null:
		return false
	if tarefas >= TAREFAS_MAX:
		alerta(_txt("dialogo", "limite_trabalhos", "Você já tem 10 trabalhos pendentes."), 3.0)
		_forcar_balao(p, "exclamacao", 2.0)
		return false
	var d = p.demanda
	if d == null:
		d = _criar_demanda(p, true)
	if d.is_empty():
		return false
	var antes := estado
	estado = Estado.CONVERSANDO
	var opcoes := _opcoes_dialogo(p)
	modal = {
		"nome": str(p.nome), "cargo": str(p.cargo), "texto": str(d.get("texto", "")),
		"opcoes": opcoes, "alvo_id": str(p.id), "cor": str(p.roupa),
		"tipo": str(d.get("tipo", "funcionarios")), "estado_antes": antes,
		"fundido": "Energia baixa: respostas mais cautelosas." if energia / maxf(0.001, E_MAX) < 0.4 else "",
	}
	inc("dialogos_abertos")
	return true


func fechar_dialogo() -> void:
	if modal == null:
		return
	var tipo_modal := str(modal.get("tipo", ""))
	var antes := int(modal.get("estado_antes", Estado.LIVRE))
	var era_papo: bool = tipo_modal == "papo"
	var respondeu: bool = str(modal.get("fase", "")) == "resposta"
	var alvo = _pessoa(str(modal.get("alvo_id", "")))
	modal = null
	if tipo_modal == "exame":
		exame_busca["ativo"] = false
	if estado == Estado.CONVERSANDO:
		estado = antes if antes != Estado.CONVERSANDO else Estado.LIVRE
	if alvo != null:
		if era_papo:
			if not respondeu:
				inc("papos_perdidos")
			_encerrar_papo(alvo, respondeu)
		else:
			_liberar_abordagem(alvo)


func motivo_opcao(_op: Dictionary) -> String:
	return ""


func escolher_opcao(i: int) -> void:
	if modal == null:
		return
	if str(modal.get("tipo", "")) == "papo":
		_responder_papo(i)
		return
	var opcoes: Array = modal.get("opcoes", [])
	if i < 0 or i >= opcoes.size():
		return
	var op: Dictionary = opcoes[i]
	var alvo = _pessoa(str(modal.get("alvo_id", "")))
	var d = null
	if alvo != null:
		d = alvo.demanda
	var aceitou := bool(op.get("aceitar", false))
	var gerou := 0
	if aceitou:
		if d != null:
			gerou = _aplicar_consequencia(d)
		inc("demandas_aceitas")
		if alvo != null and alvo.tipo == "paciente":
			alvo.raiva = maxf(0.0, alvo.raiva + RAIVA_BOM)
			_forcar_balao(alvo, "coracao", 2.0)
		som("aceitar")
	else:
		inc("demandas_negadas")
		if alvo != null and alvo.tipo == "paciente":
			alvo.raiva = minf(100.0, alvo.raiva + RAIVA_RUIM * 0.7)
			_forcar_balao(alvo, "raiva", 2.0)
		som("negar")
	if alvo != null and alvo.demanda != null:
		_limpar_demanda(alvo)
	var antes := int(modal.get("estado_antes", Estado.LIVRE))
	modal = null
	if estado == Estado.CONVERSANDO:
		estado = antes if antes != Estado.CONVERSANDO else Estado.LIVRE
	if alvo != null:
		_liberar_abordagem(alvo)
	if aceitou:
		if gerou <= 0:
			alerta("Demanda aceita. O caminho gastou um pouco da sua energia.", 3.0)
		else:
			alerta(_txt("dialogo", "aceito", "Demanda aceita.") % tarefas, 3.0)
	else:
		alerta(_txt("dialogo", "negado", "Demanda recusada."), 2.0)
	if exame_pendente:
		exame_pendente = false
		abrir_exame(d if d is Dictionary else {})


func _aplicar_consequencia(d: Dictionary) -> int:
	if bool(d.get("sem_pc", false)):
		var custo: float = maxf(0.0, float(d.get("custo_energia", 0.16)))
		energia = maxf(0.0, energia - custo)
		inc("tarefas_sem_pc")
		return 0
	var faixa: Array = d.get("tarefas", [1, 1])
	var qmin: int = int(faixa[0]) if not faixa.is_empty() else 1
	var qmax: int = int(faixa[1]) if faixa.size() > 1 else qmin
	var qtd := ri.randi_range(qmin, maxi(qmin, qmax))
	var antes := tarefas
	tarefas = mini(TAREFAS_MAX, tarefas + qtd)
	if tarefas >= TAREFAS_MAX:
		alerta("Você atingiu 10 trabalhos pendentes.", 3.0)
	if qtd > 0 and str(d.get("tipo_tarefa", "")) == "exame":
		exame_pendente = true
	return tarefas - antes


func levar_pessoa_ao_jogador(p: Dictionary) -> bool:
	return abrir_dialogo(p)


func _atualizar_raiva(dt: float) -> void:
	var pj := jogador()
	var aura_calma: bool = pj.visivel and energia / maxf(0.001, E_MAX) > 0.8
	for p in pessoas:
		if p.tipo != "paciente" or p.fase in ["saindo", "saiu"]:
			continue
		if not p.visivel or p.oculto:
			continue
		var esperando: bool = p.fase in ["fila_guiche", "indo_fila_guiche", "sentado", "em_pe", "na_sala", "indo_cadeira", "indo_em_pe"]
		if esperando:
			var taxa := RAIVA_ESPERA
			if p.fase in ["fila_guiche", "indo_fila_guiche"] or fila_guiche.size() > 3:
				taxa += RAIVA_FILA
			p.raiva = minf(100.0, p.raiva + taxa * dt)
		if aura_calma and p.pos.distance_to(pj.pos) < 190.0:
			p.raiva = maxf(0.0, p.raiva - 0.45 * dt)
		if p.prox_reclamacao > 0.0 and tempo >= p.prox_reclamacao:
			p.reclamou = false
			p.prox_reclamacao = 0.0
		if p.raiva >= RAIVA_ABANDONO:
			if p.fase not in ["no_guiche", "no_recepcao", "no_recepcao_player"] and p.atendimento_restante <= 0.0:
				_iniciar_saida(p, true)
				continue
		var pode_reclamar: bool = p.fase in ["fila_guiche", "indo_fila_guiche", "sentado", "em_pe", "indo_cadeira", "indo_em_pe"]
		if p.raiva >= RAIVA_RECLAMAR and not p.reclamou and pode_reclamar:
			_iniciar_reclamacao(p)
# =================================================================== reclamacoes

func _alvo_reclamacao(p: Dictionary) -> Dictionary:
	var melhor = null
	var dist := 1e20
	var pj := jogador()
	if pj.visivel and estado != Estado.NO_PC:
		var d: float = p.pos.distance_to(pj.pos)
		if d < dist:
			dist = d
			melhor = pj
	for q in pessoas:
		if q.tipo in ["jogador", "paciente", "crianca"] or q.oculto or not q.visivel:
			continue
		if q.fase in ["saindo", "saiu", "externo"]:
			continue
		var dq: float = p.pos.distance_to(q.pos)
		if dq < dist:
			dist = dq
			melhor = q
	if melhor == null:
		return {"pos": p.pos, "id": ""}
	return {"pos": melhor.pos, "id": melhor.id}


func _iniciar_reclamacao(p: Dictionary) -> void:
	if p.fase in ["indo_reclamar", "reclamando", "saindo", "saiu"]:
		return
	p.quer_reclamar = false
	p.retorno_fase = str(p.fase)
	_liberar_assento(p)
	_remover_filas(p)
	var alvo := _alvo_reclamacao(p)
	p.fase = "indo_reclamar"
	var ponto: Vector2 = alvo.pos + Vector2(DISTANCIA_LADO, 0)
	if not nav.ponto_livre(ponto):
		ponto = alvo.pos + Vector2(-DISTANCIA_LADO, 0)
	_mover_para(p, ponto, {"tipo": "reclamar", "alvo": str(alvo.id)}, true)
	_forcar_balao(p, "raiva", 3.0)


func _ao_chegar_reclamar(p: Dictionary) -> void:
	var melhor = null
	var dist := 1e20
	var pj := jogador()
	if pj.visivel:
		var d: float = p.pos.distance_to(pj.pos)
		if d < dist:
			dist = d
			melhor = pj
	for q in pessoas:
		if q.tipo in ["jogador", "paciente", "crianca"] or q.oculto or not q.visivel:
			continue
		if q.fase in ["saindo", "saiu", "externo"]:
			continue
		var dq: float = p.pos.distance_to(q.pos)
		if dq < dist:
			dist = dq
			melhor = q
	if melhor != null and dist < 120.0:
		if melhor.tipo == "jogador":
			energia = maxf(0.0, energia - RAIVA_ENERGIA)
		else:
			melhor.energia = maxf(0.0, float(melhor.energia) - RAIVA_ENERGIA)
	p.raiva = maxf(0.0, p.raiva - 45.0)
	p.reclamou = true
	p.prox_reclamacao = tempo + 18.0
	p.fase = "reclamando"
	p.visita_ate = tempo + 1.0
	inc("reclamacoes")
	som("reclamacao")
	alerta("%s reclamou do atendimento e cansou a equipe." % p.nome, 3.5)
	_forcar_balao(p, "raiva", 2.5)
	if str(p.destino_tipo) == "recepcao":
		if not fila_recepcao.has(p.id):
			fila_recepcao.append(p.id)
		_ir_esperar(p)
	elif str(p.destino_tipo) == "sala":
		_ir_esperar(p)
	elif p.admitido:
		_iniciar_saida(p, false)
	else:
		_entrar_fila_guiche(p)


func _atualizar_computadores(dt: float) -> void:
	agenda_pcs -= dt
	if agenda_pcs <= 0.0:
		agenda_pcs = ri.randf_range(PC_INTERVALO_MIN, PC_INTERVALO_MAX)
		_sortear_modo_pcs()
	agenda_problema -= dt
	if agenda_problema <= 0.0:
		agenda_problema = ri.randf_range(PC_PROBLEMA_MIN, PC_PROBLEMA_MAX)
		if ri.randf() < PC_PROBLEMA_CHANCE:
			var internos_ok := 0
			for pc in pcs:
				if pc.tipo == "interno" and pc.problema == "":
					internos_ok += 1
			var livres: Array = []
			for pc in pcs:
				if pc.problema != "" or pc.jogador:
					continue
				if pc.tipo == "interno" and internos_ok <= 1:
					continue
				livres.append(pc)
			if not livres.is_empty():
				var pc = livres[ri.randi_range(0, livres.size() - 1)]
				var grave := ri.randf() < 0.35
				pc.problema = "grave" if grave else "leve"
				pc.problema_ate = 0.0
				alerta(_txt("avisos", "pc_quebrado", "Um computador apresentou problema. Conserte clicando nele."), 3.2)
				som("alerta")
				if grave:
					if pc.jogador or (estado == Estado.NO_PC and foco == pc):
						alerta(_txt("avisos", "pc_quebrado", "Este computador está com problema grave."), 2.5)
						var p := jogador()
						_sair_do_pc()
						estado = Estado.CAMINHANDO
						_mover_para(p, pc.assento + Vector2(-42, 30), {"tipo": "chegada_livre"}, true)
					elif pc.ocupante != "":
						var f = _pessoa(str(pc.ocupante))
						if f != null:
							f.no_pc = ""
							f.posto_tipo = "livre"
							f.sentado = false
							pc.ocupante = ""
							pc.atendimento_id = ""
							_voltar_ao_posto(f)


# =================================================================== baloes

func _forcar_balao(p: Dictionary, tipo: String, dur: float = 2.0) -> void:
	p.balao_tipo = tipo
	p.balao_ate = tempo + dur


func _balao_para(p: Dictionary) -> String:
	if p.demanda != null:
		return "exclamacao"
	if p.raiva >= RAIVA_RECLAMAR:
		return "raiva"
	if p.tipo == "paciente":
		return "duvida"
	if p.tipo == "crianca":
		return "sorriso"
	if p.energia / maxf(0.001, p.max_energia) < 0.3:
		return "cansado"
	if p.fase == "na_copa":
		return "cafe"
	return "sorriso"


func _atualizar_baloes(dt: float) -> void:
	for p in pessoas:
		if p.balao_ate <= 0.0:
			continue
		p.balao_ate -= dt
		if p.balao_ate <= 0.0 and p.demanda == null and p.papo == null:
			p.balao_tipo = ""
	# Balões ambientes, sem palavras.
	for p in pessoas:
		if p.oculto or not p.visivel or p.balao_tipo != "" or p.demanda != null or p.papo != null:
			continue
		if p.fase in ["saindo", "saiu", "aguardando_entrada", "externo", "atendendo", "indo_atender", "auxiliando"]:
			continue
		if ri.randf() < 0.0025 * dt:
			var icones := ["coracao", "sorriso", "duvida", "relogio"]
			if p.tipo in ["funcionario_sala", "recepcao", "acs", "guiche"]:
				icones = ["coracao", "sorriso", "relogio", "cafe"]
			_forcar_balao(p, str(icones[ri.randi_range(0, icones.size() - 1)]), ri.randf_range(1.5, 3.0))


# =================================================================== papo de corredor

func _funcionario_de_papo(p: Dictionary) -> bool:
	return str(p.tipo) in ["funcionario_sala", "guiche", "recepcao", "acs"]


func _pessoa_de_papo(p: Dictionary) -> bool:
	return _funcionario_de_papo(p) or str(p.tipo) == "paciente"


func _categoria_papo(p: Dictionary) -> String:
	if str(p.tipo) == "paciente":
		return "paciente"
	var c := str(p.cargo_key)
	if c in ["chefe", "medica", "enfermeira", "guiche", "recepcao", "acs", "vacina", "procedimentos"]:
		return c
	return "equipe"


func _pode_papo(p: Dictionary) -> bool:
	if not _pessoa_de_papo(p):
		return false
	if modal != null:
		return false
	if p.papo != null or p.demanda != null:
		return false
	if not p.visivel or p.oculto or not p.entrou:
		return false
	if str(p.servindo) != "":
		return false
	if p.fase in ["saindo", "saiu", "externo", "entrando", "aguardando_entrada", "atendendo",
			"auxiliando", "indo_atender", "indo_abordar_jogador", "abordando_jogador"]:
		return false
	if str(p.tipo) == "paciente":
		if p.fase not in ["sentado", "em_pe", "fila_guiche"]:
			return false
	else:
		if float(p.energia) / maxf(0.001, float(p.max_energia)) < 0.35:
			return false
	return jogador().visivel


func _atualizar_papos(_dt: float) -> void:
	var ativos := 0
	for p in pessoas:
		if p.papo == null:
			continue
		ativos += 1
		var d: Dictionary = p.papo
		if tempo >= float(d.get("ate", 0.0)):
			inc("papos_perdidos")
			_encerrar_papo(p, false)
			ativos -= 1
	if ativos >= PAPO_MAX_ATIVOS:
		return
	for p in pessoas:
		if p.papo != null or not _pessoa_de_papo(p):
			continue
		if float(p.prox_papo) <= 0.0 or tempo < float(p.prox_papo):
			continue
		if not _pode_papo(p):
			continue
		if _abrir_papo_ambiente(p):
			ativos += 1
			if ativos >= PAPO_MAX_ATIVOS:
				break


func _abrir_papo_ambiente(p: Dictionary) -> bool:
	var categoria := _categoria_papo(p)
	var lista: Array = papos_def.get(categoria, [])
	if lista.is_empty():
		lista = papos_def.get("equipe", [])
	if lista.is_empty():
		return false
	var validas: Array = []
	for e in lista:
		if e is Dictionary and str(e.get("id", "")) != str(p.ultimo_papo):
			validas.append(e)
	if validas.is_empty():
		validas = lista
	var base: Dictionary = validas[ri.randi_range(0, validas.size() - 1)]
	var d: Dictionary = base.duplicate(true)
	d["ate"] = tempo + PAPO_DURACAO
	p.papo = d
	p.balao_tipo = "pergunta" if str(d.get("tipo", "fala")) == "pergunta" else "fala"
	p.balao_ate = tempo + PAPO_DURACAO
	p.prox_papo = 0.0
	inc("papos_surgidos")
	return true


func abrir_papo(p: Dictionary) -> bool:
	if p == null or modal != null:
		return false
	if p.papo == null or not p.visivel or p.oculto:
		return false
	var d: Dictionary = p.papo
	var opcoes: Array = []
	for op in d.get("opcoes", []):
		opcoes.append({"texto": str(op.get("texto", ""))})
	if opcoes.is_empty():
		return false
	var antes := estado
	var eh_paciente := str(p.tipo) == "paciente"
	estado = Estado.CONVERSANDO
	modal = {
		"nome": str(p.nome), "cargo": str(p.cargo), "texto": str(d.get("texto", "")),
		"opcoes": opcoes, "alvo_id": str(p.id), "cor": str(p.roupa),
		"tipo": "papo", "estado_antes": antes, "fase": "pergunta",
		"id_papo": str(d.get("id", "")),
		"titulo": "Conversa na espera" if eh_paciente else "Papo de corredor",
		"papo_paciente": eh_paciente, "fundido": "",
	}
	inc("papos_abertos")
	if bool(p.get("animal", false)):
		inc("papos_animais")
	som("papo")
	return true


func _responder_papo(i: int) -> void:
	if modal == null or str(modal.get("tipo", "")) != "papo":
		return
	if str(modal.get("fase", "")) == "resposta":
		fechar_dialogo()
		return
	var alvo = _pessoa(str(modal.get("alvo_id", "")))
	if alvo == null or alvo.papo == null:
		fechar_dialogo()
		return
	var opcoes: Array = alvo.papo.get("opcoes", [])
	if i < 0 or i >= opcoes.size():
		return
	var op: Dictionary = opcoes[i]
	modal["fase"] = "resposta"
	modal["texto"] = str(op.get("resposta", ""))
	modal["opcoes"] = [{"texto": "Entendi. Até mais!", "fechar": true}]
	modal["fundido"] = ""
	inc("papos_respondidos")
	som("papo")


func _encerrar_papo(p: Dictionary, respondeu: bool) -> void:
	var d = p.papo
	if d == null:
		return
	p.papo = null
	p.ultimo_papo = str(d.get("id", ""))
	p.prox_papo = tempo + ri.randf_range(PAPO_MIN, PAPO_MAX)
	if str(p.balao_tipo) in ["fala", "pergunta"]:
		p.balao_tipo = ""
		p.balao_ate = 0.0
	if respondeu and p.visivel and not p.oculto:
		_forcar_balao(p, "coracao", 2.0)
