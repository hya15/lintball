# shellcheck disable=SC2086,SC2230,SC2048

# shellcheck source=SCRIPTDIR/version_compare/version_compare
source "${LINTBALL_DIR}/lib/version_compare/version_compare"

install_bundler_requirements() {
  (
    cd "${LINTBALL_DIR}/tools"
    if [ -z "$(which bundle)" ] && [ -n "$(which gem)" ]; then
      gem install bundler || sudo gem install bundler
    fi
    if [ -n "$(which bundle)" ]; then
      (
        bundle config set --local deployment 'true' || sudo bundle config set --local deployment 'true'
        bundle install || sudo bundle install
      )
    else
      echo "Error: cannot install bundler requirements - could not find a bundle executable." >&2
      echo "If ruby is installed, try gem install bundler and re-run this script." >&2
      return 1
    fi
  )
}

install_clippy() {
  if [ -n "$(which cargo)" ]; then
    if [ -z "$(which rustup)" ]; then
      # Install rustup
      curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
    else
      rustup self update
      rustup update
    fi
    # nightly is needed for clippy to fix issues
    rustup toolchain install nightly
    rustup component add clippy --toolchain nightly
  else
    echo "Error: cannot install clippy - could not find a cargo executable." >&2
    return 1
  fi
}

install_pip_requirements() {
  (
    cd "${LINTBALL_DIR}/tools"
    local pyexe
    pyexe=""
    if [ ! -d "python-env" ]; then
      if [ -n "$(which python3)" ]; then
        pyexe="python3"
      elif [ -n "$(which python)" ]; then
        if python -c "import sys; sys.exit(0 if sys.version_info >= (3,3,0) else 1)"; then
          pyexe="python"
        fi
      fi
      if [ -n "$pyexe" ]; then
        "$pyexe" -m venv "python-env" || sudo "$pyexe" -m venv "python-env"
      else
        echo "Error: cannot install pip requirements." >&2
        echo "could not find a suitable Python version (>=3.3.0)." >&2
        return 1
      fi
    fi
    local activateexe
    activateexe=""
    if [ -f "python-env/bin/activate" ]; then
      activateexe="python-env/bin/activate"
    elif [ -f "python-env/Scripts/activate" ]; then
      activateexe="python-env/Scripts/activate"
    else
      echo "Could not find venv activate script" >&2
      return 1
    fi
    set +eu # workaround for https://github.com/pypa/virtualenv/issues/1029
    source "$activateexe"
    set -eu
    local pipexe
    pipexe="pip"
    if [ -f "python-env/bin/pip" ]; then
      pipexe="python-env/bin/pip"
    elif [ -f "python-env/Scripts/pip.exe" ]; then
      pipexe="python-env/Scripts/pip.exe"
    else
      curl https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py
      python-env/bin/python get-pip.py || sudo python-env/bin/python get-pip.py
      rm /tmp/get-pip.py
    fi
    "$pipexe" install -r requirements-pip.txt --force || sudo "$pipexe" install -r requirements-pip.txt --force
  )
}

install_shell_tools() {
  local packages shellcheck_version
  packages=()
  if [ -n "$(which shellcheck)" ]; then
    # min version 0.6.0, for --severity=style
    shellcheck_version="$(parse_version "text=$(shellcheck -V)")"
    if version_compare "$shellcheck_version" "0.6.0" "<"; then
      packages+=("shellcheck")
    fi
  else
    packages+=("shellcheck")
  fi
  if [ -z "$(which shfmt)" ]; then
    packages+=("shfmt")
  fi
  if [ "${#packages[@]}" -gt 0 ]; then
    if [ -n "$(which brew)" ]; then
      brew update
      brew install ${packages[*]}
    elif [ -n "$(which apt-get)" ]; then
      sudo apt-get update
      if [ "$answer" = "yes" ]; then
        sudo apt-get install -y ${packages[*]}
      else
        sudo apt-get install ${packages[*]}
      fi
    elif [ -n "$(which pacman)" ]; then
      sudo pacman -Syu ${packages[*]}
    elif [ -n "$(which apk)" ]; then
      apk --update add ${packages[*]}
    else
      echo "Error: cannot install requirements: ${packages[*]}" >&2
      echo "Try installing manually." >&2
      return 1
    fi
  fi
}

install_stylua() {
  if [ -n "$(which cargo)" ]; then
    cargo +stable install stylua --features luau
  else
    echo "Error: cannot install stylua - could not find a cargo executable." >&2
    return 1
  fi
}

install_uncrustify() {
  local answer
  answer="${1//answer=/}"
  if [ -n "$(which brew)" ]; then
    brew update
    brew install uncrustify
  elif [ -n "$(which apt-get)" ]; then
    sudo apt-get update
    if [ "$answer" = "yes" ]; then
      sudo apt-get install -y uncrustify
    else
      sudo apt-get install uncrustify
    fi
  elif [ -n "$(pacman)" ]; then
    sudo pacman -Syu uncrustify
  elif [ -n "$(which apk)" ]; then
    apk --update add uncrustify
  else
    echo "Error: cannot install requirements: uncrustify" >&2
    echo "Try installing manually." >&2
    return 1
  fi
}

validate_nimpretty() {
  if [ -z "$(which nimpretty)" ]; then
    echo "Error: nimpretty not found." >&2
    echo "nimpretty is included with Nim. Try installing a Nim release manually." >&2
    return 1
  fi
}
