# contains /usr/local/opt/ruby/bin $fish_user_paths; or set -Ua fish_user_paths /usr/local/opt/ruby/bin
# set -x PATH /usr/local/lib/ruby/gems/2.6.0/bin $PATH
# set -gx LDFLAGS "-L/usr/local/opt/ruby/lib"
# set -gx CPPFLAGS "-I/usr/local/opt/ruby/include"
# set -gx PKG_CONFIG_PATH "/usr/local/opt/ruby/lib/pkgconfig"

set -e LDFLAGS
status --is-interactive; and rbenv init - fish | source
