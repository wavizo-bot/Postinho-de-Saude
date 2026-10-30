"""Confere o AAB final: R8, mapping, DEX e metadados de bundle.

Uso:
    python tools/verificar_aab.py caminho/PostinhoDeSaude.aab

Saida: linhas CHAVE=valor e codigo 0/1. Nao substitui o bundletool para o
manifesto; o script de build roda os dois.
"""
from __future__ import annotations

import json
import sys
import zipfile
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 2:
        print("uso: verificar_aab.py <arquivo.aab>")
        return 2
    aab = Path(sys.argv[1])
    if not aab.is_file():
        print(f"ERRO: AAB nao encontrado: {aab}")
        return 2
    problemas: list[str] = []
    with zipfile.ZipFile(aab) as z:
        nomes = set(z.namelist())
        r8 = "BUNDLE-METADATA/com.android.tools/r8.json"
        mapping = "BUNDLE-METADATA/com.android.tools.build.obfuscation/proguard.map"
        if r8 not in nomes:
            problemas.append("r8.json ausente")
            dados_r8 = {}
        else:
            dados_r8 = json.loads(z.read(r8).decode("utf-8"))
        if mapping not in nomes:
            problemas.append("mapping.txt ausente")
            tamanho_mapping = 0
        else:
            tamanho_mapping = len(z.read(mapping))
        dex = [n for n in nomes if n.startswith("base/dex/") and n.endswith(".dex")]
        if not dex:
            problemas.append("nenhum DEX no bundle")
        manifest = "base/manifest/AndroidManifest.xml"
        if manifest not in nomes:
            problemas.append("manifesto base ausente")
        nativos = [n for n in nomes if n.endswith("libgodot_android.so")]
        if not nativos:
            problemas.append("libgodot_android.so ausente")

    # AGP 8.10+ grava as flags dentro de "options"; versoes antigas podiam
    # expor no topo. Aceitar as duas formas mantem o verificador util.
    opcoes = dados_r8.get("options", dados_r8) if isinstance(dados_r8, dict) else {}
    otim = bool(opcoes.get("isOptimizationsEnabled", False))
    minif = bool(opcoes.get("isObfuscationEnabled", False))
    encolh = bool(opcoes.get("isShrinkingEnabled", False))
    if not otim:
        problemas.append("R8 sem otimizacoes (isOptimizationsEnabled=false)")
    if not minif:
        problemas.append("R8 sem minificacao/ofuscacao")
    if not encolh:
        problemas.append("R8 sem shrinking")
    versao_r8 = str(dados_r8.get("version", "")) if isinstance(dados_r8, dict) else ""
    if not versao_r8:
        problemas.append("versao do R8 ausente no r8.json")

    print(f"AAB={aab}")
    print(f"TAMANHO={aab.stat().st_size}")
    print(f"R8_VERSAO={versao_r8}")
    print(f"R8_OTIMIZACOES={otim}")
    print(f"R8_MINIFICACAO={minif}")
    print(f"R8_SHRINKING={encolh}")
    print(f"MAPPING_BYTES={tamanho_mapping}")
    print(f"DEX={len(dex)}")
    print(f"NATIVOS={len(nativos)}")
    if problemas:
        print("PROBLEMAS=" + "; ".join(problemas))
        return 1
    print("RESULTADO=OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
