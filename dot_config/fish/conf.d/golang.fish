set -x GOPATH $HOME/go
# set -x GOROOT "$(brew --prefix go)/libexec"
set -x GOROOT /opt/homebrew/opt/go/libexec
set -x PATH $PATH $GOPATH/bin $GOROOT/bin
