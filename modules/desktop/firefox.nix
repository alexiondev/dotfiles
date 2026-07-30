{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
# Firefox as the desktop browser: stock mainline, hardened and de-monetized by policy.
let
  cfg = config.modules.desktop.firefox;
  user = config.user.name;
  firefoxAddons = inputs.firefox-addons.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  options.modules.desktop.firefox.enable = lib.mkEnableOption "Firefox as the desktop browser";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user} = hm: {
      programs.firefox = {
        enable = true;

        # Enterprise policies: enforced and unchangeable from the browser UI.
        policies = {
          DisableTelemetry = true;
          DisableFirefoxStudies = true;
          DisablePocket = true;
          OfferToSaveLogins = false;
          DontCheckDefaultBrowser = true;
          DisableFirefoxAccounts = true;

          # Strip the monetized surfaces from the new-tab page.
          FirefoxHome = {
            SponsoredTopSites = false;
            SponsoredPocket = false;
            Snippets = false;
          };
        };

        profiles.default = {
          isDefault = true;

          extensions = {
            packages = with firefoxAddons; [
              ublock-origin
              proton-pass
              sponsorblock
            ];

            # The Nord chrome theme is a declared extension setting, so home-manager
            # owns the extension-settings store, overwriting runtime changes to it.
            force = true;
          };

          # Stylix's Nord mapping paints the selected address-bar result a
          # near-white grey, leaving its light text unreadable. Darken that one
          # highlight to the Nord selection grey, from the same scheme.
          extensions.settings."FirefoxColor@mozilla.com".settings.theme.colors.popup_highlight =
            let
              c = hm.config.lib.stylix.colors;
            in
            lib.mkForce {
              r = c."base03-rgb-r";
              g = c."base03-rgb-g";
              b = c."base03-rgb-b";
            };

          settings = {
            # Scale the UI and page by a fixed factor.
            # Left at auto (-1), Firefox reads the panel's 1.5x and inflates its
            # whole chrome while point-sized apps stay put.
            # A shade under that brings it into line without dropping to true
            # 1:1, which reads too small at this DPI.
            "layout.css.devPixelsPerPx" = "1.25";

            # Auto-enable the sideloaded Firefox Color add-on carrying the Nord
            # chrome theme, which Firefox otherwise leaves disabled.
            "extensions.autoDisableScopes" = 0;

            # Sponsored surfaces the policies above do not reach.
            "browser.urlbar.suggest.quicksuggest.sponsored" = false;
            "browser.newtabpage.activity-stream.showSponsored" = false;
            "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
          };

          search = {
            # Declaring search overwrites Firefox's own engine list wholesale,
            # so engines added later in the UI do not survive a rebuild.
            force = true;
            default = "ddg";

            # The general-purpose commercial engines, hidden to leave a lean
            # DuckDuckGo-and-Wikipedia list. They stay reachable through bangs.
            # An engine carrying only metaData is treated as a builtin.
            engines = {
              google.metaData.hidden = true;
              bing.metaData.hidden = true;
              ebay.metaData.hidden = true;
              "amazondotcom-us".metaData.hidden = true;
            };
            order = [ "ddg" ];
          };
        };
      };

      # Nord chrome for the one profile, applied through the Stylix-managed
      # Firefox Color add-on that colorTheme enables.
      stylix.targets.firefox = {
        enable = true;
        profileNames = [ "default" ];
        colorTheme.enable = true;
      };

      # Links opened from other applications land in Firefox.
      xdg.mimeApps = {
        enable = true;
        defaultApplications = {
          "text/html" = "firefox.desktop";
          "application/xhtml+xml" = "firefox.desktop";
          "x-scheme-handler/http" = "firefox.desktop";
          "x-scheme-handler/https" = "firefox.desktop";
        };
      };

      # Firefox writes profiles.ini itself on first launch, so home-manager is
      # told to own the file rather than fail activation refusing to clobber it.
      home.file."${hm.config.programs.firefox.configPath}/profiles.ini".force = true;
    };
  };
}
