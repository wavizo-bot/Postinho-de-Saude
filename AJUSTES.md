# Postinho de Saude - como ajustar o jogo

Tudo o que muda o jogo esta em arquivos `.json` dentro da pasta `data/`.
Voce nao precisa mexer em codigo: abra o arquivo no Bloco de Notas, salve, e rode de novo.

Depois de qualquer mudanca, rode os testes para garantir que nada quebrou:

```
godot --headless --path . --script res://tests/testes.gd
```

Deve terminar com "TODOS OS 249 TESTES PASSARAM".

O teste de interface precisa de janela, nunca de `--headless`, e termina com
"CLIQUES OK: 112 verificacoes". Ele usa e depois restaura o save real do jogador:

```
godot --path . --resolution 1280x720 --script res://tests/cliques.gd
```

## Rodar o jogo

```
godot --path .
```

Ou abra a pasta no editor do Godot e aperte F5.

## Sessao, tela inicial e save

* Existe um unico slot: `user://sessao_postinho.dat`.
* Ao abrir o jogo, a tela inicial aparece sempre. Com save, oferece **Continuar
  sessao** ou **Nova sessao**; sem save, oferece **Comecar o dia**.
* O jogo salva sozinho a cada 20 s, ao fechar a janela e ao sair pelo sistema.
* Continuar restaura equipe, pacientes, criancas, salas, PCs, impressora e o jogador.
* Pacientes e criancas de saves antigos que ainda tinham nomes como "Paciente 3"
  recebem nomes ficticios ao continuar.
* A tela inicial e o menu pausam a simulacao. Dialogos, papos, consertos e o arquivo
  de exames **nao pausam**: o posto continua rodando. Nao existe botao de pause.

## Nomes, equipe e animais

* `npcs.json` tem pools de nomes femininos, masculinos e neutros, alem de sobrenomes.
  Pacientes, criancas e funcionarios recebem nome + sobrenome.
* Criancas herdam o sobrenome do adulto que as acompanha; quando sao animais, tambem
  costumam herdar a especie.
* A equipe e sorteada a cada nova sessao: chefe, medica, enfermeira e o restante dos
  cargos mudam de pessoa, mas os IDs dos cargos continuam estaveis para as demandas.
* Pelo menos 8 dos 20 funcionarios sao animais antropomorficos. Cerca de 34% dos
  pacientes tambem sao animais. Todos sao tratados como pessoas normais.

## Os arquivos

| Arquivo | O que ajusta |
|---|---|
| `data/config.json` | Regras e numeros: energia, tarefas, cafe, pacientes, PCs, impressora, exame e equipe |
| `data/demandas.json` | Todas as falas e o que cada resposta rende |
| `data/papos.json` | Falas e perguntas dos funcionarios no corredor, com respostas sociais |
| `data/layout.json` | Posicao das salas, cadeiras, computadores, impressora, chegada de pacientes e HUD |
| `data/npcs.json` | Nomes, aparencias, especies animais, funcionarios e frequencias |
| `data/textos.json` | Textos fixos da interface (avisos, rotulos) |

## config.json

* `recurso.energia_max`: energia maxima (padrao 5).
* `recurso.energia_inicial`: com quanto o jogador comeca.
* `recurso.tarefas_max`: limite de trabalhos pendentes (padrao 10).
* `recurso.tempo_tarefa_s`: quanto dura uma tarefa (padrao 5 s).
* `recurso.custo_tarefa`: energia por tarefa (padrao 0,5).
* `recurso.rendimento_trabalho_por_segundo`: fracao da tarefa por segundo. 0,5 = 2 s por tarefa.
* `esforco.bonus_velocidade` / `bonus_custo`: 0.2 = 20% mais rapido e 20% mais gasto.
* `esforco.duracao_s`: quanto dura cada clique de esforco.
* `copa.tempo_cafe_s` / `ganho_cafe`: tempo do cafe e energia recuperada.
* `demandas.intervalo_min_s` / `intervalo_max_s`: sorteio do proximo encontro.
* `demandas.tempo_vida_min_s` / `tempo_vida_max_s`: quanto tempo uma demanda de funcionario dura antes de sumir.
* `papo.intervalo_min_s` / `intervalo_max_s`: espera de cada funcionario para puxar outro papo.
* `papo.duracao_s`: tempo para responder antes de o balao de papo sumir.
* `papo.max_ativos`: quantos baloes de conversa podem existir ao mesmo tempo.
* `presenca.*`: chegada de pacientes e tempo de atendimento.
* `computadores.distribuicao`: `um_interno` 40, `uma_recepcao` 40, `um_de_cada` 10, `nenhum` 10.
* `computadores.chance_problema`: chance de um PC apresentar problema (0.10 = 10%).
* `computadores.fator_problema_leve`: problema leve deixa o PC a 50% do rendimento.
* `impressora.*`: intervalo entre quebras, chance de quebrar e quantidade de fios (3).
* `exame.*`: quantidade de pastas e custo de energia por erro.
* `sessao.salvar_a_cada_s`: intervalo do autosave.
* `equipe.*`: quantos funcionarios/animais a sessao sorteia.
* `interrupcao.chance_funcionario_por_segundo`: 0.025 = 2,5% por segundo (media de 1 a cada 40 s).
* `interrupcao.chance_paciente_por_segundo`: chance por faixa de computadores livres na recepcao.

## demandas.json

Cada demanda tem `texto`, `opcoes` e, em cada opcao, uma `consequencia`:

* `{"tarefas": [1, 3]}`: ganha de 1 a 3 trabalhos (sorteio).
* `{"energia": 0.5}`: ganha energia.
* `{}`: nada acontece.

Campos extras:

* `tempo_vida`: segundos ate a demanda sumir sozinha (0 = nunca some).
* `frequencia`: peso; 0 desliga a demanda.
* `condicao`: so aparece quando a condicao vale, ex. `{"energia_acima_de": 4}`.
* `sem_pc`: a tarefa so gasta energia, sem gerar trabalho no computador (ex.: buscar cafe).
* `custo_energia`: energia gasta por uma tarefa `sem_pc`.
* `tipo_tarefa`: `"exame"` abre o arquivo de exames em vez de um trabalho comum.
* `paciente_fundido_texto`: fala do paciente quando voce recusa o pedido.
* `pacientes_seus_texto`: fala do paciente quando voce aceita.

Para criar um funcionario novo, adicione uma entrada em `npcs.json` (`funcionarios_sala`)
e uma sala em `layout.json`. Depois pode criar demandas com `"personagens": ["id_novo"]`.

## papos.json

Papo de corredor e a conversa espontanea dos funcionarios. O balao continua sem palavras:
usa o icone de fala para um comentario e o de pergunta para uma duvida. Clicar na pessoa
abre uma janela com duas respostas sociais; depois da escolha, o funcionario devolve uma
replica. O posto continua rodando durante a conversa e o papo nao gasta energia nem cria
tarefas. Pacientes sentados, em pe ou na fila tambem puxam conversa de espera.

As categorias seguem o cargo: `chefe`, `medica`, `enfermeira`, `guiche`, `recepcao`,
`acs`, `vacina`, `procedimentos`, `equipe` (reserva) e `animal`. Cada entrada tem:

```json
{
  "id": "medica_implanon",
  "tipo": "fala",
  "texto": "O implante de etonogestrel, o famoso Implanon, esta disponivel em alguns servicos.",
  "opcoes": [
    {"texto": "Explico isso com cuidado e sem julgamento.", "resposta": "Perfeito. Contracepcao e escolha, nao palpite."},
    {"texto": "Vou dizer que e um piercing cientifico.", "resposta": "Por favor, nao. Ja temos poodle de moicano demais nessa historia."}
  ]
}
```

* `tipo`: `fala` mostra o balao de conversa; `pergunta` mostra o balao de interrogacao.
* `opcoes`: sempre duas respostas sociais, cada uma com a `resposta` do funcionario.
* Um funcionario nunca repete o ultimo papo seguido, mas pode voltar a ele depois.
* Uma demanda formal interrompe o papo daquela pessoa.
* O total de conversas respondidas aparece em `Informacoes e estatisticas` como
  "Conversas de corredor".

## Computadores, impressora e exames

* Sao 3 PCs internos para os ACS e 3 de recepcao. O jogador tambem pode usar PCs de
  salas vazias, exceto o da sala da chefe.
* PC com problema leve rende 50%; com problema grave fica inutilizavel. Nenhum
  problema pode inutilizar o ultimo PC interno funcional.
* Conserto de PC e impressora usam um minijogo de 3 fios coloridos: repita a ordem
  das luzes. Um erro reinicia a sequencia e gasta um pouco de energia.
* A impressora quebra com frequencia, avisa no HUD e so volta com o minijogo.
* O arquivo de exames e uma grade de 30 pastas: ache a pasta creme com a cruz verde.
* O jogo nao exige a resposta "certa" nas conversas: sao escolhas sociais, nao prova.

## HUD e camera

* O HUD mostra fila do guiche ou "Sagao tranquilo", energia, trabalhos e esforco.
  Nao ha contador de PCs livres nem relogio de tempo jogado.
* Arraste para explorar; pince para aproximar. Botoes no canto voltam ao jogador
  e centralizam a camera.
* Menu inferior direito: personalizar personagem, aparencia, regras, sons,
  informacoes/estatisticas, Google Play e contato.
* Um banner no topo avisa quando a impressora quebra e leva a camera ate ela.

## layout.json

Coordenadas em pixels do mundo 1440x900. A construcao fica em 24,24 com 1392x852;
o saguao ocupa 520,34 com 872x832. As salas ficam a esquerda, o guiche no topo e os
PCs internos/recepcao no centro. Sao 42 cadeiras e 14 lugares em pe.
A copa fica recuada da sala de Procedimentos, deixando um corredor livre para a
porta da sala e para a circulacao de quem vai pegar cafe.

* `salas`: cada sala tem `id`, `nome`, `tipo`, posicao, cor, porta, cadeira(s) e
  `paciente_spots`. As salas A/B/C/D/F/E sao Chefe, Medica, Enfermeira, Vacina,
  Procedimentos e Copa.
* `guiche`: posicao do balcao, do funcionario e da fila.
* `pcs`: 3 internos e 3 de recepcao, mais os PCs das salas. O campo `mesa` desenha
  a mesa comprida; o jogador senta no lado longo.
* `cadeiras` / `espacos_em_pe`: lugares do saguao. Pacientes preferem cadeira.
* `impressora`: posicao da impressora do balcao.
* `entrada`: porta de entrada no canto superior direito.
* `porta_lateral`: porta decorativa que mostra o aviso de versao futura.

## Textos com acento

Os textos estao sem acento por seguranca, porque o programa lida melhor assim.
Se quiser acentos, pode editar direto no JSON; o Godot le UTF-8 normalmente.

## Gerar os pacotes

* Windows exe: `godot --headless --path . --export-release "Windows Desktop" build/windows/PostinhoDeSaude.exe`
* MSIX: `powershell -ExecutionPolicy Bypass -File tools\build_msix.ps1` (gera `build\msix\PostinhoDeSaude_1.0.1.0_x64.msix`).
  Para instalar numa maquina, o certificado público `build\msix\PostinhoDeSaude-teste.cer` precisa estar em
  `LocalMachine\Root` e `LocalMachine\TrustedPeople` (como administrador). O `.pfx` com a chave
  privada fica fora do repositório, no cofre local de credenciais.
  Para publicar na Loja, use um certificado comprado (o manifesto precisa usar o mesmo `Publisher`).
* Android AAB: `powershell -ExecutionPolicy Bypass -File tools\build_android_aab.ps1`
  (gera `build\android\PostinhoDeSaude.aab`, assinado com o keystore do cofre local).
  O AAB e assinado no formato JAR; confira com `jarsigner -verify`, nao com `apksigner`.
* APK universal: o próprio `build_android_aab.ps1` gera `build\android\PostinhoDeSaude-1.0.1.apk`
  com o bundletool e assina com a chave de release. O `.apks` intermediário fica em
  `build\android\PostinhoDeSaude.apks`.
* Pasta de entrega: `powershell -ExecutionPolicy Bypass -File tools\preparar_entrega.ps1`
  copia AAB, APK, MSIX e `.cer` para `build\entrega\` com nomes estáveis e gera
  `SHA256SUMS.txt`. Nenhum segredo é copiado.

O keystore de release e as senhas ficam fora do repositório, no cofre local
`ID.OAuth/postinho`. Sem eles não é possível publicar atualizações no Google Play.

## Capturas para revisao visual

```
godot --path . --script res://tests/capturar.gd -- build/capturas
```

O roteiro gera tela inicial, visao geral, trabalho, dialogos, menu, papos, salas de
vacina/procedimentos, corredor da copa, conserto da impressora, arquivo de exames e
HUD sem relogio.
