# Shaders da primeira missão e Wave64 na RTX 3060

**Em 30 segundos após desaparecer “Vice City, dois anos atrás”, 76 shaders apareceram pelo hash nos registros de chamadas descartadas por falta de pipeline.** Na variante padrão, 65 desses shaders falham na tradução e 11 produzem DXIL que exige Wave64. A primeira cutscene ainda aparece escura. [Lista dos 76 hashes, erros e taxas observadas](shaders-primeira-missao.csv)

## Quais shaders afetam a missão?

O ensaio `argumentos-hdr` usou a sonda sobre a revisão `35b054ec`, o modo Series X e uma RTX 3060 de 12 GB. A captura da janela fornece o instante em que a legenda desapareceu. Para identificar o impedimento de cada shader na versão oferecida para jogar, cruzamos os hashes desse ensaio com o catálogo e os testes da variante `Execucao`, baseada em `015d45bf`. As taxas abaixo são a maior média por quadro que o relatório atribuiu àquele motivo no trecho. O relatório nomeia apenas parte dos descartes.

| Shader | Trabalho identificado | Impedimento na variante padrão | Maior taxa informada por quadro |
| --- | --- | --- | ---: |
| `910b4be059bfb28f` | Malha de profundidade de personagem | O tradutor perde a origem de um descritor em `0x2830`. | 375 |
| `3b90165a77d95cdf` | Compute da biblioteca de construção de BVH | O endereço em registrador escalar não corresponde a um parâmetro raiz reconhecido, em `0x30`. | 239 |
| `e30970f1727063fd` | Transformação de impostores | O tamanho de cada elemento do buffer estruturado é desconhecido em `0x61c`. | 144 |
| `321d411b20a35ef9` | Outra malha de profundidade de personagem | A origem do descritor fica indeterminada em `0x2570`. | 122 |
| `c9da71da40af2e28` | Compute | O DXIL exige uma wave de 64 lanes. A RTX recusou o pipeline. | 48 |

Há ainda uma falha medida fora dessa lista. A passagem HDR `731a39171b568298` já tinha pipeline, mas recebeu `[0, 1, 1]` em oito despachos indiretos. Com zero grupos no eixo X, essa passagem não executou trabalho. Para explicar por que chega zero ali, ainda é preciso identificar a escrita no buffer de argumentos que antecede o despacho. [Rastreamento dos pixels até a composição](diagnostico-rtx3060.md#onde-a-imagem-se-perde)

## O que são 2400, 2401 e 2402?

O VIctory registra o hash do conteúdo. O número de ordem depende da ferramenta, da versão do jogo e do tratamento de duplicatas. Estas são duas contagens começando em **1**, verificadas em `shaders.rpf` da v1.0.2.1.

| Ordem dos shaders únicos | Registro no arquivo | Hash | Resultado isolado na RTX 3060 |
| ---: | ---: | --- | --- |
| 2400 | 2429 | `6090b5a95d346286` | Shader de vértices. Tradução e validação passaram. O driver criou o pipeline gráfico. |
| 2401 | 2430 | `d10a91ed62fa6c29` | Shader de malha para reflexo de personagem. A tradução parou em `0x3144` ao usar uma leitura de memória escalar como dado. |
| 2402 | 2431 | `f851519164999225` | Outra variante de malha para reflexo de personagem. Mesmo erro em `0x6350`. |
| 2371 | 2400 | `7ae4247ec464f132` | Shader de malha. Validação e criação de pipeline passaram. |
| 2372 | 2401 | `3bd7996ab42d5e2e` | Shader de malha. Validação e criação de pipeline passaram. |
| 2373 | 2402 | `ca4ce120baf69de0` | Shader de malha. Validação e criação de pipeline passaram. |

Os seis programas originais declaram Wave64. Nos quatro que o tradutor aceitou, o DXIL deixou livre a largura da wave. Para o teste gráfico, o shader de pixels complementar era mínimo. O teste verifica a criação do pipeline na placa. Executar o material completo e comparar seus pixels exige outro ensaio. Os hashes da ordem única 2400–2402 não apareceram nos três logs da missão examinados. A ferramenta usada pelos desenvolvedores que citaram os números continua desconhecida.

## Até onde vai o problema de Wave64?

Na consulta `D3D12_FEATURE_D3D12_OPTIONS1`, a RTX 3060 deste teste informou `WaveLaneCountMin = 32` e `WaveLaneCountMax = 32`. O shader pode usar 64 lanes no Xbox e ainda gerar DXIL executável com 32 quando o resultado independe da largura. Quando o DXIL exige explicitamente 64, o dispositivo precisa oferecer essa largura. [Consulta de recursos do Direct3D 12](https://learn.microsoft.com/en-us/windows/win32/api/d3d12/ns-d3d12-d3d12_feature_data_d3d12_options1) · [Especificação WaveSize da Microsoft](https://microsoft.github.io/DirectX-Specs/d3d/HLSL_SM_6_6_WaveSize.html)

| Variante padrão, instalação v1.0.2.1 | Shaders distintos |
| --- | ---: |
| Encontrados no arquivo de shaders, executável e DLLs locais | 25.985 |
| Rejeitados pelo tradutor | 3.825 |
| Traduzidos com exigência fixa de 64 lanes | 321 |
| Traduzidos com exigência fixa de 32 lanes | 159 |
| Traduzidos sem restrição de largura declarada no DXIL | 21.680 |

Testamos **cada um dos 321** no validador DXIL da Microsoft e na criação de pipeline de compute no dispositivo físico. O driver recusou todos. O validador aceitou 315 e apontou também incompatibilidades de estágio ou de propriedades de entrada em seis. Ao repetir a tradução com o caminho da variante `Diagnostico` para adaptadores de 32 lanes, **25 passaram a criar pipeline e 296 continuaram recusados**. A adaptação cobre algumas trocas de dados em grupos de 64 threads, usando memória compartilhada e barreiras. A criação do pipeline confirma que o driver o aceitou. A imagem e os valores de saída dependem de um teste de execução.

Dos 321, **114** apareceram em mensagens explícitas de recusa do driver ao longo da sessão completa da sonda. Entre os **11** presentes nos descartes nomeados nos 30 segundos da missão, apenas `13dfdd3b1136e407`, de geração de mipmaps, passou com a adaptação de diagnóstico.

## Como ler o catálogo

A lista completa reúne **4.146 impedimentos conhecidos na variante padrão**, com o hash de 16 caracteres usado pelo VIctory, estágio, motivo, arquivo e posição. Entre os 3.825 erros de tradução há 1.913 shaders de pixels, 1.049 de compute, 574 de malha, 62 de vértices e 227 cujo estágio não foi identificado pelo leitor usado. Uma tradução bem-sucedida ainda pode falhar na validação, na combinação dos estágios ou durante a execução. [Catálogo completo de pendências](shaders-com-pendencias.csv)

- `descarte_missao_30s = 1` indica um hash citado num motivo de descarte nos 30 segundos após a legenda. A coluna da taxa contém a maior média publicada pelo relator de desempenho para aquele motivo.
- `recusa_driver_sessao_sonda = 1` indica recusa explícita em algum momento da sessão completa. O valor 0 indica ausência desse registro na amostra.
- As três últimas colunas mostram o validador e os testes isolados dos 321 shaders Wave64 nas variantes indicadas. Células vazias indicam que o ensaio não se aplica.
- A ordem usa a primeira ocorrência de cada shader encontrado. O registro conta ocorrências dentro do arquivo indicado. Para comparar builds ou catálogos, use o hash.

## Como a preparação foi verificada

Na entrada normal `run --execute`, o build padrão percorreu todos os percentuais de 0 a 100. Os 25.985 shaders foram processados em **135,86 s** com cache frio. O executável do título foi mapeado depois de 100%, e a janela do jogo apareceu aos **138,67 s**. O teste foi encerrado normalmente pelo laboratório após capturar os primeiros quadros. Na preparação seguinte, o lançador levou **4,41 s** e preservou os 25.985 arquivos do cache sem reescrevê-los. Com `shaders.rpf` ausente, a preparação encerrou com código 1 antes de mapear o título.

Build de execução testado, SHA-256 `196446f7dbcea5ff7d1f361453bb9ddef62eca5a59bc87016996a36628a74144`. A compilação é local, a partir do código e dos patches publicados. [Manual de instalação e uso](../MANUAL.md)
