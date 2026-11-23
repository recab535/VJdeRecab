import json
import subprocess
import time
from pathlib import Path

ESTADO_PATH = Path("ESTADO_AGENTES.json")
MAX_DURACION_SEGUNDOS = 20 * 60  # 20 minutos

PROMPTS_AGENTES = {
    "G1": "Actúa como el agente G1 (Diseño / Balance / Campaña). Revisa el estado actual del juego, actualiza y detalla la documentación de diseño en docs/ (por ejemplo, expandiendo o refinando reglas de capítulos de campaña o balance) y prepara el siguiente paso de diseño.",
    "G2": "Actúa como el agente G2 (Arquitectura de Datos / Reglas). Revisa los archivos de datos en docs/db_y_catalogo.sql y data/especies_68.json, verifica su consistencia o añade especificaciones de datos necesarias.",
    "A1": "Actúa como el agente A1 (Mundo 3D / Cámara / UI / Persistencia en Godot 4). Revisa o implementa scripts/escenas de infraestructura, UI, cámara o persistencia según las directrices del proyecto.",
    "A2": "Actúa como el agente A2 (Cruces / Campaña / Combate 3v3 en Godot 4). Revisa o implementa sistemas de cruce, lógica de combate 3v3 o entidades visuales de dragones 2D."
}

def leer_estado():
    if not ESTADO_PATH.exists():
        return {
            "estado": "ACTIVO",
            "turno_actual": "G1",
            "rondas_completadas": 0,
            "max_rondas_limite": 4,
            "orden_agentes": ["G1", "G2", "A1", "A2"]
        }
    with open(ESTADO_PATH, "r", encoding="utf-8") as f:
        return json.load(f)

def guardar_estado(estado):
    with open(ESTADO_PATH, "w", encoding="utf-8") as f:
        json.dump(estado, f, indent=2, ensure_ascii=False)

def git_commit(mensaje):
    try:
        subprocess.run(["git", "add", "-A"], check=True, capture_output=True)
        res = subprocess.run(["git", "diff", "--cached", "--quiet"], capture_output=True)
        if res.returncode != 0:
            subprocess.run(["git", "commit", "-m", mensaje], check=True, capture_output=True)
            print(f"[Orquestador] Git commit realizado: {mensaje}")
        else:
            print("[Orquestador] No hay cambios nuevos para commitear.")
    except Exception as e:
        print(f"[Orquestador] Error al hacer git commit: {e}")

def main():
    inicio_tiempo = time.time()
    print("[Orquestador] Iniciando orquestación de agentes...")

    while True:
        tiempo_transcurrido = time.time() - inicio_tiempo
        if tiempo_transcurrido >= MAX_DURACION_SEGUNDOS:
            print("[Orquestador] Límite de tiempo alcanzado (20 minutos). Deteniendo orquestación.")
            break

        estado = leer_estado()
        
        if estado.get("estado") != "ACTIVO":
            print(f"[Orquestador] El estado no es ACTIVO (actual: {estado.get('estado')}). Deteniendo.")
            break

        rondas = estado.get("rondas_completadas", 0)
        max_rondas = estado.get("max_rondas_limite", 4)

        if rondas >= max_rondas:
            print(f"[Orquestador] Se alcanzó el límite de rondas ({rondas}/{max_rondas}). Deteniendo.")
            estado["estado"] = "FINALIZADO"
            guardar_estado(estado)
            break

        turno = estado.get("turno_actual", "G1")
        orden = estado.get("orden_agentes", ["G1", "G2", "A1", "A2"])

        prompt = PROMPTS_AGENTES.get(turno, f"Ejecutar turno para el agente {turno}.")
        print(f"\n--- [Ronda {rondas + 1}] Turno del agente: {turno} ---")
        print(f"[Orquestador] Ejecutando comando gemini...")

        cmd = ["gemini", "-m", "gemini-3.5-flash-lite", "-y", "-p", prompt]
        try:
            resultado = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8")
            if resultado.returncode == 0:
                print(f"[Orquestador] Agente {turno} ejecutado con éxito.")
            else:
                print(f"[Orquestador] Advertencia en ejecución de {turno} (código {resultado.returncode}): {resultado.stderr}")
        except Exception as e:
            print(f"[Orquestador] Error ejecutando CLI de gemini: {e}")

        git_commit(f"Orquestador: Turno completado por agente {turno} (Ronda {rondas + 1})")

        try:
            idx = orden.index(turno)
        except ValueError:
            idx = 0

        siguiente_idx = (idx + 1) % len(orden)
        siguiente_turno = orden[siguiente_idx]

        if siguiente_idx == 0:
            estado["rondas_completadas"] = rondas + 1

        estado["turno_actual"] = siguiente_turno
        guardar_estado(estado)

        print(f"[Orquestador] Siguiente turno asignado a: {siguiente_turno}. Rondas completadas: {estado['rondas_completadas']}/{max_rondas}")

    print("[Orquestador] Orquestación finalizada.")

if __name__ == "__main__":
    main()
