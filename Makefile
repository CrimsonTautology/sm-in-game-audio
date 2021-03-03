# general Makefile for compiling Sourcemod plugins
# copyright (c) 2021 https://github.com/CrimsonTautology

SHELL=/bin/bash

# directories
override scripting_dir=addons/sourcemod/scripting
override include_dir=addons/sourcemod/scripting/include
override plugins_dir=addons/sourcemod/plugins
override configs_dir=addons/sourcemod/configs
override extensions_dir=addons/sourcemod/extensions
override gamedata_dir=addons/sourcemod/gamedata
override translations_dir=addons/sourcemod/translations

# spcomp
SPCOMP=spcomp
IFLAGS=-i$(include_dir)
SPFLAGS=
DEBUG=

# other programs
CTAGS=ctags
DOS2UNIX=dos2unix

# files
override sourcefiles=$(wildcard $(scripting_dir)/*.sp)
override includefiles=$(shell find $(include_dir) -name '*.inc' 2>/dev/null)

override plugins=\
	$(patsubst $(scripting_dir)/%.sp, $(plugins_dir)/%.smx, $(sourcefiles))

override configs=\
	$(shell find $(configs_dir) -name '*' -type f 2>/dev/null)

override extensions=\
	$(shell find $(extensions_dir) -name '*.so' -type f 2>/dev/null)

override gamedata=\
	$(shell find $(gamedata_dir) -name '*.txt' -type f 2>/dev/null)

override translations=\
	$(shell find $(translations_dir) -name '*.phrases.txt' -type f 2>/dev/null)

# installation
SRCDS=/tmp
override disabled=$(addprefix $(plugins_dir)/,\
	$(notdir $(wildcard $(SRCDS)/$(plugins_dir)/disabled/*.smx)))

vpath %.sp $(scripting_dir)

ifeq ($(DEBUG), 1)
	SPFLAGS+=DEBUG=1
endif

all: clean compile

clean:
	$(RM) $(plugins_dir)/*.smx $(plugins_dir)/*.asm $(plugins_dir)/*.lst 

compile: $(plugins)

$(plugins_dir)/%.smx: %.sp | plugins
	$(SPCOMP) $^ -o$@ $(IFLAGS) $(SPFLAGS)

plugins:
	mkdir -p $(plugins_dir)

list:
	@printf 'plugins:\n'
	@printf '%s\n' $(plugins)
	@printf '\ndisabled plugins on install server:\n'
	@printf '%s\n' $(disabled)
	@printf '\nsource files:\n'
	@printf '%s\n' $(sourcefiles)
	@printf '\ninclude files:\n'
	@printf '%s\n' $(includefiles)
	@printf '\nconfigs:\n'
	@printf '%s\n' $(configs)
	@printf '\ngamedata:\n'
	@printf '%s\n' $(gamedata)
	@printf '\nextensions:\n'
	@printf '%s\n' $(extensions)
	@printf '\ntranslation:\n'
	@printf '%s\n' $(translations)

install:
	@# install only plugins that are not in the 'disabled' folder
	@$(foreach file, $(filter-out $(disabled), $(plugins)),\
		cp --parents $(file) -t $(SRCDS);)
	@if [ -n "$(plugins)" ]; then cp -n --parents $(plugins) -t $(SRCDS); fi
	@if [ -n "$(configs)" ]; then cp -n --parents $(configs) -t $(SRCDS); fi
	@if [ -n "$(extensions)" ]; then cp -n --parents $(extensions) -t $(SRCDS); fi
	@if [ -n "$(gamedata)" ]; then cp --parents $(gamedata) -t $(SRCDS); fi
	@if [ -n "$(translations)" ]; then cp --parents $(translations) -t $(SRCDS); fi
	@echo "install $(notdir $(filter-out $(disabled), $(plugins)) $(extensions)) to $(SRCDS)"

uninstall:
	@$(RM) \
		$(addprefix $(SRCDS)/, $(plugins)) \
		$(addprefix $(SRCDS)/, $(configs)) \
		$(addprefix $(SRCDS)/, $(gamedata)) \
		$(addprefix $(SRCDS)/, $(translations))
	@echo "uninstall $(notdir $(plugins)) from $(SRCDS)"

tags:
	@$(CTAGS) --langmap=c:+.sp,c:+.inc --recurse $(sourcefiles) $(includefiles)

dos2unix:
	@$(DOS2UNIX) $(sourcefiles) $(includefiles) $(configs) $(gamedata) $(translations)

.PHONY: all clean compile plugins list install uninstall tags dos2unix
