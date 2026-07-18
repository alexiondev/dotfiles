set -gx EDITOR nvim
set -x ANDROID_HOME $HOME/Android/Sdk
fish_add_path $ANDROID_HOME/platform-tools
fish_add_path $ANDROID_HOME/tools/bin
