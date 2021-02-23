.PHONY: default

VERSION='latest'
DEFAULT_BUILD_ARGS = --build-arg http_proxy=$(http_proxy) --build-arg https_proxy=$(https_proxy) --build-arg no_proxy=$(no_proxy) --network=host

default: test-all

build-all: build

test-all: test

build:
	# this weird shitty stuff with version in name due to https://github.com/docker/compose/issues/3660
	docker build --rm --force-rm -t mslipets/my-bloody-sonar-${VERSION} $(DEFAULT_BUILD_ARGS) --build-arg=FROM_TAG=$(VERSION) .

test: build
	bats tests

#TODO: https://github.com/mslipets/my-bloody-sonar/issues/1
#update-plugins:
#	env python3 $(PWD)/get-latest-plugins.py
#	git diff plugins.txt | grep  '^+' | sed 's|+||' | grep -v + | awk -F \: '{print "* ["$$1":"$$2"](https://plugins.jenkins.io/" $$1 ")"}'

release:
	$(eval NEW_INCREMENT := $(shell expr `git describe --tags --abbrev=0 | cut -d'-' -f2` + 1))
	git tag v$(VERSION)-$(NEW_INCREMENT)
	git push origin v$(VERSION)-$(NEW_INCREMENT)
