from pathlib import Path
import argparse, subprocess

repo = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--runtime', default='luau')
parser.add_argument('--revision')
parser.add_argument('--source-root', type=Path)
parser.add_argument('--case', choices=('input', 'filter'), default='input')
args = parser.parse_args()
work = repo / 'work'
work.mkdir(exist_ok=True)
paths = {
    'commands': 'src/ui/components/commands.luau',
    'interface': 'src/ui/init.luau',
    'keyboard': 'src/framework/services/keyboardService.luau',
    'keys': 'src/framework/config/services/keybinds.luau',
    'colors': 'src/framework/config/ui/colors.luau',
    'nameColor': 'src/utils/nameColor.luau',
    'drag': 'src/ui/services/dragService.luau',
    **{name: f'src/ui/themes/{name}.luau' for name in ('dark', 'light', 'classic')},
}

def literal(text):
    equals = '='
    while ']' + equals + ']' in text:
        equals += '='
    return '[' + equals + '[' + ('\n' if text.startswith('\n') else '') + text + ']' + equals + ']'

parts = ['local sources = { ["case"] = ' + literal(args.case) + ',\n']
for key, path in paths.items():
    if args.revision:
        text = subprocess.check_output(['git', '-C', str(repo), 'show', f'{args.revision}:{path}']).decode('utf-8')
    else:
        text = ((args.source_root or repo) / path).read_text(encoding='utf-8')
    parts.append('[ ' + literal(key) + ' ] = ' + literal(text) + ',\n')
parts.append('}\nlocal fixture = ' + literal((repo/'tools/input_fixture.luau').read_text(encoding='utf-8')) + '\nreturn assert(loadstring(fixture, "XLQP/input-regression"))(sources)\n')
target = work/'input-regression.luau'
target.write_text(''.join(parts), encoding='utf-8', newline='\n')
result = subprocess.run([args.runtime, str(target)], capture_output=True, text=True, encoding='utf-8')
print(result.stdout, end='')
if result.stderr:
    print(result.stderr, end='')
raise SystemExit(result.returncode)
