LUA ?= lua

BUSTED ?= .mani/tree/bin/busted
LUACHECK ?= .mani/tree/bin/luacheck

LUAROCKS ?= luarocks

SRC = $(shell find src/ -name "*.lua")

.PHONY: install dev test test-all lint clean

install:
	$(LUAROCKS) install --tree=.mani/tree --only-deps rockspecs/mani-dev-1.rockspec
	$(LUAROCKS) install --tree=.mani/tree busted
	$(LUAROCKS) install --tree=.mani/tree luacheck
   
dev: install
	$(LUAROCKS) make --tree=.mani/tree rockspecs/mani-dev-1.rockspec

test:
	$(BUSTED) --exclude-tags=interactive,network spec/

test-all:
	$(BUSTED) spec/

lint:
	$(LUACHECK) src/ spec/

clean:
	rm -rf .mani/tree
	rm -f mani.lock.lua