export PATH="${PATH}:~/local/bin"
export PATH="~/.local/bin/:$PATH"
export PATH="${PATH}:~/Library/Python/3.9/bin"

# Load all functions from ~/.bash_functions
if [ -d "$HOME/.bash_functions" ]; then
    for file in "$HOME/.bash_functions"/*.sh; do
        [ -r "$file" ] && source "$file"
    done
    unset file  # Cleanup variable
fi

#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"

# load ~/.bash_aliases if it exists
if [ -f "$HOME/.bash_aliases" ]; then
    source "$HOME/.bash_aliases"
fi

# Load Angular CLI autocompletion.
#source <(ng completion script)

export PATH="/opt/homebrew/opt/libpq/bin:$PATH"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# Added by Antigravity
export PATH="/Users/luytbq/.antigravity/antigravity/bin:$PATH"

# opencode
export PATH=/Users/luytbq/.opencode/bin:$PATH

# source scripts from ~/.secrets/
if [[ -d "$HOME/.secrets" ]]; then
  for file in "$HOME/.secrets"/*.sh; do
    [[ -r "$file" ]] && source "$file"
  done
  unset file
fi
export PATH="$HOME/.local/bin:$PATH"
