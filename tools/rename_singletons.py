#!/usr/bin/env python3
"""
重命名 6 个 autoload singleton(让 class_name 与单例名解耦, 避免 Godot 4 解析器冲突)。
- GameState -> Game
- DataBus   -> Data
- DayNight  -> Clock
- SaveManager -> Save
- InputSetup  -> Keys
- SoundBus  -> SFX

class_name 行在脚本里另行恢复(本脚本不处理 class_name, 只动单例引用)。
限定项目目录(排除 addons/), 用 \\b 单词边界避免误伤。
"""
import re, pathlib

mappings = [
    (r'\bGameState\b', 'Game'),
    (r'\bDataBus\b', 'Data'),
    (r'\bDayNight\b', 'Clock'),
    (r'\bSaveManager\b', 'Save'),
    (r'\bInputSetup\b', 'Keys'),
    (r'\bSoundBus\b', 'SFX'),
]
allowed = {'autoload', 'battle', 'core', 'data', 'harness', 'test', 'ui', 'world'}

n_files = 0
n_subs = 0
for path in pathlib.Path('.').rglob('*.gd'):
    if not (set(path.parts) & allowed):
        continue
    text = path.read_text(encoding='utf-8')
    new = text
    file_subs = 0
    for pat, repl in mappings:
        new, c = re.subn(pat, repl, new)
        file_subs += c
    if new != text:
        path.write_text(new, encoding='utf-8')
        n_files += 1
        n_subs += file_subs
        print(f'  {path}: {file_subs} 处替换')

print(f'\n总计: 更新 {n_files} 个文件, {n_subs} 处替换')