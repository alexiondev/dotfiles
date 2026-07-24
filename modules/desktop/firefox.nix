{ config, lib, ... }:
# Firefox as the desktop browser: stock mainline, hardened and de-monetized by policy.
let
  cfg = config.modules.desktop.firefox;
  user = config.user.name;

  # A force-installed extension, keyed at the call site by the add-on's own id.
  # Firefox fetches the signed add-on from Mozilla's site and enables it automatically.
  forceInstalled = slug: {
    install_url = "https://addons.mozilla.org/firefox/downloads/latest/${slug}/latest.xpi";
    installation_mode = "force_installed";
  };
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

          # An ad and content blocker, the operator's password manager, and a
          # video sponsor-skipper. All three are self-contained web extensions.
          ExtensionSettings = {
            "uBlock0@raymondhill.net" = forceInstalled "ublock-origin";
            "78272b6fa58f4a1abaac99321d503a20@proton.me" = forceInstalled "proton-pass";
            "sponsorBlocker@ajay.app" = forceInstalled "sponsorblock";
          };
        };

        profiles.default = {
          isDefault = true;

          settings = {
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

      # Nord chrome from the shared Stylix scheme, against the one profile.
      stylix.targets.firefox = {
        enable = true;
        profileNames = [ "default" ];
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
