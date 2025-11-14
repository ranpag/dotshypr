if status --is-login
    set -gx PATH $PATH $HOME/.local/bin
    set -gx PATH $PATH $HOME/.asdf/shims
    set -gx PATH $PATH $HOME/.scripts/xxx
end

function fish_greeting
end

if status --is-interactive
    sleep 0.1 && starship init fish | source

    if test (tput cols) -gt 100
    and test (tput lines) -gt 30
        fastfetch
    end
end


