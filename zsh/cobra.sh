cobra_dawin_init() {
    # >>> conda initialize >>>
    # !! Contents within this block are managed by 'conda init' !!
    __conda_setup="$('/opt/homebrew/anaconda3/bin/conda' 'shell.zsh' 'hook' 2>/dev/null)"
    if [ $? -eq 0 ]; then
        eval "$__conda_setup"
    else
        if [ -f "/opt/homebrew/anaconda3/etc/profile.d/conda.sh" ]; then
            . "/opt/homebrew/anaconda3/etc/profile.d/conda.sh"
        else
            export PATH="/opt/homebrew/anaconda3/bin:$PATH"
        fi
    fi
    unset __conda_setup
}

cobra_linux_init() {
    # >>> conda initialize >>>
    # !! Contents within this block are managed by 'conda init' !!
    __conda_setup="$('/opt/anaconda/3-2023.03-1-Linux-x86_64/bin/conda' 'shell.bash' 'hook' 2>/dev/null)"
    if [ $? -eq 0 ]; then
        eval "$__conda_setup"
    else
        if [ -f "/opt/anaconda/3-2023.03-1-Linux-x86_64/etc/profile.d/conda.sh" ]; then
            . "/opt/anaconda/3-2023.03-1-Linux-x86_64/etc/profile.d/conda.sh"
        else
            export PATH="/opt/anaconda/3-2023.03-1-Linux-x86_64/bin:$PATH"
        fi
    fi
    unset __conda_setup
    # <<< conda initialize <<<
}

cobra_init() {
    os_type=$(uname)
    [[ "$os_type" == "Darwin" ]] && cobra_dawin_init
    [[ "$os_type" == "Linux" ]] && cobra_linux_init
}

cobra_env() {
    [[ -z $CONDA_PROMPT_MODIFIER ]] && cobra_init
    conda create -p $PWD/.conda_env python=3.12 -y
}

cobra_activate() {
    [[ -z $CONDA_PROMPT_MODIFIER ]] && cobra_init
    conda activate $PWD/.conda_env
    export CONDA_PROMPT_MODIFIER_DEFAULT="${CONDA_PROMPT_MODIFIER:-}"
    export CONDA_PROMPT_MODIFIER="($(basename $PWD))"
}

cobra_deactivate() {
    export CONDA_PROMPT_MODIFIER="${CONDA_PROMPT_MODIFIER_DEFAULT:-}"
    conda deactivate # deactivate env conda
    conda deactivate # deactivate base conda
    unset CONDA_PROMPT_MODIFIER_DEFAULT
    unset CONDA_PROMPT_MODIFIER
}

cobra_create() {
    [[ -z $CONDA_PROMPT_MODIFIER ]] && cobra_init
    conda env create --prefix $PWD/.conda_env --file environment-nolock.yml
}

cobra_update() {
    conda env update --prefix $PWD/.conda_env --file environment-nolock.yml --prune
}
