# Audita os textos e links públicos antes da publicação.
# Uso: python tools/auditar_publicacao.py
# Falha (exit 1) se houver BOM, UTF-8 inválido, U+FFFD, placeholder, link
# interno quebrado ou checksum da página /app/ diferente da pasta de entrega.

from __future__ import annotations

import html
import re
import sys
from pathlib import Path
from urllib.parse import unquote, urlparse

RAIZ = Path(__file__).resolve().parent.parent
DOCS = RAIZ / "docs"
ENTREGA = RAIZ / "build" / "entrega"

TEXTOS = [RAIZ / "README.md", RAIZ / "manual.txt", RAIZ / "AJUSTES.md", RAIZ / "LICENSE"]
TEXTOS += sorted(DOCS.rglob("*.html"))
TEXTOS += sorted(DOCS.rglob("*.css"))
TEXTOS += sorted(DOCS.rglob("*.xml"))
TEXTOS += sorted(DOCS.rglob("*.txt"))
TEXTOS += sorted((RAIZ / "store" / "textos").glob("*.md"))

PROIBIDOS = [
    (re.compile(r"\bTODO\b"), "marcador TODO"),
    (re.compile(r"lorem\s+ipsum", re.IGNORECASE), "texto lorem ipsum"),
    (re.compile(r"localhost", re.IGNORECASE), "endereço localhost"),
    (re.compile(r"C:\\"), "caminho absoluto do Windows"),
]

ATRIBUTO = re.compile(r"""(?:href|src)\s*=\s*["']([^"']+)["']""", re.IGNORECASE)


def auditar_textos() -> list[str]:
    problemas: list[str] = []
    for caminho in TEXTOS:
        if not caminho.is_file():
            problemas.append(f"arquivo ausente: {caminho.relative_to(RAIZ)}")
            continue
        dados = caminho.read_bytes()
        if dados.startswith(b"\xef\xbb\xbf"):
            problemas.append(f"{caminho.relative_to(RAIZ)}: BOM UTF-8")
        try:
            texto = dados.decode("utf-8")
        except UnicodeDecodeError as erro:
            problemas.append(f"{caminho.relative_to(RAIZ)}: UTF-8 inválido ({erro})")
            continue
        if "\ufffd" in texto:
            problemas.append(f"{caminho.relative_to(RAIZ)}: U+FFFD encontrado")
        for regex, rotulo in PROIBIDOS:
            ocorrencias = len(regex.findall(texto))
            if ocorrencias:
                problemas.append(f"{caminho.relative_to(RAIZ)}: {rotulo} x{ocorrencias}")
    return problemas


def auditar_links() -> list[str]:
    problemas: list[str] = []
    for pagina in sorted(DOCS.rglob("*.html")):
        texto = pagina.read_text(encoding="utf-8")
        for bruto in ATRIBUTO.findall(texto):
            alvo = html.unescape(bruto).strip()
            if not alvo or alvo.startswith(("#", "http://", "https://", "mailto:", "tel:", "data:", "javascript:")):
                continue
            caminho_url = unquote(urlparse(alvo).path)
            if not caminho_url:
                continue
            destino = (pagina.parent / caminho_url).resolve()
            if destino.is_dir():
                destino = destino / "index.html"
            if not destino.is_file():
                problemas.append(f"{pagina.relative_to(RAIZ)}: link quebrado -> {alvo}")
    return problemas


def auditar_checksums() -> list[str]:
    problemas: list[str] = []
    pagina = DOCS / "app" / "index.html"
    somas = ENTREGA / "SHA256SUMS.txt"
    if not pagina.is_file():
        return ["docs/app/index.html ausente"]
    if not somas.is_file():
        return ["build/entrega/SHA256SUMS.txt ausente; rode tools/preparar_entrega.ps1"]
    texto = pagina.read_text(encoding="utf-8").upper()
    for linha in somas.read_text(encoding="utf-8").splitlines():
        linha = linha.strip()
        if not linha:
            continue
        partes = linha.split()
        if len(partes) < 2:
            problemas.append(f"linha inválida em SHA256SUMS.txt: {linha}")
            continue
        hash_esperado, nome = partes[0].upper(), partes[-1]
        if hash_esperado not in texto:
            problemas.append(f"docs/app/index.html não exibe o SHA256 de {nome}")
    return problemas


def auditar_versao() -> list[str]:
    import json

    problemas: list[str] = []
    dados = json.loads((RAIZ / "version.json").read_text(encoding="utf-8"))
    app = (DOCS / "app" / "index.html").read_text(encoding="utf-8")
    readme = (RAIZ / "README.md").read_text(encoding="utf-8")
    manual = (RAIZ / "manual.txt").read_text(encoding="utf-8")
    for rotulo, texto in (("/app/", app), ("README", readme), ("manual", manual)):
        if dados["versao"] not in texto:
            problemas.append(f"{rotulo}: versão {dados['versao']} ausente")
    if dados["windows"] not in app:
        problemas.append(f"/app/: versão Windows {dados['windows']} ausente")
    if dados["android"] not in app:
        problemas.append(f"/app/: versão Android {dados['android']} ausente")
    return problemas


def main() -> int:
    problemas = []
    problemas += auditar_textos()
    problemas += auditar_links()
    problemas += auditar_checksums()
    problemas += auditar_versao()
    if problemas:
        print(f"FALHAS: {len(problemas)}")
        for problema in problemas:
            print(f"- {problema}")
        return 1
    print(f"AUDITORIA OK: {len(TEXTOS)} textos, links internos, checksums e versão.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
