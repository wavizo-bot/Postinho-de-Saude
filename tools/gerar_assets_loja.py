"""Gera os assets de loja e da landing a partir das capturas reais do jogo.

Uso:
    python tools/gerar_assets_loja.py

Entradas:
    build/capturas/*.png (capturas reais, dados ficticios)
Saidas:
    store/play/...            icone, feature graphic e 6 capturas
    store/microsoft/...       6 capturas 1366x768 + artes 720x1080/720x1280,
                              1080x1080 e faixa 1080x80
    docs/assets/...           WebP 1366/390, OG 1200x630, icone e favicon

Nao usa banco de imagens nem mockup generico: todas as telas sao do jogo.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

RAIZ = Path(__file__).resolve().parent.parent
CAPTURAS = RAIZ / "build" / "capturas"
PLAY = RAIZ / "store" / "play"
MS = RAIZ / "store" / "microsoft"
DOCS = RAIZ / "docs" / "assets"

TINTA = (23, 33, 43)
TINTA2 = (30, 45, 58)
CREME = (255, 247, 235)
VERDE = (42, 157, 143)
VERDE_ESCURO = (24, 106, 98)
PELE = (244, 162, 97)
VERMELHO = (231, 111, 81)
BRANCO = (255, 255, 255)
CINZA = (201, 216, 226)

FONTES = [
    Path("C:/Windows/Fonts/segoeuib.ttf"),
    Path("C:/Windows/Fonts/segoeui.ttf"),
    Path("C:/Windows/Fonts/arialbd.ttf"),
]
FONTE_NORMAL = Path("C:/Windows/Fonts/segoeui.ttf")


def fonte(tamanho: int, negrito: bool = True) -> ImageFont.FreeTypeFont:
    candidatos = FONTES if negrito else [FONTE_NORMAL] + FONTES
    for caminho in candidatos:
        if caminho.is_file():
            return ImageFont.truetype(str(caminho), tamanho)
    return ImageFont.load_default()


def capa(img: Image.Image, tamanho: tuple[int, int]) -> Image.Image:
    largura, altura = tamanho
    escala = max(largura / img.width, altura / img.height)
    nova = (max(1, int(img.width * escala + 0.5)), max(1, int(img.height * escala + 0.5)))
    red = img.resize(nova, Image.Resampling.LANCZOS)
    x = (red.width - largura) // 2
    y = (red.height - altura) // 2
    return red.crop((x, y, x + largura, y + altura))


def contem(img: Image.Image, tamanho: tuple[int, int]) -> Image.Image:
    largura, altura = tamanho
    escala = min(largura / img.width, altura / img.height)
    nova = (max(1, int(img.width * escala + 0.5)), max(1, int(img.height * escala + 0.5)))
    return img.resize(nova, Image.Resampling.LANCZOS)


def gradiente(tamanho: tuple[int, int], esquerda: tuple[int, int, int, int], direita: tuple[int, int, int, int]) -> Image.Image:
    largura, altura = tamanho
    img = Image.new("RGBA", tamanho)
    d = ImageDraw.Draw(img)
    for x in range(largura):
        t = x / max(1, largura - 1)
        cor = tuple(int(esquerda[i] * (1 - t) + direita[i] * t) for i in range(4))
        d.line((x, 0, x, altura), fill=cor)
    return img


def fundo_verde(tamanho: tuple[int, int]) -> Image.Image:
    largura, altura = tamanho
    img = Image.new("RGBA", tamanho, VERDE)
    d = ImageDraw.Draw(img)
    for y in range(altura):
        t = y / max(1, altura - 1)
        cor = tuple(int(VERDE[i] * (1 - t) + VERDE_ESCURO[i] * t) for i in range(3)) + (255,)
        d.line((0, y, largura, y), fill=cor)
    # Bolhas decorativas: desenhar em camada propria e compor, para o alfa
    # nao virar branco opaco quando a imagem for salva em RGB.
    bolhas = Image.new("RGBA", tamanho, (0, 0, 0, 0))
    db = ImageDraw.Draw(bolhas)
    db.ellipse((-int(largura * 0.25), -int(altura * 0.20), int(largura * 0.45), int(altura * 0.40)), fill=(255, 255, 255, 18))
    db.ellipse((int(largura * 0.70), int(altura * 0.62), int(largura * 1.12), int(altura * 1.05)), fill=(255, 255, 255, 16))
    return Image.alpha_composite(img, bolhas)


def painel_texto(tamanho: tuple[int, int], titulo: str, subtitulo: str, bullets: list[str], rodape: str = "v1.0.1") -> Image.Image:
    largura, altura = tamanho
    img = fundo_verde(tamanho)
    d = ImageDraw.Draw(img)
    margem = int(largura * 0.075)
    y = int(altura * 0.075)
    f_titulo = fonte(int(largura * 0.072))
    f_sub = fonte(int(largura * 0.032), negrito=False)
    f_bullet = fonte(int(largura * 0.030), negrito=False)
    f_rodape = fonte(int(largura * 0.022), negrito=False)

    d.text((margem, y), titulo, font=f_titulo, fill=BRANCO)
    y += int(largura * 0.095)
    d.text((margem, y), subtitulo, font=f_sub, fill=(255, 255, 255, 220))
    y += int(largura * 0.075)

    # Captura emoldurada.
    shot = Image.open(CAPTURAS / "01_visao_geral.png").convert("RGBA")
    moldura_w = largura - margem * 2
    moldura_h = int(moldura_w * 9 / 16)
    shot = capa(shot, (moldura_w, moldura_h))
    sombra = Image.new("RGBA", tamanho, (0, 0, 0, 0))
    ds = ImageDraw.Draw(sombra)
    ds.rounded_rectangle((margem + 10, y + 14, margem + moldura_w + 10, y + moldura_h + 14), radius=18, fill=(0, 0, 0, 90))
    sombra = sombra.filter(ImageFilter.GaussianBlur(12))
    img = Image.alpha_composite(img, sombra)
    d = ImageDraw.Draw(img)
    mask = Image.new("L", (moldura_w, moldura_h), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, moldura_w, moldura_h), radius=18, fill=255)
    img.paste(shot, (margem, y), mask)
    d.rounded_rectangle((margem, y, margem + moldura_w, y + moldura_h), radius=18, outline=(255, 255, 255, 150), width=3)
    y += moldura_h + int(altura * 0.035)

    for texto in bullets:
        raio = max(4, int(largura * 0.010))
        d.ellipse((margem, y + raio, margem + raio * 2, y + raio * 3), fill=PELE)
        d.text((margem + raio * 4, y), texto, font=f_bullet, fill=(255, 255, 255, 235))
        y += int(largura * 0.048)

    d.text((margem, altura - int(altura * 0.045)), rodape, font=f_rodape, fill=(255, 255, 255, 170))
    return img


def feature_graphic() -> Image.Image:
    largura, altura = 1024, 500
    base = capa(Image.open(CAPTURAS / "01_visao_geral.png").convert("RGBA"), (largura, altura))
    overlay = gradiente((largura, altura), (13, 22, 30, 248), (13, 22, 30, 35))
    img = Image.alpha_composite(base, overlay)
    d = ImageDraw.Draw(img)
    icone = Image.open(RAIZ / "store" / "play" / "icone_512.png").convert("RGBA").resize((84, 84), Image.Resampling.LANCZOS)
    img.alpha_composite(icone, (52, 46))
    d.text((150, 50), "POSTINHO", font=fonte(58), fill=BRANCO)
    d.text((150, 108), "DE SAÚDE", font=fonte(58), fill=PELE)
    d.text((54, 190), "A rotina do ACS virou jogo.", font=fonte(30, negrito=False), fill=(255, 255, 255, 230))
    d.text((54, 232), "Acolha, escute, resolva demandas e ria do absurdo.", font=fonte(21, negrito=False), fill=CINZA)
    d.rounded_rectangle((54, 300, 300, 344), radius=22, fill=(231, 111, 81, 235))
    d.text((76, 310), "ANDROID  •  WINDOWS", font=fonte(17), fill=BRANCO)
    d.text((54, 430), "Jogo independente • offline • sem dados reais", font=fonte(17, negrito=False), fill=(255, 255, 255, 190))
    return img


def og_image() -> Image.Image:
    largura, altura = 1200, 630
    base = capa(Image.open(CAPTURAS / "01_visao_geral.png").convert("RGBA"), (largura, altura))
    overlay = gradiente((largura, altura), (13, 22, 30, 250), (13, 22, 30, 55))
    img = Image.alpha_composite(base, overlay)
    d = ImageDraw.Draw(img)
    icone = Image.open(RAIZ / "docs" / "assets" / "icone-512.png").convert("RGBA").resize((110, 110), Image.Resampling.LANCZOS)
    img.alpha_composite(icone, (64, 54))
    d.text((198, 62), "POSTINHO DE SAÚDE", font=fonte(46), fill=BRANCO)
    d.text((66, 210), "A rotina do ACS", font=fonte(62), fill=BRANCO)
    d.text((66, 280), "virou jogo.", font=fonte(62), fill=PELE)
    d.text((68, 375), "Acolhimento, filas, café e humor nonsense.", font=fonte(24, negrito=False), fill=CINZA)
    d.text((68, 412), "Offline • Android e Windows • sem dados reais", font=fonte(22, negrito=False), fill=(255, 255, 255, 200))
    d.rounded_rectangle((68, 480, 330, 534), radius=27, fill=VERDE)
    d.text((94, 494), "JOGO INDEPENDENTE", font=fonte(20), fill=BRANCO)
    return img


def faixa() -> Image.Image:
    largura, altura = 1080, 80
    img = Image.new("RGBA", (largura, altura), TINTA)
    d = ImageDraw.Draw(img)
    icone = Image.open(RAIZ / "store" / "play" / "icone_512.png").convert("RGBA").resize((56, 56), Image.Resampling.LANCZOS)
    img.alpha_composite(icone, (16, 12))
    d.text((86, 17), "POSTINHO DE SAÚDE", font=fonte(30), fill=BRANCO)
    d.text((86, 50), "A rotina do ACS virou jogo • offline • Android e Windows", font=fonte(15, negrito=False), fill=CINZA)
    d.text((largura - 120, 28), "v1.0.1", font=fonte(18), fill=PELE)
    return img


def salvar_webp(origem: Path, destino: Path, largura: int) -> None:
    img = Image.open(origem).convert("RGB")
    altura = int(img.height * largura / img.width)
    img = img.resize((largura, altura), Image.Resampling.LANCZOS)
    destino.parent.mkdir(parents=True, exist_ok=True)
    qualidade = 84
    while qualidade >= 55:
        img.save(destino, "WEBP", quality=qualidade, method=6)
        if destino.stat().st_size <= 250_000:
            return
        qualidade -= 5
    raise RuntimeError(f"WebP acima de 250 KB: {destino}")


def main() -> None:
    for pasta in (PLAY, MS, DOCS):
        pasta.mkdir(parents=True, exist_ok=True)
    (PLAY / "capturas").mkdir(parents=True, exist_ok=True)
    (MS / "capturas").mkdir(parents=True, exist_ok=True)

    selecionadas = [
        ("01_visao_geral.png", "O posto inteiro em um só olhar"),
        ("02_trabalhando.png", "Trabalho, energia e tarefas"),
        ("03_dialogo_energia_alta.png", "Demandas e conversas com a equipe"),
        ("08_regras.png", "Ritmo e demandas ajustáveis"),
        ("16_salas_vacina_procedimentos.png", "Salas de vacina e procedimentos"),
        ("17_corredor_copa.png", "Copa, café e circulação livre"),
    ]

    for i, (nome, _legenda) in enumerate(selecionadas, start=1):
        origem = CAPTURAS / nome
        if not origem.is_file():
            raise FileNotFoundError(origem)
        img = Image.open(origem).convert("RGB")
        rotulo = Path(nome).stem.split("_", 1)[-1]
        destino = PLAY / "capturas" / f"{i:02d}_{rotulo}.png"
        img.save(destino, "PNG")
        # Microsoft: 1366x768 recomendado (Regra W9).
        img.resize((1366, 768), Image.Resampling.LANCZOS).save(MS / "capturas" / f"{i:02d}_{rotulo}_1366x768.png", "PNG")
        # Landing: WebP 1366 e 390 de largura (Regras GH5.2).
        salvar_webp(origem, DOCS / f"tela-{i:02d}-1366.webp", 1366)
        salvar_webp(origem, DOCS / f"tela-{i:02d}-390.webp", 390)

    feature_graphic().convert("RGB").save(PLAY / "feature_1024x500.png", "PNG")
    feature_graphic().convert("RGB").save(DOCS / "og-1200x630-base.png", "PNG")  # placeholder temporario
    og_image().convert("RGB").save(DOCS / "og-1200x630.png", "PNG")
    (DOCS / "og-1200x630-base.png").unlink(missing_ok=True)

    painel_texto((720, 1080), "POSTINHO", "A rotina do ACS virou jogo.", [
        "Acolha a comunidade e escute as demandas.",
        "Trabalhe nos PCs, conserte a impressora e ache pastas.",
        "Sem prova, sem nota, sem game over.",
    ]).convert("RGB").save(MS / "arte_720x1080.png", "PNG")
    painel_texto((720, 1280), "POSTINHO", "A rotina do ACS virou jogo.", [
        "Acolha a comunidade e escute as demandas.",
        "Trabalhe nos PCs, conserte a impressora e ache pastas.",
        "Sem prova, sem nota, sem game over.",
        "Humor nonsense com uma equipe que virou bicho.",
    ]).convert("RGB").save(MS / "arte_720x1280.png", "PNG")
    painel_texto((1080, 1080), "POSTINHO DE SAÚDE", "A rotina do ACS virou jogo.", [
        "Acolhimento, filas, café e humor nonsense.",
        "Offline • Android e Windows • sem dados reais.",
    ]).convert("RGB").save(MS / "arte_1080x1080.png", "PNG")
    faixa().convert("RGB").save(MS / "faixa_1080x80.png", "PNG")

    # Icone padrao da loja ja e gerado por tools/gerar_icone.py.
    print("Assets de loja e landing gerados em store/ e docs/assets/.")


if __name__ == "__main__":
    main()
