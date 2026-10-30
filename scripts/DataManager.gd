extends RefCounted

const ARQUIVOS := {
	"config": "res://data/config.json",
	"layout": "res://data/layout.json",
	"npcs": "res://data/npcs.json",
	"demandas": "res://data/demandas.json",
	"papos": "res://data/papos.json",
	"textos": "res://data/textos.json",
}

var config: Dictionary = {}
var layout: Dictionary = {}
var npcs: Dictionary = {}
var demandas: Dictionary = {}
var papos: Dictionary = {}
var textos: Dictionary = {}
var erros: PackedStringArray = []


func carregar() -> bool:
	erros.clear()
	for chave in ARQUIVOS:
		var caminho: String = ARQUIVOS[chave]
		var dados: Variant = _ler_json(caminho)
		if dados == null:
			continue
		set(chave, dados)
	_validar_essenciais()
	return erros.is_empty()


func _ler_json(caminho: String) -> Variant:
	if not FileAccess.file_exists(caminho):
		erros.append("Arquivo nao encontrado: " + caminho)
		return null
	var arquivo := FileAccess.open(caminho, FileAccess.READ)
	if arquivo == null:
		erros.append("Nao consegui abrir: " + caminho)
		return null
	var texto := arquivo.get_as_text()
	arquivo.close()
	var dados: Variant = JSON.parse_string(texto)
	if dados == null or not (dados is Dictionary):
		erros.append("JSON invalido em " + caminho + ". Verifique virgulas e aspas.")
		return null
	return dados


func _validar_essenciais() -> void:
	var recurso: Dictionary = config.get("recurso", {})
	for chave in ["energia_max", "tempo_tarefa_s", "custo_tarefa"]:
		if not recurso.has(chave):
			erros.append("config.json sem recurso." + chave)
	if layout.get("pcs", []).is_empty():
		erros.append("layout.json sem pcs")
	if layout.get("salas", []).is_empty():
		erros.append("layout.json sem salas")
	var salas_ids := {}
	for sala in layout.get("salas", []):
		salas_ids[sala.get("id", "")] = true
	for funcionario in npcs.get("funcionarios_sala", []):
		var sala_id: String = str(funcionario.get("sala", ""))
		if not salas_ids.has(sala_id):
			erros.append("npcs.json: funcionario '" + str(funcionario.get("id")) + "' aponta para sala inexistente '" + sala_id + "'")
	var grupos := ["chefe", "medica", "enfermeira", "funcionarios", "pacientes"]
	var total := 0
	for grupo in grupos:
		total += demandas.get(grupo, []).size()
	if total == 0:
		erros.append("demandas.json sem demandas")
	var total_papos := 0
	for grupo in papos.keys():
		total_papos += (papos[grupo] as Array).size()
	if total_papos == 0:
		erros.append("papos.json sem conversas de corredor")
	for pc in layout.get("pcs", []):
		if not salas_ids.has(str(pc.get("sala", ""))) and str(pc.get("tipo", "")) == "sala":
			erros.append("layout.json: computador '" + str(pc.get("id")) + "' aponta para sala inexistente")
