setopt prompt_subst

typeset -g _rr_git_prompt_info=''
typeset -g _rr_git_prompt_pwd=''
typeset -g _rr_git_prompt_git_dir=''
typeset -g _rr_git_prompt_head=''
typeset -g _rr_git_prompt_branch=''
typeset -gi _rr_git_prompt_dirty=0
typeset -gi _rr_git_prompt_command_ran=1
typeset -gi _rr_git_prompt_git_command_ran=0
typeset -gi _rr_git_prompt_last_dirty_check=-9999
typeset -gi _rr_git_prompt_dirty_ttl=5

_rr_git_prompt_reset() {
  _rr_git_prompt_info=''
  _rr_git_prompt_git_dir=''
  _rr_git_prompt_head=''
  _rr_git_prompt_branch=''
  _rr_git_prompt_dirty=0
  _rr_git_prompt_last_dirty_check=-9999
}

_rr_git_prompt_clear_flags() {
  _rr_git_prompt_command_ran=0
  _rr_git_prompt_git_command_ran=0
}

_rr_git_prompt_refresh_repo() {
  _rr_git_prompt_pwd=$PWD
  _rr_git_prompt_reset

  local git_info
  git_info=$(command git rev-parse --is-inside-work-tree --path-format=absolute --git-dir 2>/dev/null) ||
    git_info=$(command git rev-parse --is-inside-work-tree --git-dir 2>/dev/null) ||
    return

  local -a git_lines
  git_lines=("${(@f)git_info}")
  [[ ${git_lines[1]} == true && -n ${git_lines[2]} ]] || return

  _rr_git_prompt_git_dir=${git_lines[2]}
  [[ $_rr_git_prompt_git_dir == /* ]] || _rr_git_prompt_git_dir=$PWD/$_rr_git_prompt_git_dir
  _rr_git_prompt_git_dir=${_rr_git_prompt_git_dir:A}
}

_rr_git_prompt_refresh_branch() {
  [[ -n $_rr_git_prompt_git_dir && -r "$_rr_git_prompt_git_dir/HEAD" ]] || return 1

  local head
  IFS= read -r head < "$_rr_git_prompt_git_dir/HEAD" || return 1
  [[ $head == $_rr_git_prompt_head ]] && return

  _rr_git_prompt_head=$head
  if [[ $head == ref:\ * ]]; then
    _rr_git_prompt_branch=${head#ref: }
    _rr_git_prompt_branch=${_rr_git_prompt_branch#refs/heads/}
  else
    local tag
    if tag=$(command git describe --tags --exact-match HEAD 2>/dev/null); then
      _rr_git_prompt_branch=$tag
    else
      _rr_git_prompt_branch=${head[1,7]}
    fi
  fi

  # Avoid branch names with % being interpreted as zsh prompt escapes.
  _rr_git_prompt_branch=${_rr_git_prompt_branch//\%/%%}
}

_rr_git_prompt_refresh_dirty() {
  local status_line
  _rr_git_prompt_dirty=0
  IFS= read -r status_line < <(command git -c core.optionalLocks=false status --porcelain --ignore-submodules=dirty 2>/dev/null) || true
  [[ -n $status_line ]] &&
    _rr_git_prompt_dirty=1
  _rr_git_prompt_last_dirty_check=$SECONDS
}

_rr_git_prompt_preexec() {
  _rr_git_prompt_command_ran=1
  [[ $1 == git || $1 == git\ * || $1 == command\ git\ * ]] && _rr_git_prompt_git_command_ran=1
  return 0
}

_rr_git_prompt_precmd() {
  local repo_changed=0
  local dirty_check_due=0
  [[ $_rr_git_prompt_pwd != $PWD ]] && repo_changed=1

  if (( repo_changed )) || { (( _rr_git_prompt_git_command_ran )) && [[ -z $_rr_git_prompt_git_dir ]]; }; then
    _rr_git_prompt_refresh_repo || {
      _rr_git_prompt_reset
      _rr_git_prompt_clear_flags
      return 0
    }
  fi

  [[ -n $_rr_git_prompt_git_dir ]] || {
    _rr_git_prompt_clear_flags
    return 0
  }

  _rr_git_prompt_refresh_branch || {
    _rr_git_prompt_reset
    _rr_git_prompt_clear_flags
    return 0
  }

  (( SECONDS - _rr_git_prompt_last_dirty_check >= _rr_git_prompt_dirty_ttl )) && dirty_check_due=1
  if (( repo_changed || _rr_git_prompt_command_ran || dirty_check_due )); then
    _rr_git_prompt_refresh_dirty
  fi

  if [[ -n $_rr_git_prompt_branch ]]; then
    if (( _rr_git_prompt_dirty )); then
      _rr_git_prompt_info="%B%F{blue}git:(%F{red}${_rr_git_prompt_branch}%F{blue}) %F{yellow}✘%f%b "
      # _rr_git_prompt_info="%B%F{blue}git:(%F{red}${_rr_git_prompt_branch}%F{blue}) %F{yellow}✗%f%b "
    else
      _rr_git_prompt_info="%B%F{blue}git:(%F{red}${_rr_git_prompt_branch}%F{blue})%f%b "
    fi
  fi

  _rr_git_prompt_clear_flags
  return 0
}

autoload -Uz add-zsh-hook
add-zsh-hook -d preexec _rr_git_prompt_preexec 2>/dev/null || true
add-zsh-hook -d precmd _rr_git_prompt_precmd 2>/dev/null || true
add-zsh-hook preexec _rr_git_prompt_preexec
add-zsh-hook precmd _rr_git_prompt_precmd

PROMPT='%(?:%B%F{green}➜%f%b :%B%F{red}➜%f%b ) %B%F{cyan}%c%f%b ${_rr_git_prompt_info}'
