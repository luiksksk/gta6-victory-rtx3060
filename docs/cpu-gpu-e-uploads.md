# Por que a RTX fica esperando na primeira cutscene

Na fila direta de D3D12, `host.rs` prepara as listas e seus descritores, chama `ExecuteCommandLists`, sinaliza uma fence e espera sua conclusão. Depois, `shadow.rs::copy_back` compara regiões que a GPU pode ter escrito com a memória do título e publica as mudanças. Enquanto esse caminho serial prepara ou publica dados, o próximo lote pode ficar fora da fila. Desenhos descartados por falta de pipeline também reduzem o trabalho que chega à placa. A ocupação medida é o tempo ativo do motor 3D do processo nos contadores do Windows. O tempo da fence inclui execução, sinalização e espera no host.

## Teste de upload na RTX 3060

Mesmo executável, SHA-256 `890975d71cc2934f56f522b2335184370a274b8831fe7cc5f85fc3bdcf9e494e`, mesma cópia inicial de perfil e mesmo catálogo preparado, Series X e alvo `2560x1440:28:0`. O controle reenvia texturas limpas que já possuem staging. A alternativa só reenvia quando a detecção pede atualização. Um ensaio de cada modo. O instante zero é a primeira apresentação bem-sucedida do alvo da cena. CPU e motores cobrem dez segundos. Os contadores do runtime usam os intervalos completos entre apresentações dentro desses dez segundos.

| Medida | Reenviar limpas | Enviar alteradas |
| --- | ---: | ---: |
| Intervalos observados | 12 em 9,34 s | 10 em 9,79 s |
| Tempo médio entre apresentações | 778 ms | 979 ms |
| Motor 3D do processo | 24,5% | 13,8% |
| Motor de cópia do processo | 0,020% | 0,002% |
| CPU do processo sobre a capacidade total | 17,5% | 10,5% |
| Comandos de cópia de textura por apresentação | 1.633 | 411 |
| Extensão lógica verificada pelo write-watch por apresentação | 7,73 GB | 10,66 GB |
| Readback comparado por apresentação | 508,8 MB | 585,1 MB |
| Diferenças exatas nos bytes comparados | 0,390 MB | 0,347 MB |
| Bytes escritos de volta, em blocos | 1,63 MB | 2,28 MB |
| Preparação de planos bindless | 149 ms | 191 ms |
| Preparação dos registros de descritores | 117 ms | 123 ms |
| Espera acumulada por fence | 147 ms | 135 ms |
| Tabelas novas / comandos descartados por apresentação | 468 / 637 | 1.160 / 2.358 |

As duas janelas mostraram figuras com faixas sobre preto. A posição da câmera e a carga dos desenhos diferiram. A execução de controle terminou com leitura inválida em `+0x4e9b54a`, e a outra com `DXGI_ERROR_DEVICE_HUNG` após oito listas. A diminuição dos comandos de upload foi observada. Essa dupla de ensaios não permite atribuir uma regressão ou ganho estável de FPS ao patch. Intervalos lógicos do write-watch podem se sobrepor e páginas limpas podem ser descartadas por metadados. O contador do motor de cópia também exclui trabalho de cópia emitido pela fila direta. [Medições brutas](uploads-rtx3060.json) · [Comparação independente no upstream](https://github.com/Marvisak/VIctory/issues/400).

## Divisão do trabalho

**Primeiro, a imagem.** Escolher um desenho da personagem ou do cenário cuja passagem realmente escreve. Salvar o hash da textura no staging, o subrecurso e o mip após o detiling, o slot SRV no momento do `bind`, a fence que concluiu o upload e o texel no UV do desenho. Repetir essa leitura no MRT e na saída nativa do jogo. Se a textura chega válida a tempo, antecipar o pedido não explica onde a cor se perde. Se chega tarde, testar uma fila de pré-carregamento com os pedidos já emitidos pelo jogo, deduplicada por recurso, mip e geração. Manter o recurso antigo vivo até a última fence consumidora e só publicar a nova vista quando a cópia terminar. Medir acertos, bytes inúteis e tempo até o primeiro desenho válido. [Ensaios com materiais e pausa](pausa-e-materiais.md).

**Console e streaming.** O GDK do Xbox permite enfileirar e priorizar vários pedidos DirectStorage, descomprimir dados e sinalizar a conclusão por fence. O Sampler Feedback Streaming pode indicar regiões e níveis de textura necessários. A estratégia interna adotada por esta cutscene ainda exige evidência do título. No PC, um pedido antecipado só é útil quando reduz uma espera observada do primeiro consumidor. [DirectStorage no Xbox](https://learn.microsoft.com/en-us/gaming/gdk/docs/features/console/storage/directstorage/directstorage-overview) · [Sampler Feedback Streaming](https://news.xbox.com/en-us/2020/03/16/xbox-series-x-glossary/).

**Fila e sincronização.** Em `host.rs`, marcar cada lote com a fence, o fim da preparação, o envio e a publicação. Em `shadow.rs`, correlacionar cada faixa com o próximo consumidor: leitura de CPU do título, escrita de CPU que invalida o espelho, próxima lista GPU ou publicação explícita de readback. Agrupar intervalos sobrepostos dentro da mesma geração. Uma primeira implementação pode deixar a GPU encadear lotes que usam exclusivamente dados residentes. Manter a espera para consumidores de CPU comprovados. Testar leituras imediatamente após sinalização, escritas parciais, alias, reuso do buffer e saída com dispositivo removido. Comparar bytes com o caminho atual e só então comparar o tempo.

**Experimento isolado na GPU.** O shader de referência compara dois snapshots residentes, produzindo um bit por bloco de 1 KiB. O teste D3D12 na RTX 3060 comparou a máscara com uma referência CPU byte a byte em 15 combinações, incluindo nenhum byte alterado, diferenças esparsas, todos os blocos e o último dword parcialmente válido. A máscara para 512 MiB ocuparia 64 KiB. O teste ainda não mede ganho no jogo. A integração requer uma cópia de referência com geração válida, barreira entre produtor e comparação, máscara zerada por geração e invalidação se a CPU escrever no intervalo. Manter o caminho conservador quando houver alias, versão desconhecida ou mapeamento concorrente. Enviar um buffer inteiro pela PCIe só para construir a referência pode consumir o ganho. [Shader HLSL](../ferramentas/blocos-alterados.hlsl) · [Teste D3D12](../patches/teste-blocos-gpu.patch).

## Reproduzir com fontes próprias

Para o A/B, comece pela árvore Materiais `6fc6ceb882461675a417fe9160a194aea8df43ea`. O script público já a prepara. Crie uma pasta de ensaio nova e uma árvore de trabalho separada a partir do repositório que contém a árvore preparada. Aplique primeiro `uploads-texturas-alteradas.patch`, depois `medicao-uploads-ab.patch`. Compile uma vez com o mesmo DXC usado para Materiais. Nas duas execuções use o mesmo alvo, perfil inicial e cópias independentes do mesmo cache. Defina `VICTORY_RESEND_CLEAN=1` no controle e remova a variável na segunda execução. `VICTORY_PERF=1` habilita os contadores. Salve o console e os contadores cumulativos de tempo do processo e de motores Windows (formatos em `medir-uploads.py`). O analisador requer Python 3.11 ou mais recente.

```powershell
python .\ferramentas\medir-uploads.py .\ensaio-controle .\ensaio-alteradas
```

Para reproduzir o compute isolado, use uma cópia de trabalho da árvore SondaMateriais. Em PowerShell, partindo da raiz do repositório público, informe uma árvore de teste gravável à qual os patches da variante já foram aplicados:

```powershell
$sonda = Read-Host 'Diretório da árvore SondaMateriais de teste'
$patch = (Resolve-Path '.\patches\teste-blocos-gpu.patch').Path
git -C $sonda apply --check $patch
git -C $sonda apply $patch
$env:VICTORY_DIRTY_MASK_DXIL = Join-Path $env:TEMP 'victory-blocos-comparados.dxil'
dxc.exe -T cs_6_6 -E main -Fo $env:VICTORY_DIRTY_MASK_DXIL .\ferramentas\blocos-alterados.hlsl
Push-Location (Join-Path $sonda 'crates\victory-shader')
try {
    cargo +1.98.1 test --locked --profile diag --lib dirty_mask_matches_cpu_byte_reference -- --ignored --nocapture
} finally {
    Pop-Location
}
```
