"""Relaciona a recusa na variante Materiais com o estágio e os comandos observados."""
import argparse
import csv
import re
import struct
from collections import Counter
from pathlib import Path

STAGES = {0: "Ps", 1: "Vs", 2: "Gs", 3: "Hs", 4: "Ds", 5: "Cs", 13: "Ms", 14: "As"}
HASH = r"[0-9a-f]{16}"


def stage(blob):
    if blob[:4] != b"DXBC" or struct.unpack_from("<I", blob, 24)[0] != len(blob):
        raise ValueError("Contêiner DXBC inválido")
    count = struct.unpack_from("<I", blob, 28)[0]
    chunks = {}
    for offset in struct.unpack_from(f"<{count}I", blob, 32):
        tag, size = struct.unpack_from("<4sI", blob, offset)
        payload = blob[offset + 8:offset + 8 + size]
        if len(payload) != size:
            raise ValueError("Parte truncada")
        chunks[tag] = payload
    psv = chunks[b"PSV0"]
    size = struct.unpack_from("<I", psv)[0]
    if size < 25 or len(psv) < 4 + size:
        raise ValueError("PSV sem ShaderStage")
    kind = psv[4 + 24]
    if b"DXIL" in chunks:
        assert kind == struct.unpack_from("<H", chunks[b"DXIL"], 2)[0]
        return STAGES[kind], "DXIL+PSV0"
    return STAGES[kind], "PSV0"


def scene_commands(log):
    requested, issued = Counter(), Counter()
    with log.open(encoding="utf-8", errors="replace") as lines:
        for line in lines:
            marker = "pass list submitted"
            if marker not in line:
                continue
            for op, ran, names in re.findall(r"(mesh|draw|indexed|compute|indirect-request|indirect-issued) (true|false) \[([^\]]*)\]", line):
                hashes = re.findall(HASH, names)
                if op != "indirect-issued":
                    requested.update(hashes)
                if ran == "true":
                    issued.update(hashes)
    return requested, issued


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pendencias", type=Path)
    parser.add_argument("amostras", type=Path, help="diretório de contêineres locais nomeados por hash")
    parser.add_argument("controle", type=Path, help="console.log da variante original")
    parser.add_argument("rastreio", type=Path, help="console.log com VICTORY_PASS_TRACE")
    parser.add_argument("saida", type=Path)
    args = parser.parse_args()
    binds = set(re.findall(r"first bind [^\n]*?hash=(" + HASH + ")",
                           args.controle.read_text(encoding="utf-8", errors="replace")))
    requested, issued = scene_commands(args.rastreio)
    files = {p.stem: p for p in args.amostras.rglob("*.dxbc")}
    with args.pendencias.open(encoding="utf-8-sig", newline="") as f, args.saida.open("w", encoding="utf-8", newline="") as out:
        writer = csv.writer(out, lineterminator="\n")
        writer.writerow(["hash", "estagio", "prova_estagio", "familia_primaria", "erro_primario", "visto_no_log_base",
                         "vinculado_na_base", "comandos_solicitados_na_sonda", "comandos_emitidos_na_sonda"])
        for row in csv.DictReader(f):
            h = row["hash"]
            kind, evidence = stage(files[h].read_bytes())
            first = row["motivo_materiais"].split(";")[0]
            cause = re.sub(r"^GFX10 code at 0x[0-9a-f]+: | is not supported$", "", first)
            writer.writerow([h, kind, evidence, cause, first, row["recusa_registrada_na_execucao"],
                             int(h in binds), requested[h], issued[h]])


if __name__ == "__main__":
    main()
