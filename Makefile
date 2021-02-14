SHELL = /bin/sh
.DELETE_ON_ERROR:

VENDOR ?= networkradius
PROJECT ?= interop-eap-tls13

COMMITID = $(shell git rev-parse --short HEAD | tr -d '\n')$(shell git diff-files --quiet || printf -- -dirty)

PACKER_VERSION = 1.6.6
PACKER_BUILD_FLAGS += -var vendor=$(VENDOR) -var project=$(PROJECT) -var commit=$(COMMITID)

KERNEL = $(shell uname -s | tr A-Z a-z)
ifeq ($(shell uname -m),x86_64)
MACHINE = amd64
else
MACHINE = 386
endif

CLEAN =
DISTCLEAN =

.PHONY: all
all: dev

.PHONY: clean
clean:
	-docker rmi $(VENDOR)/$(PROJECT) 2>&-
	rm -rf $(CLEAN)

.PHONY: distclean
distclean: clean
	rm -rf $(DISTCLEAN)

.PHONY: notdirty
notdirty:
ifneq ($(findstring -dirty,$(COMMITID)),)
ifeq ($(IDDQD),)
	@{ echo 'DIRTY DEPLOYS FORBIDDEN, REJECTING DEPLOY DUE TO UNCOMMITED CHANGES' >&2; git status; exit 1; }
else
	@echo 'DIRTY DEPLOY BUT GOD MODE ENABLED' >&2
endif
endif

.PHONY: dev
ifneq ($(shell docker version 2>&-),)
dev: PORT ?= 1812
dev: .stamp.docker
	-docker run -it --rm \
		--name $(PROJECT) \
		-e container=docker \
		-v $(CURDIR)/eapol_test:/opt/$(VENDOR)/$(PROJECT)/eapol_test:ro \
		-v $(CURDIR)/services:/opt/$(VENDOR)/$(PROJECT)/services:ro \
		--publish=$(PORT):1812/udp --publish=$(PORT):1812/tcp \
		--tmpfs /run \
		-v /sys/fs/cgroup:/sys/fs/cgroup:ro \
		--ulimit memlock=$$((128 * 1024)) \
		--security-opt apparmor=unconfined \
		--cap-add SYS_ADMIN --cap-add NET_ADMIN --cap-add SYS_PTRACE \
		--stop-signal SIGPWR \
		$(VENDOR)/$(PROJECT):latest

ifeq ($(shell docker images -q $(VENDOR)/$(PROJECT)),)
.PHONY: .stamp.docker
endif
.stamp.docker: packer.json .stamp.packer setup
	env TMPDIR=$(CURDIR) ./packer build -on-error=ask -only docker $(PACKER_BUILD_FLAGS) $<
	touch $@
CLEAN += .stamp.docker
else
dev:
	@{ echo you need Docker to be installed to start a dev environment >&2; exit 1; }
endif

packer_$(PACKER_VERSION)_$(KERNEL)_$(MACHINE).zip:
	curl -f -O -J -L https://releases.hashicorp.com/packer/$(PACKER_VERSION)/$@
DISTCLEAN += $(wildcard packer_*.zip)

packer: packer_$(PACKER_VERSION)_$(KERNEL)_$(MACHINE).zip
	unzip -oDD $< $@
DISTCLEAN += packer

.stamp.packer: packer.json packer
	./packer validate $(PACKER_BUILD_FLAGS) $<
	@touch $@
CLEAN += .stamp.packer

.PHONY: release
release:
	git tag --force $@
	git push --force --tag origin master
