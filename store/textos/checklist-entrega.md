# Checklist de assets e fichas de loja

Versão de referência: 1.0.0

## Google Play

- [x] Ícone 512x512 PNG 32-bit com transparência: `store/play/icone_512.png`
- [x] Feature graphic 1024x500: `store/play/feature_1024x500.png`
- [x] 6 capturas 1280x720 (16:9), entre 320 e 3840 px: `store/play/capturas/`
- [x] Textos de ficha: `store/textos/play.md`
- [x] Data Safety: `store/textos/data-safety.md`
- [x] Política de privacidade pública em HTTPS
- [x] AAB assinado, R8, targetSdk 36, sem AD_ID
- [ ] Conta de desenvolvedor Google Play e upload (credenciais externas)
- [ ] Questionário de classificação etária e conteúdo do app
- [ ] Teste fechado/teste interno na Play Console

## Microsoft Store / Partner Center

- [x] 6 capturas 1366x768 da UI real: `store/microsoft/capturas/`
- [x] Arte 9:16 720x1080: `store/microsoft/arte_720x1080.png`
- [x] Arte 9:16 720x1280: `store/microsoft/arte_720x1280.png`
- [x] Arte 1:1 1080x1080: `store/microsoft/arte_1080x1080.png`
- [x] Faixa 1080x80: `store/microsoft/faixa_1080x80.png`
- [x] Ícone/StoreLogo 1:1: `tools/msix/Assets/StoreLogo.png`
- [x] Textos de ficha: `store/textos/microsoft.md`
- [x] MSIX 1.0.0.0 assinado para teste e manifesto conferido
- [ ] Conta Partner Center, reserva de nome e upload (credenciais externas)
- [ ] Certificado de produção compatível com o Publisher reservado
- [ ] Teste de instalação em máquina limpa

## Landing / GitHub Pages

- [x] 6 WebP 1366 px e 6 WebP 390 px, até 250 KB
- [x] OG 1200x630
- [x] Ícone e favicon
- [x] Documentos legais públicos
- [x] robots.txt e sitemap.xml
- [x] Resumo em inglês
- [ ] Teste HTTP 200 após o deploy
- [ ] Teste visual em 1366x768 e 390x844

## Regras de conteúdo

- [x] Capturas reais, com dados fictícios.
- [x] Nenhum nome de paciente/profissional real, CPF, cartão SUS, telefone ou
      endereço pessoal.
- [x] Nenhum mockup genérico, tela vazia ou foto de banco de imagens.
- [x] Nenhuma promessa de função inexistente (multiplayer, nuvem, versão web).
- [x] Aviso de jogo independente, não oficial e não médico nas fichas e na
      landing.
- [x] Versão 1.0.0 coerente em landing, /app/, README, manual, pacotes e lojas.
