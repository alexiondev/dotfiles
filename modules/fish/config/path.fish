# Prepend ~/.local/bin to PATH when it exists.
if test -d ~/.local/bin
    fish_add_path ~/.local/bin
end

# Apply fish-compatible profile overrides if present.
if test -f ~/.fish_profile
    source ~/.fish_profile
end
