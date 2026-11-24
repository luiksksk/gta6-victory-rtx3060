"""Mede os dez segundos a partir da primeira apresentação bem-sucedida da cena."""
import argparse
import csv
import json
import re
from bisect import bisect_right
from collections import defaultdict
from datetime import datetime
from pathlib import Path

COUNTERS = ("bytes_verificados", "bytes_iguais", "bytes_readback_comparados",
            "bytes_readback_diferentes", "bytes_sem_baseline", "bytes_escritos",
            "espera_fence_us", "tabelas_novas", "preparo_planos_us",
            "preparo_descritores_us", "copias_textura", "descartes")


def at(samples, t):
    i = bisect_right([x for x, _ in samples], t)
    if i and samples[i - 1][0] == t:
        return samples[i - 1][1]
    if i == 0 or i == len(samples):
        raise ValueError("amostragem insuficiente para a janela")
    a, x = samples[i - 1]
    b, y = samples[i]
    return x + (y - x) * ((t - a) / (b - a))


def measure(folder):
    presents = []
    with (folder / "console.log").open(encoding="utf8", errors="replace") as log:
        for line in log:
            if "upload comparison present" in line:
                match = re.search(r"frame=(\d+) counts=\[([\d, ]+)\]", line)
                presents.append((datetime.fromisoformat(line.split()[0]).timestamp(),
                                 int(match[1]), list(map(int, match[2].split(", ")))))
    start = presents[0][0]
    end = start + 10
    window = [p for p in presents if start <= p[0] <= end]
    last = window[-1]
    if len(window) < 2 or presents[-1][0] < end:
        raise ValueError("A execução não cobriu dez segundos de apresentações")
    delta = [y - x for x, y in zip(window[0][2], last[2], strict=True)]
    with (folder / "cpu-processo.csv").open(encoding="utf-8-sig") as f:
        cpu = [(float(r["epoch"]), (float(r["user_s"]) + float(r["kernel_s"])) /
                int(r["logical_cpus"])) for r in csv.DictReader(f)]
    engines = defaultdict(list)
    with (folder / "motores-gpu.csv").open(encoding="utf-8-sig") as f:
        for row in csv.DictReader(f):
            engines[row["motor"]].append((float(row["epoch"]), int(row["tempo_100ns"]) * 1e-7))
    def busy(group):
        return 10 * sum(at(v, end) - at(v, start) for k, v in engines.items()
                        if k.endswith("engtype_" + group))
    intervals = len(window) - 1
    return {"primeiro_frame": window[0][1], "ultimo_frame_na_janela": last[1],
            "intervalos_entre_apresentacoes": intervals, "segundos_dos_contadores": last[0] - start,
            "ms_entre_apresentacoes": (last[0] - start) * 1000 / intervals,
            "cpu_total_pct": (at(cpu, end) - at(cpu, start)) * 10,
            "motor_3d_pct": busy("3D"), "motor_copia_pct": busy("Copy"),
            "contadores": dict(zip(COUNTERS, delta, strict=True))}


if __name__ == "__main__":
    cli = argparse.ArgumentParser(description=__doc__)
    cli.add_argument("pastas", nargs="+", type=Path)
    for folder in cli.parse_args().pastas:
        print(json.dumps({folder.name: measure(folder)}, ensure_ascii=False, indent=2))
