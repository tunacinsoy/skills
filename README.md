# skills

Tuna Cinsoy's personal [Claude Code](https://claude.com/claude-code) skills, as an
installable plugin.

## What's inside

| Skill | Description |
|---|---|
| [`teach-from-scratch`](skills/teach-from-scratch) | Turns a finished project into a hands-on curriculum — lessons plus a practice workspace with behavioral checks — for rebuilding it yourself, without AI in the practice loop. |

Each skill lives in its own directory under `skills/`, with its own `SKILL.md` and README.

## Installation

### As a Claude Code plugin

Add this repo as a marketplace, then install the plugin:

```
/plugin marketplace add tunacinsoy/skills
/plugin install tunacinsoy-skills
```

Updates arrive by pulling the marketplace again.

### Manually (editable, per skill)

Clone the repo and symlink whichever skill you want directly into Claude Code's skills
directory:

```bash
git clone https://github.com/tunacinsoy/skills.git ~/skills
ln -s ~/skills/skills/teach-from-scratch ~/.claude/skills/teach-from-scratch
```

This is the better option if you want to read or hack on a skill's instructions directly —
Claude Code loads personal skills from `~/.claude/skills/` automatically.

## Repository layout

```
.claude-plugin/
  marketplace.json   # lets this repo be added as a plugin marketplace
  plugin.json         # the plugin manifest — lists every skill below
skills/
  teach-from-scratch/ # one directory per skill
    SKILL.md
    README.md
    reference/
    tests/
```

## License

MIT — see [LICENSE](LICENSE).
