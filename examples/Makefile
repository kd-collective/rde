# profiles.mk provides guix version specified by rde/channels-lock.scm
# To rebuild channels-lock.scm use `make -B rde/channels-lock.scm`
include profiles.mk

# Also defined in .envrc to make proper guix version available project-wide
GUIX_PROFILE=target/profiles/guix
GUIX=GUILE_LOAD_PATH="../src:../env:../tests:./src:./rde" GUILE_LOAD_COMPILED_PATH="" ${GUIX_PROFILE}/bin/guix

SRC_DIR=./src
CONFIGS=${SRC_DIR}/rde-configs/configs.scm
PULL_EXTRA_OPTIONS=
# --allow-downgrades

ROOT_MOUNT_POINT=/mnt

VERSION=latest

repl: ares

ares:
	${GUIX} shell guile-next guile-ares-rs \
	-e '(@ (rde packages package-management) guix-from-channels-lock)' \
	-- guile \
	-L ../src \
	-L ../env \
	-L ./rde \
	-L ./src \
	-L /data/abcdw/work/abcdw/guile-ares-rs/src/guile \
	-c \
"(begin (use-modules (guix gexp)) #;(load gexp reader macro globally) \
((@ (ares server) run-nrepl-server) #:nrepl-port-path \"../.nrepl-port\"))"

ixy/home/build: guix
	RDE_TARGET=ixy-home ${GUIX} home \
	build ${CONFIGS}

ixy/home/reconfigure: guix
	RDE_TARGET=ixy-home ${GUIX} home \
	reconfigure ${CONFIGS}

ixy/system/build: guix
	RDE_TARGET=ixy-system ${GUIX} system \
	build ${CONFIGS}

ixy/system/reconfigure: guix
	RDE_TARGET=ixy-system ${GUIX} system \
	reconfigure ${CONFIGS}

cow-store:
	sudo herd start cow-store ${ROOT_MOUNT_POINT}

ixy/system/init: guix
	RDE_TARGET=ixy-system ${GUIX} system \
	init ${CONFIGS} ${ROOT_MOUNT_POINT}

target:
	mkdir -p target

live/image/build: guix
	RDE_TARGET=live-system ${GUIX} system image --image-type=iso9660 \
	${CONFIGS}

target/rde-live.iso: guix target
	RDE_TARGET=live-system ${GUIX} system image --image-type=iso9660 \
	${CONFIGS} -r target/rde-live-tmp.iso
	mv -f target/rde-live-tmp.iso target/rde-live.iso

target/release:
	mkdir -p target/release

# TODO: Prevent is rebuilds.
release/rde-live-x86_64: target/rde-live.iso target/release
	cp -df $< target/release/rde-live-${VERSION}-x86_64.iso
	gpg -ab target/release/rde-live-${VERSION}-x86_64.iso

minimal-emacs: guix
	${GUIX} shell --pure -Df ./src/rde-configs/minimal-emacs.scm \
	-E '.*GTK.*|.*XDG.*|.*DISPLAY.*' \
	--rebuild-cache -- emacs -q \
	--eval "(load \"~/.config/emacs/early-init.el\")"
	#--eval "(require 'feature-loader-portable)"

minimal/home/build: guix
	${GUIX} home build ./src/rde-configs/minimal.scm

minimal/home/build/ci:
	guix time-machine -C rde/channels-ci.scm -- \
	home build ./src/rde-configs/minimal.scm

minimal/home/build/ci-no-auth:
	guix time-machine -C rde/channels-ci.scm --disable-authentication -- \
	home build ./src/rde-configs/minimal.scm

cloud-rde: guix
	${GUIX} system image -e '(@ (rde-configs hosts cloud) cloud-image)'

clean-target:
	rm -rf ./target

clean: clean-target
