# Data Safety / Segurança dos dados — respostas sugeridas

Versão de referência: 1.0.0
Pacote: `br.com.postinhodesaude.jogo`

## Resumo

O jogo **não coleta, não compartilha e não transmite dados pessoais**. Não há
login, conta, anúncios, analytics, SDK de rastreamento, câmera, microfone,
localização, contatos ou acesso a arquivos pessoais. O único dado gravado é o
progresso fictício da partida, no armazenamento local do app.

## Google Play — Data Safety

### Coleta de dados

- O app coleta ou compartilha algum tipo de dado pessoal? **Não.**
- Dados financeiros: não.
- Saúde e fitness: não. O jogo fala de saúde de forma fictícia, mas não coleta
  dados de saúde do usuário.
- Mensagens: não.
- Fotos e vídeos: não.
- Áudio: não.
- Arquivos e documentos: não.
- Contatos: não.
- Localização aproximada ou precisa: não.
- Histórico de navegação: não.
- Histórico de pesquisa: não.
- Identificadores: não.
- Informações do app e desempenho: não são coletadas pelo app.
- Dispositivo ou outros IDs: não.

### Compartilhamento

- Compartilha dados com terceiros? **Não.**
- Vende dados? **Não.**
- Usa dados para publicidade ou marketing? **Não.**
- Usa dados para personalização? **Não.**
- Usa dados para análise? **Não.**

### Segurança e retenção

- Os dados são criptografados em trânsito? **Não se aplica**: não há transmissão.
- O usuário pode solicitar exclusão? **Não se aplica**: não há dados em servidor.
  O progresso local pode ser apagado limpando os dados do app, desinstalando ou
  iniciando uma nova sessão.
- Retenção: o save local permanece no aparelho até ser apagado pelo usuário,
  pelo sistema ou pela desinstalação.

### Práticas adicionais

- O app é destinado a crianças? **Não é direcionado especificamente a crianças**;
  é adequado ao público geral. Não coleta dados de nenhum público.
- O app usa Advertising ID? **Não.**
- O app tem compras no app? **Não.**
- O app tem anúncios? **Não.**
- O app exige login? **Não.**

## Microsoft Store — Privacy

- O produto acessa, coleta ou transmite informações pessoais? **Não.**
- O produto usa localização, câmera, microfone ou contatos? **Não.**
- O produto usa telemetria de terceiros? **Não.**
- O produto armazena dados do usuário? **Apenas o save local fictício e as
  preferências de aparência/som/ritmo**, na área local do aplicativo.
- O produto transmite dados para servidores? **Não.**
- O produto usa OAuth/Drive? **Não.**

## Texto para a política pública

“O Postinho de Saúde não coleta dados pessoais. O progresso fictício da partida
e as preferências ficam apenas no armazenamento local do aplicativo. Não há
login, anúncios, analytics, rastreamento, câmera, microfone ou localização. O
usuário pode apagar o progresso iniciando uma nova sessão, limpando os dados do
aplicativo ou desinstalando-o.”

## Conferência antes de enviar

- [ ] A política pública está em HTTPS e abre sem login.
- [ ] A política menciona ausência de coleta, armazenamento local, retenção,
      compartilhamento, LGPD/GDPR e contato.
- [ ] Não há SDK de anúncios/analytics no AAB/MSIX.
- [ ] Não há permissão `AD_ID` no manifesto Android.
- [ ] A ficha não promete função inexistente.
- [ ] O texto da loja e a política usam a mesma versão 1.0.0.
