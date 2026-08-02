import subprocess, sys

EXE = r"C:/Users/Administrator/Desktop/Godot_v4.7.1-stable_win64.exe"
CWD = r"G:/游戏设计/宝可梦游戏设计"

p = subprocess.Popen(
    [EXE, "--headless", "res://test/SmokeTest.tscn"],
    cwd=CWD, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
)
try:
    out, _ = p.communicate(timeout=120)
    print(out)
    print("=== EXIT_CODE=%d ===" % p.returncode)
except subprocess.TimeoutExpired:
    p.kill()
    out, _ = p.communicate()
    print(out)
    print("=== TIMED_OUT (killed) ===")
