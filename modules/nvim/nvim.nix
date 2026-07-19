{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
# Neovim for the primary user, configured declaratively through nixvim. Options,
# keymaps, and plugin settings are typed Nix; the imperative remainder (the
# colorscheme call and the Neogit blame-toggle autocmd) lives in ./config.lua.
# Plugins come from nixpkgs — no plugin manager and no runtime cloning — and
# treesitter grammars are built by Nix, so no compiler is needed at runtime. git
# backs the git plugins; ripgrep and fd back the picker.
let
  cfg = config.modules.nvim;
  user = config.user.name;
in
{
  options.modules.nvim.enable = lib.mkEnableOption "Neovim, configured declaratively via nixvim";

  config = lib.mkIf cfg.enable {
    home-manager.sharedModules = [ inputs.nixvim.homeModules.nixvim ];

    home-manager.users.${user} = hm: {
      programs.nixvim = {
        enable = true;

        extraPackages = with pkgs; [
          git # neogit and gitsigns shell out to git
          ripgrep # backs the picker's live grep
          fd # backs the picker's file finder
        ];

        globals.mapleader = " ";
        globals.clipboard = "osc52"; # neovim's built-in OSC 52 provider, no external binary needed

        opts = {
          clipboard = "unnamedplus";

          number = true;
          relativenumber = true;

          shiftwidth = 2;
          tabstop = 2;
          expandtab = true;

          mouse = "a";

          undofile = true;

          ignorecase = true;
          smartcase = true;

          splitright = true;
          splitbelow = true;

          wrap = false;

          scrolloff = 8;
          cursorline = true;
        };

        keymaps = [
          {
            mode = "n";
            key = "<C-h>";
            action = "<C-w>h";
            options.desc = "Move focus left";
          }
          {
            mode = "n";
            key = "<C-j>";
            action = "<C-w>j";
            options.desc = "Move focus down";
          }
          {
            mode = "n";
            key = "<C-k>";
            action = "<C-w>k";
            options.desc = "Move focus up";
          }
          {
            mode = "n";
            key = "<C-l>";
            action = "<C-w>l";
            options.desc = "Move focus right";
          }
          {
            mode = "n";
            key = "<Esc>";
            action = "<cmd>nohlsearch<CR>";
            options.desc = "Clear search highlight";
          }
          {
            mode = "n";
            key = "<leader>e";
            action = "<cmd>Oil<CR>";
            options.desc = "Open file browser";
          }
          {
            mode = "n";
            key = "<leader>f";
            action.__raw = "function() require('snacks').picker.files() end";
            options.desc = "Find files";
          }
          {
            mode = "n";
            key = "<leader>s";
            action.__raw = "function() require('snacks').picker.grep() end";
            options.desc = "Search text";
          }
          {
            mode = "n";
            key = "<leader>b";
            action.__raw = "function() require('snacks').picker.buffers() end";
            options.desc = "Switch buffer";
          }
          {
            mode = "n";
            key = "<leader>g";
            action.__raw = ''
              function()
                require('gitsigns').toggle_current_line_blame(true)
                require('neogit').open()
              end
            '';
            options.desc = "Open git (Neogit)";
          }
        ];

        plugins = {
          gitsigns = {
            enable = true;
            settings.current_line_blame = false;
          };

          neogit.enable = true;
          diffview.enable = true; # neogit's diff integration

          oil = {
            enable = true;
            settings.view_options.show_hidden = true;
          };

          snacks = {
            enable = true;
            settings = {
              picker.enabled = true;
              notifier.enabled = true;
              input.enabled = true;
            };
          };

          which-key.enable = true;
          render-markdown.enable = true;

          treesitter = {
            enable = true;
            highlight.enable = true;
            indent.enable = true;
            grammarPackages = with hm.config.programs.nixvim.plugins.treesitter.package.builtGrammars; [
              nix
              lua
              bash
              fish
              markdown
              markdown_inline
              rust
              python
              java
              kotlin
              c
              cpp
              html
              css
              javascript
              typescript
              go
            ];
          };
        };

        # gbprod/nord.nvim; nixvim's colorschemes.nord is a different plugin. Set
        # up in ./config.lua.
        extraPlugins = [ pkgs.vimPlugins.gbprod-nord ];

        extraConfigLua = builtins.readFile ./config.lua;
      };
    };
  };
}
