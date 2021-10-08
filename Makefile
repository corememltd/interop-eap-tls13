SHELL = /bin/sh
.DELETE_ON_ERROR:

VENDOR ?= networkradius
PROJECT ?= interop-eap-tls13

COMMITID = $(shell git rev-parse --short HEAD | tr -d '\n')$(shell git diff-files --quiet || printf -- -dirty)

BRANCH ?= v3.0.x
TAG ?= release_3_0_25

PACKER_VERSION = 1.7.2
PACKER_BUILD_FLAGS += -var vendor=$(VENDOR) -var project=$(PROJECT) -var commit=$(COMMITID) -var branch=$(BRANCH) -var tag=$(TAG)

KERNEL = $(shell uname -s | tr A-Z a-z)
ifneq ($(KERNEL),darwin)
ifeq ($(shell uname -m),x86_64)
MACHINE = amd64
else
MACHINE = 386
endif
else
# arm64 not yet supported but macOS provides a translation layer
MACHINE = amd64
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
dev: L2TP_PORT ?= 1701
dev: .stamp.docker
	-docker run -it --rm \
		--name $(PROJECT) \
		-e container=docker \
		-v $(CURDIR)/eapol_test:/opt/$(VENDOR)/$(PROJECT)/eapol_test:ro \
		-v $(CURDIR)/services:/opt/$(VENDOR)/$(PROJECT)/services:ro \
		--publish=$(PORT):1812/udp --publish=$(PORT):1812/tcp \
		--publish=$(L2TP_PORT):1701/udp --publish=$(L2TP_PORT):1701/tcp \
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
ifneq ($(FROM),)
.stamp.docker: PACKER_BUILD_FLAGS += -var from=$(FROM)
endif
.stamp.docker: packer.json .stamp.packer setup
	env TMPDIR=$(CURDIR) ./packer build -on-error=ask -only docker $(PACKER_BUILD_FLAGS) $<
	touch $@
CLEAN += .stamp.docker
else
dev:
	@{ echo you need Docker to be installed to start a dev environment >&2; exit 1; }
endif

.PHONY: deploy
ifneq ($(SSH_HOST),)
deploy: PACKER_BUILD_FLAGS += -var ssh_host=$(SSH_HOST)
endif
ifneq ($(SSH_USER),)
deploy: PACKER_BUILD_FLAGS += -var ssh_user=$(SSH_USER)
endif
deploy: packer.json .stamp.packer
ifeq ($(SSH_HOST),)
	@{ echo you need Docker to be installed to start a dev environment >&2; exit 1; }
endif
	env TMPDIR=$(CURDIR) ./packer build -only null $(PACKER_BUILD_FLAGS) $<

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
release: notdirty
	git tag --force $@
	git push --force --tag origin master
