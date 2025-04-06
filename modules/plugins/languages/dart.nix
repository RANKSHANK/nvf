{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (builtins) attrNames;
  inherit (lib.meta) getExe;
  inherit (lib.modules) mkIf mkMerge;
  inherit (lib.options) mkEnableOption mkOption;
  inherit (lib.types) enum listOf bool attrsOf anything either nullOr;
  inherit (lib.generators) mkLuaInline;
  inherit (lib.nvim.attrsets) mapListToAttrs;
  inherit (lib.nvim.types) mkGrammarOption luaInline mkPluginSetupOption;
  inherit (lib.nvim.dag) entryAnywhere;
  inherit (lib.nvim.lua) toLuaObject;

  cfg = config.vim.languages.dart;
  ftcfg = cfg.flutter-tools;

  defaultServer = ["dart"];
  servers = {
    dart.options = {
      cmd = [(getExe pkgs.dart) "language-server" "--protocol=lsp"];
      filetypes = ["dart"];
      root_markers = ["pubspec.yaml"];
      init_options = {
        onlyAnalyzeProjectsWithOpenFiles = true;
        suggestFromUnimportedLibraries = true;
        closingLabels = true;
        outline = true;
        flutterOutline = true;
      };
      settings = {
        dart = {
          completeFunctionCalls = true;
          showTodos = true;
        };
      };
    };
  };
in {
  options.vim.languages.dart = {
    enable = mkEnableOption "Dart language support";

    treesitter = {
      enable = mkEnableOption "Dart treesitter" // {default = config.vim.languages.enableTreesitter;};
      package = mkGrammarOption pkgs "dart";
    };

    lsp = {
      enable = mkEnableOption "Dart LSP support";
      server = mkOption {
        description = "The Dart LSP server to use";
        type = listOf (enum (attrNames servers));
        default = defaultServer;
      };
    };

    dap = {
      enable = mkOption {
        description = "Enable Dart DAP support via flutter-tools";
        type = bool;
        default = config.vim.languages.enableDAP;
      };
    };

    flutter-tools = {
      enable = mkOption {
        type = bool;
        default = config.vim.languages.enableLSP;
        description = "Enable flutter-tools for flutter support";
      };

      enableNoResolvePatch = mkOption {
        type = bool;
        default = true;
        description = ''
          Whether to patch flutter-tools so that it doesn't resolve
          symlinks when detecting flutter path.

          This is required if you want to use a flutter package built with nix.
          If you are using a flutter SDK installed from a different source
          and encounter the error "`dart` missing from PATH", disable this option.
        '';
      };

      setupOpts = mkPluginSetupOption "flutter-tools" {
        lsp = {
          # putting this here so that deprecation warnings in deprecations.nix can point to this
          color = mkOption {
            type = attrsOf anything;
            default = {};
            description = "Show derived colors for dart variables";
          };

          capabilities = mkOption {
            type = nullOr (either (attrsOf anything) luaInline);
            default = mkLuaInline "capabilities";
            description = "LSP capabilities";
          };

          on_attach = mkOption {
            type = luaInline;
            default = mkLuaInline "default_on_attach";
            description = "Lua function to run on attach";
          };

          debugger = {
            enabled = mkEnableOption "debugger support" // {default = cfg.dap.enable;};
          };
        };
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
          value = servers.${name}.options;
        })
        cfg.lsp.server;
    })

    (mkIf ftcfg.enable {
      vim.startPlugins =
        if ftcfg.enableNoResolvePatch
        then ["flutter-tools-patched"]
        else ["flutter-tools-nvim"];

      vim.pluginRC.flutter-tools = entryAnywhere ''
        require('flutter-tools').setup(${toLuaObject ftcfg.setupOpts})
      '';
    })
  ]);
}
