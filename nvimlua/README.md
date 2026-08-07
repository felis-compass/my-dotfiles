# nvimlua

A [kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim)-based Neovim
config. Plain Lua, no Nix required — copy or symlink this folder into place
and it works. [lazy.nvim](https://github.com/folke/lazy.nvim) manages
plugins and bootstraps itself on first launch; [mason.nvim](https://github.com/mason-org/mason.nvim)
installs LSP servers/formatters/linters/debug adapters on demand.

## Requirements

- Neovim >= 0.10
- `git` (plugin installs, lazy.nvim bootstrap)
- A C compiler (`gcc`/`clang`) + `make` (treesitter parsers, telescope-fzf-native, luasnip's jsregexp)
- `ripgrep` and `fd` (telescope)
- `unzip` and/or `curl`/`wget` (mason downloads)
- `node`/`npm` for a handful of mason-installed LSPs (e.g. typescript-language-server, angular-language-server)
- A [Nerd Font](https://www.nerdfonts.com/) (optional — set `vim.g.have_nerd_font = false` in `init.lua` if you don't have one)

Everything else (language servers, formatters, linters, debug adapters) is
installed by Mason the first time you open a relevant filetype — no need to
pre-provision them.

## Install

Copy or symlink this directory to your Neovim config location:

```sh
ln -s /path/to/my-dotfiles/nvimlua ~/.config/nvim
```

On first launch, lazy.nvim clones itself and installs all plugins.

## Multiple flavors (profiles)

This config supports a few "flavors" of Neovim, gated in
[`lua/config/profiles.lua`](lua/config/profiles.lua):

| Profile            | `$NVIM_APPNAME`     | Extra plugins                                        |
|--------------------|----------------------|-------------------------------------------------------|
| general (no AI)    | `nvim`               | —                                                      |
| AI (libre)         | `nvim-ai-libre`      | [codecompanion.nvim](https://github.com/olimorris/codecompanion.nvim) (self-hosted models via Ollama) |
| AI (nonfree)       | `nvim-ai-nonfree`    | [windsurf.nvim](https://github.com/Exafunction/windsurf.nvim) (proprietary Codeium/Windsurf completion) |

Neovim's `$NVIM_APPNAME` (see `:h nvim-appname`) picks a completely separate
config/data/state/cache directory, so each profile gets its own isolated
plugin install and `lazy-lock.json` — they can run side by side without
interfering with each other. To set this up, symlink this same source
directory to each profile's config dir, then select a profile by setting
`$NVIM_APPNAME` when launching:

```sh
ln -s /path/to/my-dotfiles/nvimlua ~/.config/nvim
ln -s /path/to/my-dotfiles/nvimlua ~/.config/nvim-ai-libre
ln -s /path/to/my-dotfiles/nvimlua ~/.config/nvim-ai-nonfree
```

```sh
# in your shell rc
alias nvim-ai-libre='NVIM_APPNAME=nvim-ai-libre nvim'
alias nvim-ai-nonfree='NVIM_APPNAME=nvim-ai-nonfree nvim'
```

`nvim` (no alias/env var) runs the plain general-purpose profile.

### Adding a new flavor

1. Add an entry to the `profiles` table in `lua/config/profiles.lua`.
2. Gate a plugin spec's `enabled` field on `require("config.profiles").enabled("your_feature")`.
3. Symlink a new `$NVIM_APPNAME` config dir to this same source, and add a shell alias for it.

## Using with home-manager (works on NixOS too)

No Nix build magic is needed — this is plain Lua, so home-manager just needs
to symlink it into place and make sure the requirements above are on `$PATH`.
This works identically on NixOS, nix-darwin, or standalone home-manager:

```nix
{ pkgs, ... }:
let
  nvimSrc = /path/to/my-dotfiles/nvimlua; # or pull it in as a flake input
  profiles = [ "nvim" "nvim-ai-libre" "nvim-ai-nonfree" ];
in
{
  home.packages = with pkgs; [
    git
    ripgrep
    fd
    unzip
    gcc
    gnumake
    nodejs
  ];

  home.file = builtins.listToAttrs (map (p: {
    name = ".config/${p}";
    value.source = nvimSrc;
  }) profiles);

  home.shellAliases = {
    nvim-ai-libre = "NVIM_APPNAME=nvim-ai-libre nvim";
    nvim-ai-nonfree = "NVIM_APPNAME=nvim-ai-nonfree nvim";
  };
}
```

Drop profiles you don't want from the `profiles` list (and the matching
`shellAliases` entry) if you only need e.g. the general one. `home.file` here
is equivalent to `xdg.configFile` — either works.

If you already have `nixd` on `$PATH` (e.g. via `home.packages`), the LSP
config in `lua/custom/lsp/init.lua` will pick it up automatically for Nix
files; otherwise it falls back to `nil_ls` installed via Mason.
