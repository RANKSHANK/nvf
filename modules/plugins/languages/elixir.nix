{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (builtins) attrNames;
  inherit (lib.options) mkEnableOption mkOption;
  inherit (lib.meta) getExe;
  inherit (lib.modules) mkIf mkMerge;
  inherit (lib.types) enum listOf package;
  inherit (lib.generators) mkLuaInline;
  inherit (lib.nvim.types) mkGrammarOption mkPluginSetupOption;
  inherit (lib.nvim.attrsets) mapListToAttrs;
  inherit (lib.nvim.dag) entryAnywhere;
  inherit (lib.nvim.lua) toLuaObject;

  cfg = config.vim.languages.elixir;

  defaultServer = ["elixirls"];
  servers = {
    elixirls.options = {
      cmd = [(getExe pkgs.elixir-ls)];
      filetypes = ["elixir" "eelixir" "heex" "surface"];
      root_dir = mkLuaInline ''
        function(bufnr)
          local matches = vim.fs.find({ 'mix.exs' }, { upward = true, limit = 2, path = vim.fn.bufname(bufnr) })
          local child_or_root_path, maybe_umbrella_path = unpack(matches)
          local root_dir = vim.fs.dirname(maybe_umbrella_path or child_or_root_path)

          return root_dir
        end
      '';
    };
  };

  defaultFormat = "mix";
  formats = {
    mix = {
      package = pkgs.elixir;
      config = {
        command = "${cfg.format.package}/bin/mix";
      };
    };
  };
in {
  options.vim.languages.elixir = {
    enable = mkEnableOption "Elixir language support";

    treesitter = {
      enable = mkEnableOption "Elixir treesitter" // {default = config.vim.languages.enableTreesitter;};
      package = mkGrammarOption pkgs "elixir";
    };

    lsp = {
      enable = mkEnableOption "Elixir LSP support" // {default = config.vim.languages.enableLSP;};

      server = mkOption {
        description = "Elixir LSP server to use";
        type = listOf (enum (attrNames servers));
        default = defaultServer;
      };
    };

    format = {
      enable = mkEnableOption "Elixir formatting" // {default = config.vim.languages.enableFormat;};

      type = mkOption {
        description = "Elixir formatter to use";
        type = enum (attrNames formats);
        default = defaultFormat;
      };

      package = mkOption {
        description = "Elixir formatter package";
        type = package;
        default = formats.${cfg.format.type}.package;
      };
    };

    elixir-tools = {
      enable = mkEnableOption "Elixir tools";

      setupOpts = mkPluginSetupOption "Elixir tools" {
        # disable imperative installations of various elixir related tools installed by elixir-tools
        nextls.enable = mkEnableOption "nextls";
        credo.enable = mkEnableOption "credo";
        elixirls.enable = mkEnableOption "elixirls";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    (mkIf cfg.treesitter.enable {
      vim.treesitter.enable = true;
      vim.treesitter.grammars = [cfg.treesitter.package];
    })

    (mkIf cfg.lsp.enable {
      vim.lsp.servers =
        mapListToAttrs (name: {
          inherit name;
          value = servers.${name}.config;
        })
        cfg.lsp.server;
    })

    (mkIf cfg.format.enable {
      vim.formatter.conform-nvim = {
        enable = true;
        setupOpts.formatters_by_ft.elixir = [cfg.format.type];
        setupOpts.formatters.${cfg.format.type} =
          formats.${cfg.format.type}.options;
      };
    })

    (mkIf cfg.elixir-tools.enable {
      vim.startPlugins = ["elixir-tools-nvim"];
      vim.pluginRC.elixir-tools = entryAnywhere ''
        local elixir = require("elixir")
        local elixirls = require("elixir.elixirls")

        -- disable imperative insstallations of various
        -- elixir related tools installed by elixir-tools
        elixir.setup(${toLuaObject cfg.elixir-tools.setupOpts})
      '';
    })
  ]);
}
