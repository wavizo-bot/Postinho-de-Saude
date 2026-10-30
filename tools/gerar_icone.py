"""Gera o icone do jogo e os icones de loja/MSIX sem assets externos.

Uso:
    python tools/gerar_icone.py
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

RAIZ = Path(__file__).resolve().parent.parent
TINTA = (23, 33, 43, 255)
CREME = (255, 247, 235, 255)
VERDE = (42, 157, 143, 255)
VERDE_ESCURO = (24, 106, 98, 255)
PELE = (244, 162, 97, 255)
VERMELHO = (231, 111, 81, 255)
BRANCO = (255, 255, 255, 255)


def _rounded(draw: ImageDraw.ImageDraw, caixa, raio, fill, outline=None, width=1):
    draw.rounded_rectangle(caixa, radius=raio, fill=fill, outline=outline, width=width)


def desenhar_icone(tamanho: int, fundo_transparente: bool) -> Image.Image:
    escala = 4
    lado = tamanho * escala
    img = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    margem = int(lado * 0.075) if fundo_transparente else 0
    raio = int(lado * 0.22)
    caixa = (margem, margem, lado - margem, lado - margem)
    # Sombra suave.
    if fundo_transparente:
        sombra = Image.new("RGBA", img.size, (0, 0, 0, 0))
        ds = ImageDraw.Draw(sombra)
        _rounded(ds, (margem + int(lado * 0.012), margem + int(lado * 0.018), lado - margem + int(lado * 0.012), lado - margem + int(lado * 0.018)), raio, (0, 0, 0, 55))
        sombra = sombra.filter(ImageFilter.GaussianBlur(int(lado * 0.012)))
        img = Image.alpha_composite(img, sombra)
        d = ImageDraw.Draw(img)

    _rounded(d, caixa, raio, VERDE)
    # Faixa clara no topo, para dar volume.
    d.arc((margem + int(lado * 0.05), margem + int(lado * 0.03), lado - margem - int(lado * 0.05), lado - margem - int(lado * 0.03)), 200, 340, fill=(255, 255, 255, 38), width=int(lado * 0.02))

    # Corpo do feijao/capsula.
    corpo = (int(lado * 0.235), int(lado * 0.255), int(lado * 0.765), int(lado * 0.795))
    _rounded(d, corpo, int(lado * 0.22), CREME, TINTA, int(lado * 0.018))

    # Touca de profissional com cruz.
    touca = (int(lado * 0.345), int(lado * 0.145), int(lado * 0.655), int(lado * 0.335))
    _rounded(d, touca, int(lado * 0.075), BRANCO, TINTA, int(lado * 0.014))
    cw = int(lado * 0.035)
    cx, cy = lado // 2, int(lado * 0.235)
    d.rounded_rectangle((cx - cw // 2, cy - int(lado * 0.075), cx + cw // 2, cy + int(lado * 0.075)), radius=int(lado * 0.008), fill=VERMELHO)
    d.rounded_rectangle((cx - int(lado * 0.075), cy - cw // 2, cx + int(lado * 0.075), cy + cw // 2), radius=int(lado * 0.008), fill=VERMELHO)

    # Olhos.
    olho_y = int(lado * 0.455)
    for ox in (int(lado * 0.405), int(lado * 0.595)):
        d.ellipse((ox - int(lado * 0.042), olho_y - int(lado * 0.055), ox + int(lado * 0.042), olho_y + int(lado * 0.055)), fill=TINTA)
        d.ellipse((ox - int(lado * 0.016), olho_y - int(lado * 0.033), ox + int(lado * 0.004), olho_y - int(lado * 0.013)), fill=BRANCO)

    # Bochechas.
    for ox in (int(lado * 0.335), int(lado * 0.665)):
        d.ellipse((ox - int(lado * 0.055), int(lado * 0.535), ox + int(lado * 0.055), int(lado * 0.585)), fill=(244, 162, 97, 120))

    # Sorriso.
    d.arc((int(lado * 0.425), int(lado * 0.455), int(lado * 0.575), int(lado * 0.585)), 15, 165, fill=TINTA, width=int(lado * 0.018))

    # Gola e cruz no peito.
    _rounded(d, (int(lado * 0.31), int(lado * 0.62), int(lado * 0.69), int(lado * 0.715)), int(lado * 0.05), VERDE_ESCURO)
    cw2 = int(lado * 0.024)
    cx2, cy2 = lado // 2, int(lado * 0.665)
    d.rounded_rectangle((cx2 - cw2 // 2, cy2 - int(lado * 0.045), cx2 + cw2 // 2, cy2 + int(lado * 0.045)), radius=int(lado * 0.006), fill=BRANCO)
    d.rounded_rectangle((cx2 - int(lado * 0.045), cy2 - cw2 // 2, cx2 + int(lado * 0.045), cy2 + cw2 // 2), radius=int(lado * 0.006), fill=BRANCO)

    # Bracinhos.
    _rounded(d, (int(lado * 0.175), int(lado * 0.51), int(lado * 0.275), int(lado * 0.64)), int(lado * 0.05), CREME, TINTA, int(lado * 0.012))
    _rounded(d, (int(lado * 0.725), int(lado * 0.51), int(lado * 0.825), int(lado * 0.64)), int(lado * 0.05), CREME, TINTA, int(lado * 0.012))

    return img.resize((tamanho, tamanho), Image.Resampling.LANCZOS)


def main() -> None:
    # Icone do aplicativo: fundo opaco, para launcher/exe.
    opaco = desenhar_icone(512, fundo_transparente=False)
    opaco.save(RAIZ / "icon.png", "PNG")
    opaco.save(RAIZ / "icon.ico", format="ICO", sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])

    # Icone de loja: 512x512, PNG 32-bit com transparencia (Regra L1).
    loja = desenhar_icone(512, fundo_transparente=True)
    destinos = [
        RAIZ / "store" / "play" / "icone_512.png",
        RAIZ / "docs" / "assets" / "icone-512.png",
    ]
    for destino in destinos:
        destino.parent.mkdir(parents=True, exist_ok=True)
        loja.save(destino, "PNG")

    loja.resize((192, 192), Image.Resampling.LANCZOS).save(RAIZ / "docs" / "assets" / "icone-192.png", "PNG")
    loja.resize((64, 64), Image.Resampling.LANCZOS).save(RAIZ / "docs" / "assets" / "favicon-64.png", "PNG")
    loja.resize((48, 48), Image.Resampling.LANCZOS).save(RAIZ / "docs" / "favicon.ico", format="ICO", sizes=[(16, 16), (32, 32), (48, 48)])

    # Logos do MSIX.
    msix = RAIZ / "tools" / "msix" / "Assets"
    msix.mkdir(parents=True, exist_ok=True)
    for nome, tamanho in (("Square44x44Logo.png", 44), ("Square150x150Logo.png", 150), ("StoreLogo.png", 50)):
        opaco.resize((tamanho, tamanho), Image.Resampling.LANCZOS).save(msix / nome, "PNG")

    print("Icones gerados: icon.png, icon.ico, store/play/icone_512.png, docs/assets e tools/msix/Assets")


if __name__ == "__main__":
    main()
