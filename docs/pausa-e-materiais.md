# Pausa no prólogo, cor dos materiais e compatibilidade da CPU

Windows, instalação 1.0.2.1, Direct3D 12 na RTX 3060 de 12 GB e perfil Series X. Resultados de 24 de novembro de 2026.

## Controle antes da correção de vistas

Na saída nativa, o letreiro “Vice City, dois anos atrás” apareceu. Após a primeira submissão com malhas, Esc (Start/Menu no mapeamento de teclado) mudou a imagem para um fundo escuro azulado. Durante os 87 s até a próxima sequência de entrada, não apareceram abas, mapa ou letras legíveis. O segundo Esc tirou o fundo de pausa. Entre os dois marcadores de entrada, 159 números de quadro apareceram nas listas rastreadas. Foram emitidos 3 desenhos indexados com o pixel shader de texto `fb0b42420f99e5e7`, 225 com `46447d58f4954cd1` e 45 com `a4f5af12e67c8723`. A emissão implica pipeline disponível. Ainda é preciso demonstrar onde os pixels da interface deixam de chegar à janela. Há um relato de pausa legível em outra configuração. O PR de composição de planos tem confirmação independente para a tela de perfil do Series S. [Pausa em outra GPU](https://github.com/Marvisak/VIctory/issues/71#issuecomment-7122047282) · [Composição de planos, PR #211](https://github.com/Marvisak/VIctory/pull/211).

Com o mesmo executável Materiais e o mesmo perfil, mudar apenas o seletor de `2560x1440:28:0` para `2560x1440:27:0` trocou as faixas azuis/verdes por braços em tom de pele e tronco cinza sobre preto. Os números 28 e 27 são os formatos de armazenamento RGBA8 UNORM e TYPELESS. O índice 0 escolhe o primeiro recurso registrado do formato. Num quadro da sonda, o recurso selecionado em 28 também estava no slot MRT1 da personagem, enquanto MRT0 era typeless. Em outra submissão, no slot 1 a sexta amostra da grade 4 × 4 passou de zero para 846068973 após a malha `6b57e37fe499c6e7` e o pixel shader `573d1857e903fab5`. A semântica de normal e o caminho completo de UV, mip e texel até a cor final continuam sem confirmação.

| Objeto identificado no catálogo | Mesh shader | Pixel shader |
| --- | --- | --- |
| Personagem, PedTransformPreSkinD / DeferredPedTexturedNC | `51ff151f75cd5759` | `7fe75645c406cac6` |
| Cabo da rua, Cable / Cable_Deferred | `38ad582f523fd7cf` | `d42a2d8a9d2c954a` |

O seletor de diagnóstico substitui a saída do título. Para reproduzir a pausa, use a saída nativa. O quadro com braços e tronco veio do alvo intermediário. O cenário iluminado, as roupas texturizadas e o mundo jogável ainda não foram verificados. [Saída final em outra RTX, issue #841](https://github.com/Marvisak/VIctory/issues/841).

## Resultado com vistas de formato explícito

Na execução `menu-vistas-series-x`, SondaMateriais com a adaptação do PR #876 e a saída nativa mostrou **Mapa, Jogo, Loja, Ajuda, Estúdio de fotos e Configurações** em português. A seleção apareceu em mais de uma linha nas capturas da janela. O mecanismo de apresentação registrou um plano em todas as 101 amostras, inclusive as seis após o pedido de pausa. O PR #211 trata a composição de dois planos observada em outra configuração. Nesse ensaio Series X a interface chegou à janela com um único plano. O mapa aberto e o cenário 3D com materiais completos ainda não foram comprovados. A execução terminou com a escrita em zero em `+0x23cf683`.

Ao reiniciar com o mesmo binário e cache aquecido, a janela exibiu o letreiro e voltou ao preto. Foram enviados dois pedidos de pausa com durações diferentes, e a execução terminou com dispositivo removido, motivo DXGI 0x887A0006, após 21 listas. A leitura ao vivo de quatro endereços apontados por vistas de UI encontrou dados diferentes de zero em duas regiões BC3/BC7 e apenas zeros nos primeiros 1.024 bytes de outras duas texturas BC7. Isso identifica dados de origem no momento da leitura. Ainda falta comprovar o texel amostrado naquele desenho. A visibilidade do menu é intermitente.

O binário desse ensaio tem SHA-256 `35afd62ae3b8c0d77a65ee56a346f53ae044649b6ead53f9f2f52306d32f574a`. Os dois shaders texturizados de UI geraram o mesmo DXIL por BLAKE3. Entre as vistas que o jogo forneceu, o texto usou um atlas A8 de 2048 × 2048. O shader `fb0b42420f99e5e7` lê o canal alfa da amostra e o multiplica pelo alfa de entrada. Um desenho de interface usou BC7 UNORM de 260 × 256, layout `0x105`, no slot 587151. O DXIL, as texturas e as imagens da janela ficam no laboratório. A sonda imprime tamanho, formato, slots e planos com `VICTORY_PASS_TRACE=1`. [Adaptação e rastreio](../patches/vistas-e-pausa-876.patch) · [PR #876](https://github.com/Marvisak/VIctory/pull/876).

## Textura que chega após o descritor

Um teste D3D12 cria uma vista de textura de 4 × 4 sobre uma reserva ainda sem memória confirmada. A primeira amostragem retorna zero. O teste confirma a memória, escreve o primeiro texel e executa o mesmo compute de teste usando o mesmo descritor. Na base, a GPU continuou lendo `0x00000000` depois de quatro apresentações. A referência era `0x78563412`.

Em `descriptor/host.rs::prepare_bindless_record`, o slot saía da fila de trabalho após receber uma vista nula. Agora a variante guarda o slot e a geração quando há um endereço plausível cuja memória ainda não está disponível. Após quatro apresentações pode rever até oito entradas por quadro, dentro do orçamento do heap. A fila tem no máximo uma entrada por slot. Ao revisitar, confere a geração, materializa a vista e encaminha o upload pelo caminho normal. No teste corrigido, o shader leu `0x78563412` sem reescrever o descritor. Os cinco testes selecionados com `placed_` passaram. A cobertura dessa corrida na cutscene depende da ocorrência do marcador `placed texture became resident on retry`. [Patch e teste de regressão](../patches/texturas-residencia-tardia.patch).

A árvore publicada da variante SondaMateriais é `0c3b293b7752d3c4e39fb6ebc3a82b6f6f59cd50`. Ela combina o backport CLWB, as vistas de formato explícito, o rastreio de UI e a repetição limitada para residência tardia. A saída padrão da variante é a imagem nativa. Os alvos de diagnóstico continuam disponíveis via `VICTORY_PRESENT_TARGET`.

O launcher público compilou essa árvore do zero. O executável produzido neste computador teve SHA-256 `06e26fc86cb396032221b7559b101915355e7a6b98d8bd9753263d163aa400c5`. Na suíte completa antes de ajustar o teste antigo de serialização, passaram 58 de 59. O teste antigo montava um parâmetro de root signature com alinhamento incorreto no Windows x64. Em uma cópia isolada da mesma árvore, a correção upstream apenas do teste levou a 59 de 59. [Patch para a suíte da equipe](../patches/teste-assinatura-d3d12.patch) · [Correção upstream](https://github.com/Marvisak/VIctory/commit/f0d41db411746ef9c3b07591b18e65aa603d84d4).

## Tradução e submissão

A árvore Materiais `6fc6ceb882461675a417fe9160a194aea8df43ea` produziu 24.718 traduções e 1.267 recusas. Na árvore instrumentada `0f0759317e029bad792e88313e70b6c2e97160ec`, o tradutor de malhas importado da revisão `d1fecaa1ef231f8ad24736d58e9d8e1e149938bd` recuperou 174 malhas. Foram 24.892 aceitos e 1.093 recusados, sem perdas por hash no mesmo catálogo de 25.985. O executável que gerou o rastreio teve SHA-256 `1c6e05a51d4870432ce7da5993fbd8e500bd0b6f1b8ac0e9370d01d9b4c9e50d`. As mudanças posteriores de loader e de vistas estão descritas acima.

O validador DXIL e a criação isolada de pipeline no driver passaram para 183 entradas do cache efetivamente usado, incluindo as 174 recuperadas. As combinações do jogo exigem verificação separada. O comando indireto foi emitido 427 vezes para `910b4be059bfb28f` e 220 para `321d411b20a35ef9` no período rastreado. A contagem não mede grupos efetivos ou cobertura de pixels. Os itens locais 2400, 2401 e 2402 neste catálogo são respectivamente `6090b5a95d346286`, `d10a91ed62fa6c29` e `f851519164999225`. Os três já eram aceitos na base. [Resultados de validação por hash](validacao-sonda.tsv).

Das 189 recusas registradas no log original, 172 chegaram ao primeiro vínculo. Na janela amostrada em outra execução, 153 das 189 reapareceram em comandos solicitados e nenhum desses 153 foi emitido. Para as outras 36 faltou evidência de solicitação nessa janela. Entre todas as 1.267 recusas originais, quatro malhas passaram a ter emissão observada. O CSV informa separadamente solicitação, vínculo e emissão. Os 227 estágios antes desconhecidos se dividem em 195 geometria, 29 compute, 2 pixel e 1 vértice pelo cabeçalho PSV0. Entre os primeiros motivos de recusa na base estão 283 descritores sem origem reconhecida, 198 contêineres sem programa VS/PS/CS/MS, 178 larguras de wave indisponíveis e 117 buffers estruturados sem stride conhecido. [Rastreio por hash](comandos-materiais.csv) · [PR #233](https://github.com/Marvisak/VIctory/pull/233).

No adaptador físico, WaveOps ativo, mínimo 32 e máximo 32. Na revisão `c04788537417107677d8dc5a90484f217ee22d2f`, 23 testes de Wave64 passaram com o validador obrigatório e o caminho de hardware. O conjunto inclui ballot, acessos entre metades, máscaras de execução e barreiras LDS. [Patch do ensaio](../patches/wave32-verificacao-rtx.patch).

## Reprodução

Na raiz deste repositório, em PowerShell, com um perfil de teste já configurado em português:

```powershell
.\VIctory.ps1 -Acao Compilar -Variante SondaMateriais
$jogo = Read-Host 'Diretório da instalação própria'
.\VIctory.ps1 -Acao PrepararShaders -Variante SondaMateriais -PastaJogo $jogo
$env:VICTORY_PRESENT_TARGET = 'nativo'
$env:VICTORY_PASS_TRACE = '1'
.\VIctory.ps1 -Acao Executar -Variante SondaMateriais -PastaJogo $jogo -Console series-x 2>&1 | Tee-Object -FilePath pausa.log
```

Acione Start/Esc ao primeiro letreiro da missão. O log usa `pass list submitted` para associar eventos à ordem de submissão e às posições de render target. Em uma execução separada, use `$env:VICTORY_PRESENT_TARGET = '2560x1440:28:0'` e `$env:VICTORY_PIXEL_GRID = '1'` para ler pixels antes e depois de malhas selecionadas. Compare com `2560x1440:27:0` mantendo a mesma configuração. A execução com grade tem custo de leitura extra. A comparação de desempenho usa outra compilação, sem grade.

## Issues e divisão do trabalho

- **Loader e CPU.** O endereço `+0x4ecc84a` da captura da issue #1 contém `CLWB [r9]`. O upstream já trata o loop. As variantes Execucao e SondaMateriais levam o backport, com testes de comprimento, reconhecimento do loop e fim de página com página seguinte inacessível. Recompile e verifique no computador afetado se a inicialização passa do endereço. [Issue #1](https://github.com/luiksksk/gta6-victory-rtx3060/issues/1) · [PR #45 integrado](https://github.com/Marvisak/VIctory/pull/45) · [Mesmo endereço no upstream](https://github.com/Marvisak/VIctory/issues/210) · [Decodificação no limite da página](https://github.com/Marvisak/VIctory/commit/60d2cf9cbcf5a2abc773d5de10c3c892e77d3340).
- **Interface e composição.** Em `queue.rs::present`, conte os planos passados a PresentX. Em `draw.rs::draw_indexed`, associe os três hashes de UI ao atlas SRV, ao RTV, ao alpha e à lista/fence. Leia o mesmo pixel dentro de um glifo antes e depois do desenho e na composição 4K. Critério de aceitação: mapa e abas legíveis, navegação e retorno à cena no Series X com a saída nativa. [PR #211](https://github.com/Marvisak/VIctory/pull/211) · [Issue #850](https://github.com/Marvisak/VIctory/issues/850).
- **Materiais e iluminação.** Preserve os slots vazios quando testar `draw.rs::set_targets`. Em uma passagem que realmente escreve a cor, correlacione recurso, índice de descritor, mip residente, UV e texel com MRT0/MRT1. Para HDR, confira o produtor dos argumentos indiretos e a fence consumidora. A captura histórica de `731a391…` retornou `[0,1,1]`; os próximos alvos são `df11dcd012cd7382`, `5970ee6dbc47ec61` e `4f4ec7b16673362f`. O PR #876 trata vistas typeless. Três testes locais passaram para a adaptação, mas outros testadores ainda veem preto com esse PR. [PR #876](https://github.com/Marvisak/VIctory/pull/876) · [Reteste da issue #850](https://github.com/Marvisak/VIctory/issues/850#issuecomment-7136455781).
- **Estabilidade.** Os dois controles de cor terminaram com escrita em zero em `+0x23cf683`, seguindo por `+0x2215c35` e `+0x2215eca` na pilha. A pausa nativa terminou com remoção do dispositivo após sete listas, motivo DXGI `0x887A0006`, sem breadcrumb recuperável. O caso histórico de DispatchMesh parou no marcador 8/83, com outros dispatches entre as mesmas barreiras. Colete a pilha da falha de CPU separadamente do DRED, do último lote e dos argumentos da GPU. [Falha de GPU em outra NVIDIA](https://github.com/Marvisak/VIctory/issues/1062) · [Root SRVs fora dos limites em outra máquina](https://github.com/Marvisak/VIctory/issues/951).

Os tempos de CPU, as esperas por fence e o ensaio de offload estão na [medição de uploads e ocupação da RTX](cpu-gpu-e-uploads.md).
