{ config, lib, pkgs, ... }:

with lib.my;
let cfg = config.modules.editors.vscode;
in
{
  options.modules.editors.vscode = {
    enable = mkBool false;
  };

  config = lib.mkIf (cfg.enable) {
    home-manager.users.${config.user.name} = {
      # External dependencies
      home.packages = with pkgs; [
        # Language servers
        rnix-lsp # nix
      ];

      programs.vscode = {
        enable = true;
        package = pkgs.unstable.vscode;

        userSettings =
          let
            fonts = config.modules.theme.fonts.default.monospace ++ fa;
            fa = [ "Font Awesome 5 Brands" "Font Awesome 5 Free" "Font Awesome 5 Free Solid" ];
          in
          {
            "editor.bracketPairColorization.enabled" = true;
            "editor.guides.bracketPairs" = true;
            "editor.copyWithSyntaxHighlighting" = false;
            "editor.rulers" = [ 80 120 ];
            "editor.smoothScrolling" = true;
            "editor.fontFamily" = lib.concatStringsSep "," (map (x: "'${x}'") fonts);
            "editor.fontLigatures" = true;
            "editor.minimap.enabled" = false;
            "editor.formatOnSave" = true;
            "files.enableTrash" = false;
            "files.insertFinalNewline" = true;
            "files.trimFinalNewlines" = true;
            "files.trimTrailingWhitespace" = true;
            "workbench.list.smoothScrolling" = true;
            "workbench.panel.opensMaximized" = "never";
            "workbench.startupEditor" = "none";
            "workbench.editor.closeOnFileDelete" = true;
            "workbench.editor.labelFormat" = "medium";
            "workbench.settings.openDefaultKeybindings" = true;
            "terminal.integrated.copyOnSelection" = true;
            "terminal.integrated.enableBell" = true;
            "keyboard.dispatch" = "keyCode";
            "telemetry.telemetryLevel" = "off";

            # Extension: Nix IDE
            "nix.enableLanguageServer" = true;
          };

        extensions = with pkgs.vscode-extensions; [
          jnoortheen.nix-ide
        ]
        ++ (pkgs.vscode-utils.extensionsFromVscodeMarketplace [
        ]);
      };
    };
  };
}
