# Primeira cutscene na RTX 3060 · 23 de novembro de 2026

Depois que desaparece “Vice City, dois anos atrás”, o jogo continua preparando quadros, mas parte das chamadas de desenho é descartada e uma passagem HDR chega à GPU com zero grupos de trabalho. A composição final recebe uma imagem quase preta. A primeira cutscene segue sem personagens e cenário visíveis. Os três ensaios abaixo usaram **VIctory, Direct3D 12, RTX 3060 de 12 GB e Ryzen 5 5600GT**. O Leonida não participou desse caminho de renderização.

## Por que a CPU trabalha enquanto a GPU tem pouco serviço

No ensaio `argumentos-hdr`, o processo acumulou **158,45 s de CPU em modo usuário e 42,97 s em modo kernel durante 29,56 s**. Threads executadas ao mesmo tempo somam seus tempos. Isso equivale a **6,81 dos 12 processadores lógicos ocupados**, ou **56,8% da capacidade total**. No mesmo trecho, o Windows agendou **3,68 s de trabalho do processo no motor 3D em 29,66 s**, cerca de **12,4%**. A telemetria da NVIDIA registrou mediana de **21% de utilização da placa inteira**.

O VIctory traduz os shaders do Xbox, pede ao driver que crie os pipelines e verifica quais partes da memória do título precisam chegar aos recursos do PC. Nesse ensaio houve 567 chamadas de tradução, com 167 falhas, e 237 tentativas de criar pipelines no driver, com 13 falhas, entre dois retornos de Present separados por 28,96 s. As traduções acumularam 163,55 s de tempo de parede entre workers concorrentes. Esses cronômetros incluem espera e se sobrepõem aos das etapas que os chamam.

Na mesma amostragem, **12.176 chamadas de malha**, **36.794 de compute** e **1.498 de desenho** chegaram ao caminho de execução sem um pipeline de host disponível. Isso inclui pipelines ainda em preparo e pipelines que falharam. Uma chamada indireta pode representar várias operações. A CPU também repetiu verificações de memória. O resumo emitido a +25,62 s contabilizou, em média por quadro daquele intervalo, **28.926 MB de intervalos verificados, dos quais 28.254 MB estavam inalterados**. O contador soma as verificações, inclusive de áreas repetidas. O tráfego físico no barramento PCIe exigiria outra medição.

O resultado combina trabalho de preparação no processador e pouco trabalho útil entregue à placa. A contribuição de cada tarefa para o tempo total de CPU ainda requer um perfil com pilhas por thread. Nenhuma destas medidas é um timestamp de execução de um shader na GPU.

| Primeiros 30 s após a legenda | Motor 3D do processo | Mediana entre Presents | p95 | Intervalos completos |
| --- | ---: | ---: | ---: | ---: |
| A · origem da composição | 14,3% | 904 ms | 1.612 ms | 28 |
| B · dois pipelines disponíveis a tempo | 19,8% | 1.346 ms | 1.708 ms | 20 |
| C · leitura dos argumentos HDR | 12,4% | 1.400 ms | 2.303 ms | 19 |

Cada rodada partiu de uma cópia do mesmo perfil e cache aquecido, em Series X, com alvos de 2560 × 1440 e composição de 3840 × 2160. A captura da janela situa a legenda, e os intervalos vêm de chamadas consecutivas de Present. O WDDM fornece tempo agendado por motor e PID. A NVML fornece utilização da placa. Todas as rodadas usaram instrumentação, com mais leituras nas duas últimas. As diferenças entre as linhas não isolam um ganho ou perda de FPS do patch. [Dados agregados, contagens, amostras e hashes dos builds](medicoes-rtx3060.json)

## Onde a imagem se perde

1. **A composição executou.** No ensaio A, o pixel shader `4f4ec7b16673362f` recebeu a mesma textura RGB10A2 que dois pipelines anteriores tentaram preencher. Os dois desenhos foram descartados oito vezes cada nesse alvo. As 35 leituras da entrada da composição, cinco pontos em sete chamadas, retornaram zero. No alvo de saída RGBA8, o RGB chegou a 1 em 255 nos pontos lidos.
2. **Fazer os dois desenhos executarem mudou os pixels.** No ensaio B, a sonda preparou os pipelines dos pixel shaders `43b4c00d725ac9c7` e `5510a9fd27ceb4b1` antes de usá-los. Ambos desenharam no alvo medido. A textura passou a conter valores diferentes de zero e o RGB da saída chegou a 2 em 255 nas 40 amostras. A janela continuou escura.
3. **Uma passagem anterior recebeu zero trabalho.** No ensaio C, o compute indireto `731a39171b568298` tinha pipeline de host. Em oito chamadas, o buffer usado por `ExecuteIndirect` continha **[0, 1, 1]** antes e depois do limitador de segurança. O registro tinha 12 bytes, uma chamada máxima e nenhum buffer de contagem. Com zero grupos em X, o despacho executa zero grupos. Os 40 pixels lidos após essa passagem no alvo RGBA16F `s1+96dw` estavam zerados. O estágio seguinte `df11dcd012cd7382` também entregou 40 amostras zeradas em `s1+160dw`, uma entrada de `5970ee6dbc47ec61`.

A próxima medição é rastrear **quem escreve o primeiro inteiro do buffer de argumentos** antes desse despacho. É preciso observar o valor ao sair do produtor e ao entrar no limitador para distinguir contagem vazia legítima, produtor descartado e valor perdido na sincronização do buffer. Até aqui, está demonstrado que o zero já chega ao limitador. A origem de toda a perda da cena continua em investigação.

O ensaio A terminou mais tarde com `DXGI_ERROR_DEVICE_HUNG` após um lote de 27 listas. Os ensaios B e C foram encerrados normalmente pelo laboratório depois da captura. O comando que causou o travamento e a estabilidade durante cinco minutos de jogo continuam em aberto.

## Reproduzir a sonda

Para iniciar normalmente, siga o [manual de uso](../MANUAL.md). Para investigar os mesmos estágios, abra o PowerShell na pasta do repositório. Compile a variante da sonda.

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\VIctory.ps1 -Acao Compilar -Variante SondaHDR
```

Na mesma janela, execute as linhas abaixo. Use o caminho da sua instalação. O comando mostra o caminho do arquivo de gatilho antes de abrir o jogo e guarda o log em uma pasta nova.

```powershell
$ensaio = Join-Path $env:LOCALAPPDATA ("VIctory-RTX3060-Publico\ensaios\" + (Get-Date -Format yyyyMMdd-HHmmss))
New-Item -ItemType Directory -Path $ensaio | Out-Null
$env:VICTORY_LOG = "info"
$env:VICTORY_PERF = "1"
$env:VICTORY_TRACE_REQUIRED_PS = "43b4c00d725ac9c7,5510a9fd27ceb4b1"
$env:VICTORY_SCENE_TRIGGER = Join-Path $ensaio "acionar-alvos"
Write-Host "Arquivo de gatilho: $env:VICTORY_SCENE_TRIGGER"
.\Iniciar-VIctory.cmd -Variante SondaHDR -PastaJogo "D:\Jogos\GTA VI" *> "$ensaio\console.log"
```

Quando a legenda de localização desaparecer, **em uma segunda janela do PowerShell**, crie o arquivo com o caminho completo que apareceu na primeira. Substitua o exemplo.

```powershell
New-Item -ItemType File -Path "C:\caminho-mostrado\acionar-alvos"
```

A sonda arma após o próximo Present bem-sucedido e observa oito apresentações. Feche normalmente a janela do jogo ao terminar. Procure por `scene indirect arguments`, `scene texel` e `scene native Present returned` em `console.log`. Use uma nova sessão do PowerShell para voltar à execução habitual. O perfil, o cache e os shaders da sua instalação ficam na sua máquina. O ponto exato do gatilho manual e o conteúdo do cache podem variar entre execuções.

## Patches

O lançador aplica a [sonda HDR](../patches/sonda-hdr-35b054ec.patch) sobre a revisão `35b054ec038c11bc8a0de66b1eee764b1ad4f101`. O [patch de readback](../patches/readback-35b054ec.patch) é independente e se aplica à mesma revisão limpa. Ele corrige a cópia de uma região de textura de cor para um buffer, preservando os bytes de preenchimento. O teste `texture_readback_preserves_gpu_contents_and_guest_padding` passou na RTX. A rodada com esse patch terminou com remoção do dispositivo antes de validar a primeira cena. [Código-fonte da revisão](https://github.com/Marvisak/VIctory/tree/35b054ec038c11bc8a0de66b1eee764b1ad4f101)
