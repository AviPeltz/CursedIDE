# CursedIDE

> An AI coding-agent IDE — implemented in Verilog.

CursedIDE is a hardware-described code editor for the AI agents era. Inspired
by [Superset](https://github.com/superset-sh/superset) and Conductor — tools
that let you run an army of Claude Code, Codex, and friends on your machine —
CursedIDE asks the question nobody asked:

**What if the IDE itself were a chip?**

In CursedIDE there is no Electron, no Node, no Tauri. There is a clock, a
reset line, and an army of agent FSMs that race each other through a shared
file buffer. Parallel agents are not a feature — they are silicon.

## Status

Pre-alpha. Synthesizes only on imagination. The current tree is a Verilog
skeleton you can simulate with [Icarus Verilog](https://steveicarus.github.io/iverilog/).

## Architecture

```
                  +------------------------+
   prompt --->----| prompt_channel (in)    |
                  +-----------+------------+
                              |
                  +-----------v------------+
                  |     agent_pool (N x)   |
                  |  +------------------+  |
                  |  |  agent_fsm[0]    |  |
                  |  |  agent_fsm[1]    |  |
                  |  |  ...             |  |
                  |  |  agent_fsm[N-1]  |  |
                  |  +--------+---------+  |
                  +-----------+------------+
                              |
                  +-----------v------------+
                  |     file_buffer        |  <-- shared register file
                  +-----------+------------+
                              |
                  +-----------v------------+
   diff <----<----| prompt_channel (out)   |
                  +------------------------+
```

### Modules

- `src/agent_fsm.v` — single coding agent: IDLE → RECEIVING → THINKING →
  EMIT_TOOL → AWAIT_RESULT → EMIT_DIFF → DONE.
- `src/agent_pool.v` — instantiates `N` parallel agents. Hardware parallelism
  is free; rate-limits are not.
- `src/file_buffer.v` — parameterized register-file "file" the agents read
  and write. Arbitration is round-robin (a worktree-per-agent IP block is
  on the roadmap).
- `src/prompt_channel.v` — ready/valid stream for prompts and diffs. In a
  real FPGA build this attaches to a UART or AXI-Stream bridge to the host.
- `src/cursed_ide_top.v` — top-level wiring.

### Testbenches

- `tb/tb_agent_fsm.v` — drives a single agent through one round-trip.
- `tb/tb_cursed_ide_top.v` — full system smoke test.

## Running the simulation

Requires `iverilog` and `vvp`:

```bash
brew install icarus-verilog   # macOS
# or: apt install iverilog    # Debian/Ubuntu

make           # builds and runs all testbenches
make tb_agent  # runs just the agent FSM testbench
make clean
```

## Roadmap

- [x] Single agent FSM
- [x] Parallel agent pool
- [x] Shared file buffer with round-robin arbitration
- [ ] Per-agent worktree IP block
- [ ] LLM oracle interface (off-chip via UART)
- [ ] Synthesizable line-buffer text editor
- [ ] FPGA bringup on a Lattice ECP5 board
- [ ] MCP-over-SPI

## License

MIT. See [LICENSE](LICENSE).
