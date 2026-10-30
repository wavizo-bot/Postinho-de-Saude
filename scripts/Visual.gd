extends RefCounted
## Desenho procedural dos "feijoezinhos" e de pequenos elementos de interface.
## Nao conhece as regras do jogo: recebe dicionarios de pessoa e desenha.
##
## Os personagens usam um corpo-capsula unico, com rosto aplicado na propria
## capsula. Isso evita a leitura de "cabeca redonda separada" e deixa o
## conjunto mais proximo de um feijao fofo e volumoso.

const C_BRANCO := Color("#ffffff")
const C_PRETO := Color("#1c1d24")
const C_PUPILA := Color("#24252e")
const C_BOCA := Color("#5a2b31")
const C_BLUSH := Color("#ef8f9b")
const C_CONTORNO := Color("#25242c")
const C_FOLHA := Color("#f7f5ea")


static func elipse(ci: CanvasItem, centro: Vector2, rx: float, ry: float, cor: Color, preenchido: bool = true) -> void:
	if rx <= 0.01 or ry <= 0.01:
		return
	ci.draw_set_transform(centro, 0.0, Vector2(1.0, ry / rx))
	if preenchido:
		ci.draw_circle(Vector2.ZERO, rx, cor, true, -1.0, true)
	else:
		ci.draw_arc(Vector2.ZERO, rx, 0.0, TAU, 28, cor, 1.5, true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func retangulo_arredondado(ci: CanvasItem, r: Rect2, cor: Color, raio: float = 8.0) -> void:
	var rr := minf(raio, minf(r.size.x, r.size.y) * 0.5)
	if rr <= 0.5:
		ci.draw_rect(r, cor, true)
		return
	ci.draw_rect(Rect2(r.position + Vector2(rr, 0), Vector2(r.size.x - rr * 2.0, r.size.y)), cor, true)
	ci.draw_rect(Rect2(r.position + Vector2(0, rr), Vector2(r.size.x, r.size.y - rr * 2.0)), cor, true)
	ci.draw_circle(r.position + Vector2(rr, rr), rr, cor, true, -1.0, true)
	ci.draw_circle(r.position + Vector2(r.size.x - rr, rr), rr, cor, true, -1.0, true)
	ci.draw_circle(r.position + Vector2(rr, r.size.y - rr), rr, cor, true, -1.0, true)
	ci.draw_circle(r.position + Vector2(r.size.x - rr, r.size.y - rr), rr, cor, true, -1.0, true)


static func contorno_arredondado(ci: CanvasItem, r: Rect2, cor: Color, raio: float = 8.0, largura: float = 2.0) -> void:
	var rr := minf(raio, minf(r.size.x, r.size.y) * 0.5)
	if rr <= 0.5:
		ci.draw_rect(r, cor, false, largura)
		return
	ci.draw_line(r.position + Vector2(rr, 0), r.position + Vector2(r.size.x - rr, 0), cor, largura, true)
	ci.draw_line(r.position + Vector2(rr, r.size.y), r.position + Vector2(r.size.x - rr, r.size.y), cor, largura, true)
	ci.draw_line(r.position + Vector2(0, rr), r.position + Vector2(0, r.size.y - rr), cor, largura, true)
	ci.draw_line(r.position + Vector2(r.size.x, rr), r.position + Vector2(r.size.x, r.size.y - rr), cor, largura, true)
	ci.draw_arc(r.position + Vector2(rr, rr), rr, PI, PI * 1.5, 10, cor, largura, true)
	ci.draw_arc(r.position + Vector2(r.size.x - rr, rr), rr, PI * 1.5, TAU, 10, cor, largura, true)
	ci.draw_arc(r.position + Vector2(r.size.x - rr, r.size.y - rr), rr, 0.0, PI * 0.5, 10, cor, largura, true)
	ci.draw_arc(r.position + Vector2(rr, r.size.y - rr), rr, PI * 0.5, PI, 10, cor, largura, true)


static func _capsula(ci: CanvasItem, cima: Vector2, baixo: Vector2, raio: float, cor: Color) -> void:
	var topo := minf(cima.y, baixo.y)
	var fundo := maxf(cima.y, baixo.y)
	ci.draw_rect(Rect2(Vector2(cima.x - raio, topo), Vector2(raio * 2.0, fundo - topo)), cor, true)
	ci.draw_circle(cima, raio, cor, true, -1.0, true)
	ci.draw_circle(baixo, raio, cor, true, -1.0, true)


static func sombra(ci: CanvasItem, base: Vector2, escala: float, largura: float = 9.0) -> void:
	# Duas camadas deixam a sombra macia, sem parecer um disco chapado.
	elipse(ci, base + Vector2(0, 10.5) * escala, largura * 1.35 * escala, 4.2 * escala,
		Color(0.06, 0.07, 0.09, 0.075))
	elipse(ci, base + Vector2(0, 9.3) * escala, largura * escala, 2.9 * escala,
		Color(0.06, 0.07, 0.09, 0.22))


static func pessoa(ci: CanvasItem, p: Dictionary, t: float, escala_extra: float = 1.0, aura: bool = false) -> void:
	if p.is_empty() or not bool(p.get("visivel", true)) or bool(p.get("oculto", false)):
		return
	var base: Vector2 = p.get("pos", Vector2.ZERO)
	var s: float = escala_extra * float(p.get("escala", 1.0))
	var sentado := bool(p.get("sentado", false))
	var andando := bool(p.get("andando", false))
	var walk := float(p.get("walk_phase", 0.0))
	var swing := sin(walk * 2.35)
	var fase := str(p.get("fase", ""))
	var tipo := str(p.get("tipo", ""))
	var jogador := tipo == "jogador"
	var crianca := tipo == "crianca"
	var funcionario := tipo in ["funcionario_sala", "guiche", "recepcao", "acs"]
	var raiva := float(p.get("raiva", 0.0))
	var trabalha := bool(p.get("em_esforco", false)) or fase in ["trabalhando", "atendendo", "auxiliando"] or (jogador and str(p.get("no_pc", "")) != "")
	var esforco := bool(p.get("em_esforco", false))
	var fase_anim := t * 2.0 + float(abs(hash(str(p.get("id", "")))) % 100) * 0.13
	var diam := 1.0 if not crianca else 0.97

	var bob := sin(fase_anim) * 0.55
	var sway := 0.0
	if andando:
		var passo := walk * 2.15
		swing = sin(passo)
		bob = absf(swing) * 1.9
		sway = sin(passo * 0.5) * 0.65
	elif trabalha:
		bob = absf(sin(t * (17.0 if esforco else 9.0))) * 0.75
		if esforco:
			sway = sin(t * 27.0) * 0.35

	var cor_roupa := Color(str(p.get("roupa", "#7a8a99")))
	var cor_roupa2 := Color(str(p.get("roupa2", "#eef2f4")))
	var cor_calca := Color(str(p.get("calca", "#34404d")))
	var cor_pele := Color(str(p.get("pele", "#d69f7e")))
	var cor_cabelo := Color(str(p.get("cabelo", "#2b1b17")))
	var cor_sapato := Color(str(p.get("sapato", "#2b2d42")))
	var facing: int = 1 if int(p.get("facing", 1)) >= 0 else -1
	var especie := str(p.get("especie", "humano"))
	var animal := bool(p.get("animal", false)) or especie != "humano"

	sombra(ci, base, s, 12.0 if not crianca else 8.5)
	if aura:
		var pulso := 0.5 + 0.5 * sin(t * 5.0)
		elipse(ci, base + Vector2(0, 5) * s, (20.0 + pulso * 3.5) * s, 7.5 * s,
			Color(0.92, 0.28, 0.18, 0.18 + pulso * 0.10))
	if jogador and float(p.get("energia", 0.0)) / maxf(0.001, float(p.get("max_energia", 5.0))) > 0.8:
		var pulso2 := 0.5 + 0.5 * sin(t * 2.4)
		ci.draw_arc(base + Vector2(0, 4) * s, (18.5 + pulso2 * 2.0) * s, 0.0, TAU, 32,
			Color(0.98, 0.84, 0.28, 0.18 + pulso2 * 0.12), 1.6, true)

	var raiz := base + Vector2(sway, 0) * s
	var topo_corpo := raiz + Vector2(0, -36.0 + bob) * s
	var base_corpo := raiz + Vector2(0, -19.0 + bob) * s
	var raio_corpo := 13.4 * s * diam
	var rosto := topo_corpo + Vector2(0.9 * facing, 0.3) * s
	var face_rx := 9.95 * s * diam
	var face_ry := 9.9 * s

	# Cauda dos animais fica atras do corpo; humanos mantem o cabelo comprido.
	if animal:
		_cauda_animal(ci, especie, raiz, rosto, s, facing, cor_pele)
	else:
		_cabelo_tras(ci, str(p.get("estilo_cabelo", "curto")), raiz, rosto, s, facing, cor_cabelo)

	# Pernas curtas e sapatos, atras do corpo.
	var pe_esq := Vector2(-5.5, 0.0)
	var pe_dir := Vector2(5.5, 0.0)
	if sentado:
		pe_esq = Vector2(-4.8 + 7.2 * facing, -0.4)
		pe_dir = Vector2(4.8 + 7.2 * facing, 0.2)
	elif andando:
		pe_esq.x += swing * 3.1
		pe_dir.x -= swing * 3.1
		pe_esq.y -= maxf(0.0, -swing) * 1.5
		pe_dir.y -= maxf(0.0, swing) * 1.5
	var quadril_esq := raiz + Vector2(-4.7, -8.0 + bob) * s
	var quadril_dir := raiz + Vector2(4.7, -8.0 + bob) * s
	var pe_esq_w := raiz + pe_esq * s
	var pe_dir_w := raiz + pe_dir * s
	ci.draw_line(quadril_esq, pe_esq_w, Color(C_CONTORNO, 0.78), 4.8 * s, true)
	ci.draw_line(quadril_dir, pe_dir_w, Color(C_CONTORNO, 0.78), 4.8 * s, true)
	ci.draw_line(quadril_esq, pe_esq_w, cor_calca, 3.1 * s, true)
	ci.draw_line(quadril_dir, pe_dir_w, cor_calca, 3.1 * s, true)
	elipse(ci, pe_esq_w + Vector2(0.7 * facing, 0.4) * s, 3.5 * s, 2.3 * s, Color(C_CONTORNO, 0.75))
	elipse(ci, pe_dir_w + Vector2(0.7 * facing, 0.4) * s, 3.5 * s, 2.3 * s, Color(C_CONTORNO, 0.75))
	elipse(ci, pe_esq_w + Vector2(0.7 * facing, 0.2) * s, 3.0 * s, 1.8 * s, cor_sapato)
	elipse(ci, pe_dir_w + Vector2(0.7 * facing, 0.2) * s, 3.0 * s, 1.8 * s, cor_sapato)
	ci.draw_line(pe_esq_w + Vector2(-1.6, -0.8) * s, pe_esq_w + Vector2(1.6, -0.8) * s, Color(1, 1, 1, 0.22), 0.9 * s, true)
	ci.draw_line(pe_dir_w + Vector2(-1.6, -0.8) * s, pe_dir_w + Vector2(1.6, -0.8) * s, Color(1, 1, 1, 0.22), 0.9 * s, true)

	# Capsula unica: contorno, corpo e brilho.
	_capsula(ci, topo_corpo + Vector2(0, 1.2) * s, base_corpo + Vector2(0, 1.6) * s, raio_corpo + 1.25 * s,
		Color(C_CONTORNO, 0.82))
	_capsula(ci, topo_corpo, base_corpo, raio_corpo, cor_roupa)
	# Sombra suave no lado direito/baixo e luz no alto/esquerda.
	elipse(ci, base_corpo + Vector2(4.6, 0.8) * s, 6.6 * s, 6.0 * s, Color(0, 0, 0, 0.10))
	elipse(ci, topo_corpo + Vector2(-3.9, 2.7) * s, 5.0 * s, 6.8 * s, Color(1, 1, 1, 0.16))
	ci.draw_arc(topo_corpo, raio_corpo - 0.9 * s, PI * 1.04, PI * 1.94, 22,
		Color(1, 1, 1, 0.12), 1.6 * s, true)
	# Linha de luz na base, como um tecido macio pegando luz.
	ci.draw_arc(base_corpo, raio_corpo - 1.4 * s, PI * 0.16, PI * 0.84, 18,
		Color(1, 1, 1, 0.10), 1.4 * s, true)

	_detalhes_roupa(ci, p, raiz, rosto, s, jogador, funcionario, crianca, facing,
		cor_roupa, cor_roupa2, cor_calca)

	# Bracos curtos e expressivos.
	var mao_esq := Vector2(-14.8, -17.0)
	var mao_dir := Vector2(14.8, -17.0)
	if andando:
		mao_esq.y += swing * 2.1
		mao_dir.y -= swing * 2.1
	elif trabalha:
		var digitando := sin(t * (20.0 if esforco else 11.0))
		mao_esq = Vector2(7.6 * facing, -22.4 + digitando * 1.0)
		mao_dir = Vector2(10.2 * facing, -21.4 - digitando * 1.0)
	elif sentado:
		mao_esq = Vector2(-12.8, -18.4)
		mao_dir = Vector2(12.8, -18.4)
	elif crianca:
		mao_esq = Vector2(-12.6, -17.8)
		mao_dir = Vector2(12.6, -17.8)
	var ombro_esq := raiz + Vector2(-10.7, (-28.4 if not trabalha else -27.0) + bob) * s
	var ombro_dir := raiz + Vector2(10.7, (-28.4 if not trabalha else -27.0) + bob) * s
	var mao_esq_w := raiz + mao_esq * s
	var mao_dir_w := raiz + mao_dir * s
	ci.draw_line(ombro_esq, mao_esq_w, Color(C_CONTORNO, 0.76), 5.2 * s, true)
	ci.draw_line(ombro_dir, mao_dir_w, Color(C_CONTORNO, 0.76), 5.2 * s, true)
	if jogador:
		# Manga curta azul do colete e braco amarelo aparecendo.
		var corte_esq := ombro_esq.lerp(mao_esq_w, 0.32)
		var corte_dir := ombro_dir.lerp(mao_dir_w, 0.32)
		ci.draw_line(ombro_esq, corte_esq, cor_roupa.darkened(0.05), 3.4 * s, true)
		ci.draw_line(ombro_dir, corte_dir, cor_roupa.darkened(0.05), 3.4 * s, true)
		ci.draw_line(corte_esq, mao_esq_w, cor_pele, 3.1 * s, true)
		ci.draw_line(corte_dir, mao_dir_w, cor_pele, 3.1 * s, true)
	else:
		ci.draw_line(ombro_esq, mao_esq_w, cor_roupa.darkened(0.05), 3.4 * s, true)
		ci.draw_line(ombro_dir, mao_dir_w, cor_roupa.darkened(0.05), 3.4 * s, true)
	ci.draw_circle(mao_esq_w, 2.45 * s, Color(C_CONTORNO, 0.76), true, -1.0, true)
	ci.draw_circle(mao_dir_w, 2.45 * s, Color(C_CONTORNO, 0.76), true, -1.0, true)
	ci.draw_circle(mao_esq_w, 1.95 * s, cor_pele, true, -1.0, true)
	ci.draw_circle(mao_dir_w, 1.95 * s, cor_pele, true, -1.0, true)
	if trabalha:
		ci.draw_line(mao_esq_w + Vector2(-0.7, -0.5) * s, mao_esq_w + Vector2(0.7, -0.8) * s,
			Color(cor_pele.darkened(0.28), 0.55), 0.55 * s, true)
		ci.draw_line(mao_dir_w + Vector2(-0.7, -0.9) * s, mao_dir_w + Vector2(0.7, -0.4) * s,
			Color(cor_pele.darkened(0.28), 0.55), 0.55 * s, true)

	# Orelhas e chifres ficam atras do rosto, aplicados na capsula.
	if animal:
		_orelhas_animal(ci, especie, rosto, s, facing, cor_pele)

	# Rosto aplicado na capsula, sem uma cabeca separada.
	elipse(ci, rosto, face_rx, face_ry, cor_pele)
	elipse(ci, rosto + Vector2(0, 3.0) * s, face_rx * 0.72, face_ry * 0.38,
		Color(cor_pele.darkened(0.035), 0.34))
	elipse(ci, rosto + Vector2(-2.7, -2.1) * s, face_rx * 0.52, face_ry * 0.50,
		Color(1, 1, 1, 0.10))

	var olho_y := rosto.y - 1.35 * s
	var olho_dx := 4.2 * s
	var olho_esq := Vector2(rosto.x - olho_dx, olho_y)
	var olho_dir := Vector2(rosto.x + olho_dx, olho_y)
	var pisca := fmod(fase_anim * 0.34 + float(abs(hash(str(p.get("id", ""))) % 17)) * 0.31, 4.2) > 4.05
	var olho_rx := (1.3 if not crianca else 1.4) * s
	var olho_ry := (2.4 if not crianca else 2.25) * s
	if pisca and raiva < 62.0:
		ci.draw_line(olho_esq + Vector2(-1.0, 0) * s, olho_esq + Vector2(1.0, 0) * s, C_PUPILA, 0.9 * s, true)
		ci.draw_line(olho_dir + Vector2(-1.0, 0) * s, olho_dir + Vector2(1.0, 0) * s, C_PUPILA, 0.9 * s, true)
	else:
		elipse(ci, olho_esq, olho_rx, olho_ry * (0.84 if raiva >= 62.0 else 1.0), C_PUPILA)
		elipse(ci, olho_dir, olho_rx, olho_ry * (0.84 if raiva >= 62.0 else 1.0), C_PUPILA)
		ci.draw_circle(olho_esq + Vector2(-0.36, -0.8) * s, 0.48 * s, Color(1, 1, 1, 0.92), true, -1.0, true)
		ci.draw_circle(olho_dir + Vector2(-0.36, -0.8) * s, 0.48 * s, Color(1, 1, 1, 0.92), true, -1.0, true)
		ci.draw_circle(olho_esq + Vector2(0.35, 0.95) * s, 0.26 * s, Color(1, 1, 1, 0.42), true, -1.0, true)
		ci.draw_circle(olho_dir + Vector2(0.35, 0.95) * s, 0.26 * s, Color(1, 1, 1, 0.42), true, -1.0, true)
	if raiva >= 62.0:
		ci.draw_line(olho_esq + Vector2(-1.45, -2.7) * s, olho_esq + Vector2(1.25, -1.9) * s,
			C_PUPILA, 0.8 * s, true)
		ci.draw_line(olho_dir + Vector2(-1.25, -1.9) * s, olho_dir + Vector2(1.45, -2.7) * s,
			C_PUPILA, 0.8 * s, true)

	var blush := 0.20 if raiva < 62.0 else 0.34
	elipse(ci, rosto + Vector2(-6.4, 3.6) * s, 1.6 * s, 1.1 * s, Color(C_BLUSH.r, C_BLUSH.g, C_BLUSH.b, blush))
	elipse(ci, rosto + Vector2(6.4, 3.6) * s, 1.6 * s, 1.1 * s, Color(C_BLUSH.r, C_BLUSH.g, C_BLUSH.b, blush))

	if animal:
		_rosto_animal(ci, especie, rosto, s, facing, cor_pele)
	elif raiva >= 62.0:
		ci.draw_arc(rosto + Vector2(0, 6.0) * s, 1.9 * s, PI * 1.12, PI * 1.88, 14, C_BOCA, 0.8 * s, true)
	elif trabalha or andando:
		ci.draw_arc(rosto + Vector2(0, 4.4) * s, 1.3 * s, 0.05, PI - 0.05, 12, C_BOCA, 0.75 * s, true)
	else:
		ci.draw_arc(rosto + Vector2(0, 4.8) * s, 1.7 * s, 0.12, PI - 0.12, 14, C_BOCA, 0.7 * s, true)

	# Franja, chapeu e acessorios por cima do rosto.
	if not animal:
		_cabelo_frente(ci, str(p.get("estilo_cabelo", "curto")), rosto, cor_cabelo, s, facing)
	_chapeu(ci, str(p.get("chapeu", "nenhum")), rosto, s, facing, cor_roupa.darkened(0.18))
	_acessorio(ci, str(p.get("acessorio", "nenhum")), rosto, s, facing)


static func _cauda_animal(ci: CanvasItem, especie: String, raiz: Vector2, _rosto: Vector2, s: float,
		facing: int, cor: Color) -> void:
	var base := raiz + Vector2(-12.0 * facing, -20.0) * s
	match especie:
		"gato":
			var pts := PackedVector2Array([
				base,
				base + Vector2(-7.0 * facing, -1.0) * s,
				base + Vector2(-10.5 * facing, 4.5) * s,
				base + Vector2(-9.0 * facing, 10.0) * s,
			])
			ci.draw_polyline(pts, cor.darkened(0.08), 2.6 * s, true)
		"raposa":
			var pts2 := PackedVector2Array([
				base,
				base + Vector2(-9.0 * facing, -2.0) * s,
				base + Vector2(-14.5 * facing, 4.5) * s,
				base + Vector2(-12.0 * facing, 12.0) * s,
			])
			ci.draw_polyline(pts2, cor.darkened(0.04), 4.6 * s, true)
			ci.draw_circle(pts2[3] + Vector2(1.0, 1.2) * s, 3.2 * s, Color("#f6ead8"), true, -1.0, true)
		"poodle":
			for i in 5:
				var p := base + Vector2(-i * 1.9 * facing, -2.2 + i * 2.1) * s
				ci.draw_circle(p, (2.8 - i * 0.28) * s, cor.darkened(0.02), true, -1.0, true)
		"coelho":
			ci.draw_circle(base + Vector2(-1.0 * facing, 1.0) * s, 3.2 * s, Color("#f7efe2"), true, -1.0, true)
		"capivara", "urso":
			elipse(ci, base + Vector2(0, 2.5) * s, 2.6 * s, 2.2 * s, cor.darkened(0.10))
		"tucano":
			for i in 3:
				var p2 := base + Vector2(-3.0 - i * 2.4, -2.0 + i * 3.2) * s
				ci.draw_line(p2, p2 + Vector2(-7.0 * facing, 2.0) * s, cor.darkened(0.12), 1.7 * s, true)
		"coruja":
			ci.draw_colored_polygon(PackedVector2Array([
				base + Vector2(2.0, -1.5) * s,
				base + Vector2(-3.0, 5.0) * s,
				base + Vector2(-8.0, 7.0) * s,
				base + Vector2(-2.5, 8.5) * s,
				base + Vector2(2.5, 4.0) * s,
			]), cor.darkened(0.10))
		"jacare":
			ci.draw_colored_polygon(PackedVector2Array([
				base + Vector2(3.0, -3.0) * s,
				base + Vector2(-10.0, -4.0) * s,
				base + Vector2(-18.0, 0.0) * s,
				base + Vector2(-10.0, 4.0) * s,
				base + Vector2(3.0, 3.0) * s,
			]), cor.darkened(0.10))
		_:
			ci.draw_circle(base + Vector2(0, 1.5) * s, 2.4 * s, cor.darkened(0.12), true, -1.0, true)


static func _orelhas_animal(ci: CanvasItem, especie: String, rosto: Vector2, s: float,
		facing: int, cor: Color) -> void:
	var rosa := Color("#e8a3a8")
	match especie:
		"gato", "raposa":
			for lado in [-1.0, 1.0]:
				var orelha := PackedVector2Array([
					rosto + Vector2(3.5 * lado, -6.0) * s,
					rosto + Vector2(9.6 * lado, -14.0) * s,
					rosto + Vector2(10.0 * lado, -4.0) * s,
				])
				ci.draw_colored_polygon(orelha, cor.darkened(0.06))
				var interna := PackedVector2Array([
					rosto + Vector2(5.6 * lado, -6.6) * s,
					rosto + Vector2(8.9 * lado, -11.4) * s,
					rosto + Vector2(9.0 * lado, -5.5) * s,
				])
				ci.draw_colored_polygon(interna, rosa)
		"coelho":
			for lado in [-1.0, 1.0]:
				elipse(ci, rosto + Vector2(5.0 * lado, -13.5) * s, 2.7 * s, 6.8 * s, cor)
				elipse(ci, rosto + Vector2(5.1 * lado, -13.6) * s, 1.45 * s, 5.1 * s, rosa)
		"capivara":
			for lado in [-1.0, 1.0]:
				ci.draw_circle(rosto + Vector2(7.2 * lado, -7.2) * s, 2.8 * s, cor.darkened(0.06), true, -1.0, true)
				ci.draw_circle(rosto + Vector2(7.2 * lado, -7.0) * s, 1.4 * s, cor.darkened(0.18), true, -1.0, true)
		"urso":
			for lado in [-1.0, 1.0]:
				ci.draw_circle(rosto + Vector2(7.5 * lado, -7.4) * s, 3.4 * s, cor.darkened(0.05), true, -1.0, true)
				ci.draw_circle(rosto + Vector2(7.5 * lado, -7.2) * s, 1.7 * s, rosa.darkened(0.10), true, -1.0, true)
		"poodle":
			for lado in [-1.0, 1.0]:
				elipse(ci, rosto + Vector2(9.2 * lado, -2.0) * s, 3.0 * s, 5.4 * s, cor.darkened(0.14))
			for i in 4:
				var ang := PI * 0.6 + float(i) * PI * 0.28
				ci.draw_circle(rosto + Vector2(cos(ang) * 8.0, sin(ang) * 7.2 - 5.5) * s,
					2.0 * s, cor.lightened(0.03), true, -1.0, true)
		"coruja":
			for lado in [-1.0, 1.0]:
				ci.draw_colored_polygon(PackedVector2Array([
					rosto + Vector2(4.0 * lado, -7.0) * s,
					rosto + Vector2(7.0 * lado, -13.5) * s,
					rosto + Vector2(9.0 * lado, -6.0) * s,
				]), cor.darkened(0.10))
		"sapo":
			for lado in [-1.0, 1.0]:
				ci.draw_circle(rosto + Vector2(6.2 * lado, -8.2) * s, 3.6 * s, cor.darkened(0.03), true, -1.0, true)
				ci.draw_circle(rosto + Vector2(6.2 * lado, -9.4) * s, 1.35 * s, C_PUPILA, true, -1.0, true)
		"tucano":
			ci.draw_colored_polygon(PackedVector2Array([
				rosto + Vector2(-4.0, -8.0) * s,
				rosto + Vector2(-1.0, -15.5) * s,
				rosto + Vector2(2.0, -8.5) * s,
				rosto + Vector2(5.0, -14.0) * s,
				rosto + Vector2(6.5, -7.0) * s,
			]), cor.darkened(0.12))
		"jacare":
			for lado in [-1.0, 1.0]:
				ci.draw_circle(rosto + Vector2(6.5 * lado, -8.4) * s, 2.6 * s, cor.darkened(0.09), true, -1.0, true)


static func _rosto_animal(ci: CanvasItem, especie: String, rosto: Vector2, s: float,
		facing: int, cor: Color) -> void:
	var claro := cor.lightened(0.18)
	var escuro := cor.darkened(0.28)
	match especie:
		"tucano":
			var bico := PackedVector2Array([
				rosto + Vector2(2.0 * facing, -1.4) * s,
				rosto + Vector2(17.0 * facing, 1.4) * s,
				rosto + Vector2(15.0 * facing, 5.6) * s,
				rosto + Vector2(2.0 * facing, 4.2) * s,
			])
			ci.draw_colored_polygon(bico, Color("#f2a03d"))
			ci.draw_line(rosto + Vector2(3.0 * facing, 3.5) * s, rosto + Vector2(15.0 * facing, 5.2) * s,
				Color("#c96b25"), 1.0 * s, true)
			ci.draw_circle(rosto + Vector2(11.0 * facing, 1.5) * s, 0.8 * s, Color("#7a3f18"), true, -1.0, true)
		"coruja":
			for lado in [-1.0, 1.0]:
				ci.draw_circle(rosto + Vector2(4.2 * lado, -1.2) * s, 5.4 * s, claro, true, -1.0, true)
				ci.draw_arc(rosto + Vector2(4.2 * lado, -1.2) * s, 5.4 * s, 0.0, TAU, 22,
					cor.darkened(0.20), 0.75 * s, true)
			ci.draw_colored_polygon(PackedVector2Array([
				rosto + Vector2(-1.8, 3.2) * s,
				rosto + Vector2(1.8, 3.2) * s,
				rosto + Vector2(0.0, 6.8) * s,
			]), Color("#d9a23d"))
		"sapo":
			ci.draw_arc(rosto + Vector2(0, 4.0) * s, 6.4 * s, 0.08, PI - 0.08, 18, C_BOCA, 0.85 * s, true)
			ci.draw_circle(rosto + Vector2(-2.2, 0.2) * s, 0.55 * s, escuro, true, -1.0, true)
			ci.draw_circle(rosto + Vector2(2.2, 0.2) * s, 0.55 * s, escuro, true, -1.0, true)
		"jacare":
			var focinho := rosto + Vector2(4.0 * facing, 4.2) * s
			elipse(ci, focinho, 10.4 * s, 4.6 * s, claro)
			ci.draw_arc(focinho + Vector2(1.5 * facing, 0.8) * s, 7.2 * s, 0.05, PI - 0.05, 18, C_BOCA, 0.9 * s, true)
			for i in 4:
				var x := -3.6 + i * 2.4
				ci.draw_colored_polygon(PackedVector2Array([
					focinho + Vector2(x, 1.4) * s,
					focinho + Vector2(x + 1.2, 1.4) * s,
					focinho + Vector2(x + 0.6, 3.4) * s,
				]), Color("#f7f2e2"))
			ci.draw_circle(focinho + Vector2(7.4 * facing, -1.6) * s, 0.65 * s, escuro, true, -1.0, true)
			ci.draw_circle(focinho + Vector2(4.6 * facing, -1.9) * s, 0.55 * s, escuro, true, -1.0, true)
		"capivara":
			var focinho := rosto + Vector2(0.8 * facing, 4.4) * s
			elipse(ci, focinho, 7.2 * s, 4.6 * s, claro)
			ci.draw_circle(focinho + Vector2(2.2 * facing, -1.9) * s, 1.35 * s, escuro, true, -1.0, true)
			ci.draw_arc(focinho + Vector2(0.4 * facing, 1.0) * s, 3.0 * s, 0.2, PI - 0.2, 12, C_BOCA, 0.7 * s, true)
			ci.draw_line(focinho + Vector2(-4.5, 1.2) * s, focinho + Vector2(-6.8, 0.4) * s, escuro, 0.45 * s, true)
			ci.draw_line(focinho + Vector2(4.5, 1.2) * s, focinho + Vector2(6.8, 0.4) * s, escuro, 0.45 * s, true)
		"urso":
			var focinho := rosto + Vector2(0.6 * facing, 4.2) * s
			elipse(ci, focinho, 6.4 * s, 4.5 * s, claro)
			ci.draw_circle(focinho + Vector2(1.2 * facing, -1.6) * s, 1.5 * s, escuro, true, -1.0, true)
			ci.draw_arc(focinho + Vector2(0.2 * facing, 1.1) * s, 2.8 * s, 0.2, PI - 0.2, 12, C_BOCA, 0.75 * s, true)
		"coelho":
			var focinho := rosto + Vector2(0.4 * facing, 4.4) * s
			elipse(ci, focinho, 5.2 * s, 3.8 * s, claro)
			ci.draw_circle(focinho + Vector2(0.6 * facing, -1.5) * s, 1.1 * s, Color("#e79aa4"), true, -1.0, true)
			ci.draw_line(focinho + Vector2(0, 0.2) * s, focinho + Vector2(0, 2.4) * s, C_BOCA, 0.7 * s, true)
			ci.draw_rect(Rect2(focinho + Vector2(-1.6, 2.6) * s, Vector2(1.2, 2.0) * s), Color("#fffaf0"), true)
			ci.draw_rect(Rect2(focinho + Vector2(0.4, 2.6) * s, Vector2(1.2, 2.0) * s), Color("#fffaf0"), true)
		"poodle":
			var focinho := rosto + Vector2(0.8 * facing, 4.2) * s
			elipse(ci, focinho, 5.8 * s, 4.0 * s, claro)
			ci.draw_circle(focinho + Vector2(1.0 * facing, -1.8) * s, 1.4 * s, escuro, true, -1.0, true)
			ci.draw_arc(focinho + Vector2(0.4 * facing, 0.8) * s, 2.7 * s, 0.15, PI - 0.15, 12, C_BOCA, 0.8 * s, true)
			ci.draw_circle(focinho + Vector2(1.0 * facing, 3.0) * s, 1.2 * s, Color("#e78b98"), true, -1.0, true)
		"gato", "raposa":
			var focinho := rosto + Vector2(0.6 * facing, 4.3) * s
			elipse(ci, focinho, 5.8 * s, 3.9 * s, Color("#f7ecdc") if especie == "raposa" else claro)
			ci.draw_colored_polygon(PackedVector2Array([
				focinho + Vector2(-1.8, -1.9) * s,
				focinho + Vector2(1.8, -1.9) * s,
				focinho + Vector2(0.4 * facing, 0.4) * s,
			]), Color("#6b3c3a"))
			ci.draw_line(focinho + Vector2(0, 0.2) * s, focinho + Vector2(0, 2.2) * s, C_BOCA, 0.65 * s, true)
			ci.draw_arc(focinho + Vector2(0, 1.3) * s, 2.2 * s, 0.15, PI - 0.15, 12, C_BOCA, 0.6 * s, true)
			for lado in [-1.0, 1.0]:
				for i in 2:
					ci.draw_line(focinho + Vector2(4.0 * lado, (-0.2 + i * 1.4)) * s,
						focinho + Vector2(9.0 * lado, (-1.5 + i * 2.2)) * s,
						Color(1, 1, 1, 0.72), 0.45 * s, true)
		_:
			var focinho := rosto + Vector2(0.6 * facing, 4.3) * s
			elipse(ci, focinho, 5.8 * s, 4.0 * s, claro)
			ci.draw_circle(focinho + Vector2(0.8 * facing, -1.8) * s, 1.2 * s, escuro, true, -1.0, true)
			ci.draw_arc(focinho + Vector2(0, 0.8) * s, 2.4 * s, 0.15, PI - 0.15, 12, C_BOCA, 0.7 * s, true)


static func _detalhes_roupa(ci: CanvasItem, p: Dictionary, raiz: Vector2, rosto: Vector2, s: float,
		jogador: bool, funcionario: bool, crianca: bool, facing: int,
		cor_roupa: Color, cor_roupa2: Color, cor_calca: Color) -> void:
	var topo := rosto + Vector2(0, 8.7) * s
	if jogador or funcionario:
		var cor_peito := cor_roupa2 if jogador else cor_roupa.lightened(0.06)
		# Camiseta/scrub visivel no centro; o branco/azul forma um colete aberto.
		var peito := Rect2(topo + Vector2(-2.9, 1.1) * s, Vector2(5.8, 11.6) * s)
		retangulo_arredondado(ci, peito, Color(cor_peito, 0.97), 2.8 * s)
		var cor_painel := cor_roupa if jogador else cor_roupa2
		var y0 := topo.y + 1.0 * s
		var y1 := topo.y + 12.9 * s
		var painel_esq := PackedVector2Array([
			Vector2(topo.x - 6.5, y0),
			Vector2(topo.x - 1.8, y0 + 2.5 * s),
			Vector2(topo.x - 2.4, y1),
			Vector2(topo.x - 8.6, y1),
		])
		var painel_dir := PackedVector2Array([
			Vector2(topo.x + 6.5, y0),
			Vector2(topo.x + 1.8, y0 + 2.5 * s),
			Vector2(topo.x + 2.4, y1),
			Vector2(topo.x + 8.6, y1),
		])
		ci.draw_colored_polygon(painel_esq, Color(cor_painel, 0.97))
		ci.draw_colored_polygon(painel_dir, Color(cor_painel, 0.97))
		# Lapelas e acabamento.
		ci.draw_line(Vector2(topo.x - 6.5, y0), Vector2(topo.x - 1.8, y0 + 2.5 * s),
			Color(cor_painel.darkened(0.16), 0.55), 1.0 * s, true)
		ci.draw_line(Vector2(topo.x + 6.5, y0), Vector2(topo.x + 1.8, y0 + 2.5 * s),
			Color(cor_painel.darkened(0.16), 0.55), 1.0 * s, true)
		ci.draw_line(Vector2(topo.x - 1.9, y0 + 2.5 * s), Vector2(topo.x - 2.4, y1),
			Color(cor_painel.darkened(0.20), 0.42), 0.9 * s, true)
		ci.draw_line(Vector2(topo.x + 1.9, y0 + 2.5 * s), Vector2(topo.x + 2.4, y1),
			Color(cor_painel.darkened(0.20), 0.42), 0.9 * s, true)
		if funcionario:
			# Bolso e cracha do avental branco.
			ci.draw_line(topo + Vector2(-6.4, 8.8) * s, topo + Vector2(-2.6, 8.8) * s,
				Color(cor_roupa.darkened(0.22), 0.34), 0.8 * s, true)
			var cracha := Rect2(topo + Vector2(5.4, 3.2) * s, Vector2(2.5, 3.8) * s)
			ci.draw_rect(cracha, Color(1, 1, 1, 0.92), true)
			ci.draw_rect(Rect2(cracha.position + Vector2(0.4, 0.5) * s, Vector2(1.7, 1.0) * s),
				cor_roupa.darkened(0.25), true)
		else:
			# Cracha do agente no peito esquerdo.
			var cracha := Rect2(topo + Vector2(-7.4, 3.4) * s, Vector2(3.0, 4.4) * s)
			ci.draw_rect(cracha, Color(1, 1, 1, 0.94), true)
			ci.draw_rect(Rect2(cracha.position + Vector2(0.45, 0.55) * s, Vector2(2.1, 1.3) * s),
				Color("#2f6fd0"), true)
			ci.draw_line(cracha.position + Vector2(0.55, 2.9) * s, cracha.position + Vector2(2.45, 2.9) * s,
				Color("#6b7280"), 0.5 * s, true)
			# Faixa de identificacao do colete.
			ci.draw_line(topo + Vector2(-4.2, 11.7) * s, topo + Vector2(4.2, 11.7) * s,
				Color(cor_roupa.lightened(0.25), 0.55), 1.0 * s, true)
	elif not crianca:
		# Pacientes ganham estampas simples e variadas, sem texto.
		var estilo: int = absi(hash(str(p.get("id", "")))) % 3
		if estilo == 0:
			for i in 3:
				for j in 2:
					ci.draw_circle(topo + Vector2(-4.6 + i * 4.6, 6.0 + j * 4.4) * s, 0.8 * s,
						Color(cor_roupa2, 0.60), true, -1.0, true)
		elif estilo == 1:
			for i in 2:
				ci.draw_line(topo + Vector2(-7.0, (6.4 + i * 4.0)) * s, topo + Vector2(7.0, (4.8 + i * 4.0)) * s,
					Color(cor_roupa2, 0.38), 1.6 * s, true)
		else:
			ci.draw_line(topo + Vector2(0, 2.6) * s, topo + Vector2(0, 12.2) * s,
				Color(cor_roupa2, 0.25), 1.2 * s, true)
	# Bainha inferior, sugerindo camisa sobre a calca.
	ci.draw_line(topo + Vector2(-8.0, 13.6) * s, topo + Vector2(8.0, 13.6) * s,
		Color(cor_calca, 0.38), 1.5 * s, true)


static func _cabelo_tras(ci: CanvasItem, estilo: String, raiz: Vector2, rosto: Vector2, s: float, facing: int, cor: Color) -> void:
	match estilo:
		"longo":
			_capsula(ci, raiz + Vector2(-11.9, -39.0) * s, raiz + Vector2(-12.3, -24.0) * s, 2.8 * s, cor)
			_capsula(ci, raiz + Vector2(11.9, -39.0) * s, raiz + Vector2(12.3, -24.0) * s, 2.8 * s, cor)
			elipse(ci, rosto + Vector2(0, -7.2) * s, 8.9 * s, 4.7 * s, cor)
		"cacheado":
			for i in 7:
				var ang := PI + float(i) * PI / 6.0
				ci.draw_circle(rosto + Vector2(cos(ang) * 9.6, sin(ang) * 7.8 - 3.3) * s,
					2.35 * s, cor, true, -1.0, true)
		"coque":
			ci.draw_circle(rosto + Vector2(0, -13.0) * s, 3.8 * s, cor, true, -1.0, true)
			ci.draw_circle(rosto + Vector2(-1.0, -14.2) * s, 1.3 * s, cor.lightened(0.12), true, -1.0, true)
		_:
			pass


static func _cabelo_frente(ci: CanvasItem, estilo: String, rosto: Vector2, cor: Color, s: float, facing: int) -> void:
	match estilo:
		"curto":
			ci.draw_arc(rosto + Vector2(0, -3.6) * s, 9.4 * s, PI * 1.02, TAU - 0.03, 22, cor, 3.2 * s, true)
			ci.draw_circle(rosto + Vector2(-7.9, -2.0) * s, 2.0 * s, cor, true, -1.0, true)
		"franja":
			ci.draw_arc(rosto + Vector2(0, -3.4) * s, 9.5 * s, PI, TAU - 0.02, 22, cor, 3.3 * s, true)
			for i in 4:
				ci.draw_line(rosto + Vector2(-6.7 + i * 4.4, -6.0) * s,
					rosto + Vector2(-5.9 + i * 4.4, -2.2) * s, cor, 1.8 * s, true)
		"coque":
			ci.draw_arc(rosto + Vector2(0, -3.5) * s, 9.3 * s, PI * 1.04, TAU - 0.06, 22, cor, 2.8 * s, true)
			ci.draw_circle(rosto + Vector2(0, -9.3) * s, 1.4 * s, cor, true, -1.0, true)
		"longo":
			ci.draw_arc(rosto + Vector2(0, -3.3) * s, 9.4 * s, PI, TAU - 0.03, 22, cor, 2.9 * s, true)
			ci.draw_line(rosto + Vector2(-7.6, -4.1) * s, rosto + Vector2(-8.6, 4.6) * s, cor, 2.1 * s, true)
			ci.draw_line(rosto + Vector2(7.6, -4.1) * s, rosto + Vector2(8.6, 4.6) * s, cor, 2.1 * s, true)
		"cacheado":
			for i in 5:
				var ang := PI + float(i) * PI / 4.0
				ci.draw_circle(rosto + Vector2(cos(ang) * 8.0, sin(ang) * 7.3 - 2.1) * s,
					2.1 * s, cor, true, -1.0, true)
		"calvo":
			ci.draw_circle(rosto + Vector2(-8.0, -3.2) * s, 1.9 * s, cor, true, -1.0, true)
			ci.draw_circle(rosto + Vector2(8.0, -3.2) * s, 1.9 * s, cor, true, -1.0, true)
		_:
			ci.draw_arc(rosto + Vector2(0, -3.5) * s, 9.3 * s, PI, TAU, 22, cor, 2.6 * s, true)


static func _chapeu(ci: CanvasItem, tipo: String, rosto: Vector2, s: float, facing: int, cor: Color) -> void:
	var topo := rosto + Vector2(0, -10.0) * s
	match tipo:
		"bone":
			ci.draw_arc(topo + Vector2(0, 2.0) * s, 9.8 * s, PI, TAU, 22, cor, 3.8 * s, true)
			ci.draw_line(topo + Vector2(2.0, 1.6) * s, topo + Vector2(13.8 * facing, 3.0) * s,
				cor.darkened(0.12), 2.5 * s, true)
			ci.draw_circle(topo + Vector2(0, -6.1) * s, 0.9 * s, Color(1, 1, 1, 0.22), true, -1.0, true)
		"touca":
			ci.draw_arc(topo + Vector2(0, 2.2) * s, 9.9 * s, PI, TAU, 22, cor, 4.4 * s, true)
			ci.draw_line(topo + Vector2(-8.9, -1.0) * s, topo + Vector2(8.9, -1.0) * s,
				cor.lightened(0.16), 1.4 * s, true)
			ci.draw_circle(topo + Vector2(0, -8.9) * s, 2.2 * s, C_BRANCO, true, -1.0, true)
		"chapeu_praia":
			elipse(ci, topo + Vector2(0, 2.2) * s, 17.0 * s, 3.5 * s, cor.lightened(0.12))
			elipse(ci, topo + Vector2(0, 1.6) * s, 16.0 * s, 2.8 * s, cor.lightened(0.22))
			ci.draw_rect(Rect2(topo + Vector2(-5.3, -8.8) * s, Vector2(10.6, 10.6) * s), cor, true)
			ci.draw_line(topo + Vector2(-5.3, -4.4) * s, topo + Vector2(5.3, -4.4) * s,
				cor.darkened(0.2), 1.6 * s, true)
		"laco":
			ci.draw_circle(topo + Vector2(8.9 * facing, 1.8) * s, 2.8 * s, cor.lightened(0.20), true, -1.0, true)
			ci.draw_circle(topo + Vector2(6.2 * facing, 0.2) * s, 1.6 * s, cor.lightened(0.12), true, -1.0, true)
			ci.draw_line(topo + Vector2(7.6 * facing, 1.3) * s, topo + Vector2(4.4 * facing, 3.6) * s,
				cor, 1.0 * s, true)
		"coroa":
			var ouro := Color("#f3c64e")
			for i in 3:
				var x := -4.6 + i * 4.6
				ci.draw_colored_polygon(PackedVector2Array([
					topo + Vector2(x, 1.0) * s,
					topo + Vector2(x + 1.9, -7.0) * s,
					topo + Vector2(x + 3.8, 1.0) * s,
				]), ouro)
			ci.draw_line(topo + Vector2(-5.2, 1.0) * s, topo + Vector2(5.2, 1.0) * s,
				ouro.darkened(0.16), 1.9 * s, true)
			ci.draw_circle(topo + Vector2(0, -3.2) * s, 1.0 * s, Color("#e85d75"), true, -1.0, true)
		"orelhas":
			var rosa := Color("#f2a8b6")
			ci.draw_circle(topo + Vector2(-7.2, -1.0) * s, 3.5 * s, cor, true, -1.0, true)
			ci.draw_circle(topo + Vector2(7.2, -1.0) * s, 3.5 * s, cor, true, -1.0, true)
			ci.draw_circle(topo + Vector2(-7.2, -1.0) * s, 1.8 * s, rosa, true, -1.0, true)
			ci.draw_circle(topo + Vector2(7.2, -1.0) * s, 1.8 * s, rosa, true, -1.0, true)
		"capacete":
			ci.draw_arc(topo + Vector2(0, 1.8) * s, 10.0 * s, PI, TAU, 24, cor.lightened(0.16), 5.0 * s, true)
			ci.draw_rect(Rect2(topo + Vector2(1.0, 0.6) * s, Vector2(9.6 * facing, 2.2) * s),
				Color("#8ed8ff"), true)
			ci.draw_line(topo + Vector2(-8.3, 0.0) * s, topo + Vector2(8.3, 0.0) * s,
				Color(1, 1, 1, 0.28), 1.0 * s, true)
		"boina":
			elipse(ci, topo + Vector2(1.4 * facing, -1.8) * s, 9.4 * s, 4.0 * s, cor)
			ci.draw_circle(topo + Vector2(1.4 * facing, -6.4) * s, 1.2 * s, cor.darkened(0.2), true, -1.0, true)
			ci.draw_arc(topo + Vector2(0.5 * facing, -0.8) * s, 8.0 * s, PI * 1.05, PI * 1.62, 12,
				Color(1, 1, 1, 0.16), 1.2 * s, true)
		_:
			pass


static func _acessorio(ci: CanvasItem, tipo: String, rosto: Vector2, s: float, facing: int) -> void:
	match tipo:
		"oculos":
			for lado in [-1.0, 1.0]:
				var centro := rosto + Vector2(3.85 * lado, -1.15) * s
				ci.draw_circle(centro, 3.0 * s, Color(0.22, 0.28, 0.36, 0.10), true, -1.0, true)
				ci.draw_arc(centro, 3.0 * s, 0.0, TAU, 20, Color("#2d3440"), 0.9 * s, true)
			ci.draw_line(rosto + Vector2(-0.9, -1.2) * s, rosto + Vector2(0.9, -1.2) * s,
				Color("#2d3440"), 0.8 * s, true)
			ci.draw_line(rosto + Vector2(-6.8, -1.4) * s, rosto + Vector2(-8.4, -2.2) * s,
				Color("#2d3440"), 0.7 * s, true)
			ci.draw_line(rosto + Vector2(6.8, -1.4) * s, rosto + Vector2(8.4, -2.2) * s,
				Color("#2d3440"), 0.7 * s, true)
		"mascara":
			var mascara := Rect2(rosto + Vector2(-5.8, 1.5) * s, Vector2(11.6, 4.3) * s)
			retangulo_arredondado(ci, mascara, Color("#e9f3f6"), 2.0 * s)
			ci.draw_line(mascara.position + Vector2(1.0, 1.4) * s, mascara.position + Vector2(mascara.size.x - 1.0, 1.4) * s,
				Color("#b8ccd3"), 0.6 * s, true)
			ci.draw_line(rosto + Vector2(-5.8, 2.2) * s, rosto + Vector2(-8.4, 1.5) * s,
				Color("#c8d9de"), 0.7 * s, true)
			ci.draw_line(rosto + Vector2(5.8, 2.2) * s, rosto + Vector2(8.4, 1.5) * s,
				Color("#c8d9de"), 0.7 * s, true)
		"bolsa":
			var bolsa := Rect2(rosto + Vector2(9.5 * facing, 10.0) * s, Vector2(5.0, 6.4) * s)
			ci.draw_line(rosto + Vector2(6.0 * facing, 7.0) * s, bolsa.position + Vector2(1.0, 0.0) * s,
				Color("#6b452b"), 1.0 * s, true)
			retangulo_arredondado(ci, bolsa, Color("#8b5e3c"), 1.8 * s)
			ci.draw_arc(bolsa.position + Vector2(2.5, 0.2) * s, 1.7 * s, PI, TAU, 10,
				Color("#6b452b"), 0.7 * s, true)
		"cachecol":
			ci.draw_line(rosto + Vector2(-8.0, 9.3) * s, rosto + Vector2(8.0, 9.3) * s,
				Color("#c95d63"), 2.4 * s, true)
			ci.draw_line(rosto + Vector2(4.2, 9.8) * s, rosto + Vector2(5.2, 15.0) * s,
				Color("#b44a52"), 1.9 * s, true)
			ci.draw_line(rosto + Vector2(-7.4, 8.1) * s, rosto + Vector2(7.4, 8.1) * s,
				Color("#e0777e"), 0.8 * s, true)
		_:
			pass


static func balao(ci: CanvasItem, p: Dictionary, tipo: String, t: float, escala_extra: float = 1.0) -> void:
	if tipo == "":
		return
	var base: Vector2 = p.get("pos", Vector2.ZERO)
	var s: float = escala_extra * float(p.get("escala", 1.0))
	var pulo := sin(t * 5.0 + float(abs(hash(str(p.get("id", "")))) % 19)) * 1.6
	var centro := base + Vector2(0, (-68.0 if tipo == "exclamacao" else -64.5) * s + pulo)
	var raio := 10.5 * s if tipo != "exclamacao" else 11.5 * s
	var cor_fundo := Color("#fff8e8")
	var cor_icone := Color("#2b2d36")
	match tipo:
		"raiva":
			cor_fundo = Color("#ffe3df")
			cor_icone = Color("#d63b32")
		"coracao":
			cor_fundo = Color("#ffe9ef")
			cor_icone = Color("#d94b72")
		"duvida":
			cor_fundo = Color("#e7f1ff")
			cor_icone = Color("#2f6fd0")
		"cafe":
			cor_fundo = Color("#f5e9d7")
			cor_icone = Color("#6f4a2d")
		"relogio":
			cor_fundo = Color("#eef2f5")
			cor_icone = Color("#45505a")
		"cansado":
			cor_fundo = Color("#eef0f3")
			cor_icone = Color("#5b6570")
		"sorriso":
			cor_fundo = Color("#fff3d6")
			cor_icone = Color("#c98a16")
		"fala":
			cor_fundo = Color("#e7f7ee")
			cor_icone = Color("#2f8a57")
		"pergunta":
			cor_fundo = Color("#eee9ff")
			cor_icone = Color("#6b4fc8")
	# Balao arredondado com rabicho.
	elipse(ci, centro + Vector2(0, 2.2) * s, raio * 1.06, raio * 1.00, Color(0, 0, 0, 0.16))
	ci.draw_circle(centro, raio, cor_fundo, true, -1.0, true)
	ci.draw_circle(centro + Vector2(0.3, -0.4) * s, raio * 0.82, cor_fundo, true, -1.0, true)
	ci.draw_colored_polygon(PackedVector2Array([
		centro + Vector2(-3.1, 8.4) * s,
		centro + Vector2(3.1, 8.4) * s,
		centro + Vector2(0.2, 14.6) * s,
	]), cor_fundo)
	ci.draw_arc(centro, raio, 0.0, TAU, 28, Color(0.17, 0.18, 0.21, 0.22), 1.0 * s, true)
	_desenhar_icone(ci, tipo, centro, s, cor_icone)


static func _desenhar_icone(ci: CanvasItem, tipo: String, c: Vector2, s: float, cor: Color) -> void:
	match tipo:
		"exclamacao":
			ci.draw_line(c + Vector2(0, -6.0) * s, c + Vector2(0, 2.2) * s, cor, 2.5 * s, true)
			ci.draw_circle(c + Vector2(0, 6.1) * s, 1.55 * s, cor, true, -1.0, true)
		"duvida":
			ci.draw_arc(c + Vector2(0, -3.2) * s, 3.1 * s, PI * 1.05, PI * 2.15, 16, cor, 1.7 * s, true)
			ci.draw_line(c + Vector2(0.2, -0.1) * s, c + Vector2(0.2, 2.2) * s, cor, 1.7 * s, true)
			ci.draw_circle(c + Vector2(0.2, 5.9) * s, 1.5 * s, cor, true, -1.0, true)
		"coracao":
			ci.draw_circle(c + Vector2(-2.5, -1.5) * s, 3.1 * s, cor, true, -1.0, true)
			ci.draw_circle(c + Vector2(2.5, -1.5) * s, 3.1 * s, cor, true, -1.0, true)
			ci.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-5.2, 0.3) * s, c + Vector2(5.2, 0.3) * s, c + Vector2(0, 7.0) * s,
			]), cor)
		"raiva":
			for i in 4:
				var ang := float(i) * PI * 0.5
				ci.draw_arc(c, 5.2 * s, ang + 0.2, ang + PI * 0.5 - 0.2, 12, cor, 1.6 * s, true)
			ci.draw_circle(c, 1.1 * s, cor, true, -1.0, true)
		"cafe":
			ci.draw_rect(Rect2(c + Vector2(-4.0, -3.8) * s, Vector2(7.4, 7.2) * s), cor, true)
			ci.draw_arc(c + Vector2(4.4, -1.2) * s, 2.5 * s, -PI * 0.45, PI * 0.45, 10, cor, 1.3 * s, true)
			ci.draw_line(c + Vector2(-5.0, 4.6) * s, c + Vector2(5.0, 4.6) * s, cor, 1.1 * s, true)
			for i in 2:
				var x := -1.8 + i * 3.0
				ci.draw_arc(c + Vector2(x, -5.8) * s, 1.3 * s, PI * 0.2, PI * 1.3, 10, cor, 0.7 * s, true)
		"relogio":
			ci.draw_arc(c, 5.2 * s, 0.0, TAU, 24, cor, 1.2 * s, true)
			ci.draw_line(c, c + Vector2(0, -3.6) * s, cor, 1.1 * s, true)
			ci.draw_line(c, c + Vector2(2.8, 1.8) * s, cor, 1.1 * s, true)
			ci.draw_circle(c, 0.8 * s, cor, true, -1.0, true)
		"cansado":
			ci.draw_line(c + Vector2(-4.0, -2.0) * s, c + Vector2(-1.2, -2.0) * s, cor, 1.0 * s, true)
			ci.draw_line(c + Vector2(1.2, -2.0) * s, c + Vector2(4.0, -2.0) * s, cor, 1.0 * s, true)
			ci.draw_arc(c + Vector2(0, 3.6) * s, 2.4 * s, PI * 0.15, PI * 0.85, 12, cor, 0.9 * s, true)
			ci.draw_line(c + Vector2(-4.2, 2.0) * s, c + Vector2(-2.4, 1.2) * s, cor, 0.7 * s, true)
			ci.draw_line(c + Vector2(4.2, 2.0) * s, c + Vector2(2.4, 1.2) * s, cor, 0.7 * s, true)
		"sorriso":
			ci.draw_arc(c + Vector2(0, 0.6) * s, 4.5 * s, PI * 1.12, PI * 1.88, 16, cor, 1.3 * s, true)
			ci.draw_circle(c + Vector2(-2.4, -2.8) * s, 0.9 * s, cor, true, -1.0, true)
			ci.draw_circle(c + Vector2(2.4, -2.8) * s, 0.9 * s, cor, true, -1.0, true)
		"fala":
			retangulo_arredondado(ci, Rect2(c + Vector2(-5.6, -4.8) * s, Vector2(11.2, 7.8) * s), cor, 2.6 * s)
			ci.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-2.4, 2.4) * s, c + Vector2(1.2, 2.4) * s, c + Vector2(-2.0, 6.4) * s,
			]), cor)
			for i in 3:
				ci.draw_circle(c + Vector2(-2.7 + float(i) * 2.7, -0.9) * s, 0.82 * s,
					Color("#ffffff"), true, -1.0, true)
		"pergunta":
			ci.draw_arc(c + Vector2(0, -3.4) * s, 3.4 * s, PI * 1.05, PI * 2.15, 16, cor, 1.9 * s, true)
			ci.draw_line(c + Vector2(0.2, -0.1) * s, c + Vector2(0.2, 2.4) * s, cor, 1.9 * s, true)
			ci.draw_circle(c + Vector2(0.2, 6.2) * s, 1.6 * s, cor, true, -1.0, true)
		_:
			ci.draw_circle(c, 2.0 * s, cor, true, -1.0, true)


static func retrato(ci: CanvasItem, p: Dictionary, centro: Vector2, escala: float, t: float) -> void:
	var copia: Dictionary = p.duplicate(true)
	copia["pos"] = centro
	copia["andando"] = false
	copia["sentado"] = false
	copia["escala"] = float(p.get("escala", 1.0))
	copia["em_esforco"] = false
	copia["no_pc"] = ""
	copia["energia"] = 0.0
	pessoa(ci, copia, t, escala, false)
