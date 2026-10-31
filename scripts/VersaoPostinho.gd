class_name VersaoPostinho
## Versão exibida no app: fiel ao pacote instalado, não um texto fixo.
##
## Ordem de leitura:
##   1. version.json carimbado no build (fonte da verdade do repositório);
##   2. PackageManager do Android, quando devolve um nome válido, para confirmar
##      o pacote realmente instalado (versionName/versionCode);
##   3. application/config/version do projeto, como último recurso no editor.
##
## O jogo não tem host nativo próprio: no Windows a versão carimbada no build é
## a versão do MSIX (por exemplo, 1.0.1.0). No Android o PackageManager confirma o valor
## quando o JNI entrega uma string utilizável; caso contrário, o version.json
## carimbado no PCK continua valendo.

const ARQUIVO := "res://version.json"
const VERSAO_PADRAO := "1.0.1"

static var _cache: Dictionary = {}
static var _lido := false


static func info() -> Dictionary:
	if _lido:
		return _cache
	_lido = true
	_cache = _ler_arquivo()
	var android := _ler_android()
	if not android.is_empty():
		_cache["versao"] = str(android.get("nome", _cache.get("versao", VERSAO_PADRAO)))
		_cache["codigo"] = int(android.get("codigo", _cache.get("codigo", 1)))
		_cache["origem"] = "android"
	return _cache


static func texto() -> String:
	return "v" + str(info().get("versao", VERSAO_PADRAO))


static func completo() -> String:
	var dados := info()
	return "Versão %s (build %d)" % [
		str(dados.get("versao", VERSAO_PADRAO)),
		int(dados.get("codigo", 1)),
	]


static func _ler_arquivo() -> Dictionary:
	var padrao := {
		"versao": str(ProjectSettings.get_setting("application/config/version", VERSAO_PADRAO)),
		"codigo": 1,
		"origem": "projeto",
	}
	if not FileAccess.file_exists(ARQUIVO):
		return padrao
	var arq := FileAccess.open(ARQUIVO, FileAccess.READ)
	if arq == null:
		return padrao
	var texto_json := arq.get_as_text()
	arq.close()
	var dados = JSON.parse_string(texto_json)
	if typeof(dados) != TYPE_DICTIONARY:
		return padrao
	if not dados.has("versao") or str(dados["versao"]).is_empty():
		return padrao
	return {
		"versao": str(dados.get("versao", padrao["versao"])),
		"codigo": int(dados.get("codigo", 1)),
		"windows": str(dados.get("windows", "")),
		"android": str(dados.get("android", "")),
		"canal": str(dados.get("canal", "release")),
		"origem": "version.json",
	}


static func _ler_android() -> Dictionary:
	# Fora do Android o singleton nem existe; no editor não há o que corrigir.
	if not OS.has_feature("android"):
		return {}
	if not Engine.has_singleton("AndroidRuntime"):
		return {}
	var runtime = Engine.get_singleton("AndroidRuntime")
	if runtime == null:
		return {}
	var contexto = runtime.getApplicationContext()
	if contexto == null:
		return {}
	var gerenciador = contexto.getPackageManager()
	if gerenciador == null:
		return {}
	var pacote := str(contexto.getPackageName())
	if pacote.is_empty():
		return {}
	var dados = gerenciador.getPackageInfo(pacote, 0)
	if dados == null:
		return {}
	var nome := nome_valido(dados.versionName)
	if nome.is_empty():
		return {}
	# versionCode é campo int desde a API 1; evita getLongVersionCode (API 28+)
	# e mantém o minSdk 24.
	var codigo := int(dados.versionCode)
	if codigo <= 0:
		codigo = int(_cache.get("codigo", 1))
	return {"nome": nome, "codigo": codigo}


static func nome_valido(valor) -> String:
	# O JNI pode devolver <null> ou um objeto Java em vez de String. Só aceita
	# texto numérico; caso contrário, o version.json do build permanece.
	if not (valor is String or valor is StringName):
		return ""
	var texto := str(valor).strip_edges()
	if texto.is_empty():
		return ""
	var regex := RegEx.new()
	regex.compile("^[0-9]+(\\.[0-9]+){1,3}$")
	if regex.search(texto) == null:
		return ""
	return texto
