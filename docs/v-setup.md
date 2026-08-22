# Prerequisite

These steps are for people that are trying [Vlang](https://vlang.io) for the first time

## Installation

Go to [Vlang Homepage](https://vlang.io/) and click the download button and add it to your `$PATH` environment variable. 

### Compile from source

To install it from source run the commands below. It takes only a few seconds:
```sh
git clone --depth=1 https://github.com/vlang/v
cd v
make
```

## VLS - V Language Server

For whatever reson the plugin doesn't fetch the LSP on it's own, so it'll require some additional work on our end

Start by compile vls from source and add it to your `$PATH` environment variable as well.

```sh
v download -RD https://raw.githubusercontent.com/vlang/v-analyzer/main/install.vsh
```

Now install the [V Extension for vscode](https://marketplace.visualstudio.com/items?itemName=vlanguage.vscode-vlang) and right clicking on it to and opening settings and update the `V › Vls: Command` to the path where v-analyzer is located with "v-analyzer" binary name appended at the end like `/Users/<YOUR_USERNAME>/.config/v-analyzer/bin/v-analyzer`


