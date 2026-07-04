setopt prompt_subst

_git_prompt_info() {
  command git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return

  local branch
  branch=$(
    command git symbolic-ref --quiet --short HEAD 2>/dev/null ||
    command git rev-parse --short HEAD 2>/dev/null
  ) || return

  # Avoid branch names with % being interpreted as zsh prompt escapes.
  branch=${branch//\%/%%}

  if [[ -n "$(command git status --porcelain --ignore-submodules=dirty 2>/dev/null)" ]]; then
    print -r -- "%B%F{blue}git:(%F{red}${branch}%F{blue}) %F{yellow}✘%f%b "
    # print -r -- "%B%F{blue}git:(%F{red}${branch}%F{blue}) %F{yellow}✗%f%b "
  else
    print -r -- "%B%F{blue}git:(%F{red}${branch}%F{blue})%f%b "
  fi
}

PROMPT='%(?:%B%F{green}➜%f%b :%B%F{red}➜%f%b ) %B%F{cyan}%c%f%b $(_git_prompt_info)'

