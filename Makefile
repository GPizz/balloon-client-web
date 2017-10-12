SHELL=/bin/bash

# DIRECTORIES
BASE_DIR = .
NODE_MODULES_DIR = $(BASE_DIR)/node_modules
DIST_DIR = $(BASE_DIR)/dist
BUILD_DIR = $(BASE_DIR)/build
PACK_DIR = $(BASE_DIR)/pack

# VERSION
VERSION = $(shell cat $(BASE_DIR)/package.json | grep '"version"' | cut -d '"' -f4)

# PACKAGES
DEB_LIGHT = $(DIST_DIR)/balloon-web-light-$(VERSION).deb
DEB_FULL = $(DIST_DIR)/balloon-web-full-$(VERSION).deb
TAR = $(DIST_DIR)/balloon-web-$(VERSION).tar.gz

# NPM STUFF
NPM_BIN = npm

# TARGET ALIASES
NPM_TARGET = $(NODE_MODULES_DIR)
WEBPACK_TARGET = $(BUILD_DIR)
CHANGELOG_TARGET = $(PACK_DIR)/DEBIAN/changelog
BUILD_TARGET = $(NPM_TARGET)
# $(WEBPACK_TARGET)


# TARGETS
.PHONY: all
all: dist


.PHONY: clean
clean:
	@-test ! -f $(TAR) || rm -fv $(TAR)
	@-test ! -d $(BUILD_DIR) || rm -rfv $(BUILD_DIR)
	@-test ! -d $(NODE_MODULES_DIR) || rm -rfv $(NODE_MODULES_DIR)
	@-test ! -f $(DIST_DIR)/*.deb || rm -fv $(DIST_DIR)/*.deb


.PHONY: deps
deps: npm


.PHONY: build
build: $(BUILD_TARGET)


.PHONY: dist
dist: tar deb


.PHONY: deb
deb: $(DIST_DIR)/balloon-web-light-$(VERSION).deb $(DIST_DIR)/balloon-web-full-$(VERSION).deb

$(DIST_DIR)/balloon-web-%-$(VERSION).deb: $(CHANGELOG_TARGET) $(BUILD_TARGET)
	@-test ! -d $(PACK_DIR) || rm -rfv $(PACK_DIR)
	@mkdir -p $(PACK_DIR)/DEBIAN
	@cp $(BASE_DIR)/packaging/debian/control-$* $(PACK_DIR)/DEBIAN/control
	@sed -i s/'{version}'/$(VERSION)/g $(PACK_DIR)/DEBIAN/control
	@mkdir -p $(PACK_DIR)/usr/share/balloon-web
	@cp -Rp $(BUILD_DIR)/* $(PACK_DIR)/usr/share/balloon-web
	@-test -d $(DIST_DIR) || mkdir $(DIST_DIR)
	@dpkg-deb --build $(PACK_DIR) $@
	@rm -rf $(PACK_DIR)


.PHONY: tar
tar: $(TAR)

$(TAR): $(BUILD_TARGET)
	@-test ! -f $(TAR) || rm -fv $(TAR)
	@-test ! -d $(PACK_DIR) || rm -rfv $(PACK_DIR)
	@-test -d $(DIST_DIR) || mkdir $(DIST_DIR)
	@mkdir $(PACK_DIR)
	@cp -Rp $(BUILD_DIR)/* $(PACK_DIR)

	@tar -czvf $(TAR) -C $(PACK_DIR) .
	@rm -rf $(PACK_DIR)

	@echo "package available at $(TAR)"
	@echo "MD5 CHECKSUM: `md5sum $(TAR) | cut -d' ' -f1`"
	@touch $@


.PHONY: changelog
changelog: $(CHANGELOG_TARGET)

$(CHANGELOG_TARGET): CHANGELOG.md
	@-test -d $(@D) || mkdir -p $(@D)
	@v=""
	@stable="stable"
	@author=""
	@date=""
	@changes=""
	@-test ! -f $@ || rm $@

	@while read l; \
	do \
		if [ "$${l:0:2}" == "##" ]; \
		then \
	 		if [ "$$v" != "" ]; \
	 		then \
	 			echo "balloon ($$v) $$stable; urgency=low" >> $@; \
	 			echo -e "$$changes" >> $@; \
	 			echo >>  $@; \
	 			echo " -- $$author  $$date" >> $@; \
	 			echo >>  $@; \
	 			v=""; \
	 			stable="stable"; \
	 			author=";" \
	 			date=";" \
	 			changes=""; \
	 		fi; \
	 		v=$${l:3}; \
			if [[ "$$v" == *"RC"* ]]; \
	 	 	then \
	 			stable="unstable"; \
	 		elif [[ "$$v" == *"BETA"* ]]; \
	 		then \
	 			stable="unstable"; \
	 		elif [[ "$$v" == *"ALPHA"* ]]; \
	 		then \
	 			stable="unstable"; \
	 		elif [[ "$$v" == *"dev"* ]]; \
			then \
	 			stable="unstable"; \
	 		fi \
	 	elif [ "$${l:0:5}" == "**Mai" ]; \
	 	then \
	 		p1=`echo $$l | cut -d '>' -f1`; \
	 		p2=`echo $$l | cut -d '>' -f2`; \
	 		author="$${p1:16}>"; \
	 		date=$${p2:13}; \
	 		date=`date -d"$$date" +'%a, %d %b %Y %H:%M:%S %z'`; \
			if [ $$? -ne 0 ]; \
			then \
				date=`date +'%a, %d %b %Y %H:%M:%S %z'`; \
			fi; \
			echo $$date; \
	 	elif [ "$${l:0:2}" == "* " ]; \
	 	then \
			changes="  $$changes\n  $$l"; \
	 	fi; \
	done < $<
	@echo generated $@ from $<


.PHONY: npm
npm: $(NPM_TARGET)

$(NPM_TARGET) : $(BASE_DIR)/package.json
	@test "`$(NPM_BIN) install --dry-run 2>&1 >/dev/null | grep Failed`" == ""
	$(NPM_BIN) update
	@touch $@


.PHONY: webpack
webpack: $(WEBPACK_TARGET)

$(WEBPACK_TARGET) : $(BASE_DIR)/package.json
	@test "`$(NPM_BIN) run build --dry-run 2>&1 >/dev/null | grep Failed`" == ""
	$(NPM_BIN) run build
	@touch $@
