{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.options) mkEnableOption mkOption;
  inherit (lib.meta) getExe;
  inherit (lib.modules) mkIf mkMerge;
  inherit (lib.types) package;
  inherit (lib.nvim.types) mkGrammarOption;

  cfg = config.vim.languages.assembly;
in {
  options.vim.languages.assembly = {
    enable = mkEnableOption "Assembly support";

    treesitter = {
      enable = mkEnableOption "Assembly treesitter" // {default = config.vim.languages.enableTreesitter;};
      package = mkGrammarOption pkgs "asm";
    };

    lsp = {
      enable = mkEnableOption "Assembly LSP support (asm-lsp)" // {default = config.vim.languages.enableLSP;};

      package = mkOption {
        type = package;
        default = pkgs.asm-lsp;
        description = "asm-lsp package";
      };
    };
  };
  config = mkIf cfg.enable (mkMerge [
    (mkIf cfg.treesitter.enable {
      vim.treesitter.enable = true;
      vim.treesitter.grammars = [cfg.treesitter.package];
    })

    (mkIf cfg.lsp.enable {
      vim.lsp.servers.asm_lsp = {
        cmd = [(getExe pkgs.asm-lsp)];
        filetypes = ["asm" "vmasm"];
        root_markers = [".asm-lsp.toml" ".git"];
      };
    })
  ]);
}
