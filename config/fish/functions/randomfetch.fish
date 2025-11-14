function randomfetch
    set -l target_dir ~/.config/fastfetch/assets
    set -l random_file (find $target_dir -maxdepth 2 -type f | shuf -n 1)

    if test -z $random_file
        return 0
    end

    set -l file_basename (basename $random_file)
    set -l file_name_only (string replace -r '\.[^/.]+$' '' $file_basename)

    if test -f ~/.config/fastfetch/conf.d/$file_name_only.jsonc
        fastfetch --config ~/.config/fastfetch/conf.d/$file_name_only.jsonc
    else
        fastfetch --logo $random_file --structure none
    end
end
