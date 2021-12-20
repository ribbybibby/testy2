ROOT_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

GO_VERSION ?= 1.14
GO := $(or $(shell which go$(GO_VERSION)),$(shell which go))

OS := $(shell $(GO) env GOOS)
ARCH := $(shell $(GO) env GOARCH)

BIN?=$(ROOT_DIR)/.bin

# Make sure BIN is on the PATH
export PATH := $(BIN):$(PATH)

COSIGN_VERSION := 1.4.1
COSIGN := $(BIN)/cosign-$(COSIGN_VERSION)

GHA_SLSA_VERSION := 0.4.0
GHA_SLSA := $(BIN)/slsa-provenance-$(GHA_SLSA_VERSION)

$(BIN):
	mkdir -p $(BIN)

$(COSIGN): $(BIN)
	curl -sSL -o $(COSIGN) https://github.com/sigstore/cosign/releases/download/v$(COSIGN_VERSION)/cosign-$(OS)-$(ARCH) && \
	chmod +x $(COSIGN)

$(GHA_SLSA): $(BIN)
	mkdir -p $(BIN)/slsa
	wget -qO - https://github.com/philips-labs/slsa-provenance-action/releases/download/v$(GHA_SLSA_VERSION)/slsa-provenance_$(GHA_SLSA_VERSION)_$(OS)_$(ARCH).tar.gz | tar xvz -C $(BIN)/slsa/
	mv $(BIN)/slsa/slsa-provenance $(GHA_SLSA)
	chmod +x $(GHA_SLSA)

IMAGE_DOCKERFILES:=$(wildcard $(ROOT_DIR)/dockerfiles/*.dockerfile)
IMAGE_TARGETS:= $(patsubst $(ROOT_DIR)/dockerfiles/%.dockerfile,%,$(IMAGE_DOCKERFILES))

COMMIT:=$(shell git rev-list -1 HEAD)
VERSION:=$(COMMIT)

REGISTRY:=eu.gcr.io/jetstack-rob-best

.SECONDEXPANSION:
testy.REQUIREMENTS:= 

SIGN_ALL_IMAGES:= $(addprefix sign-image-,$(IMAGE_TARGETS))
sign-all-images: $(SIGN_ALL_IMAGES)
$(SIGN_ALL_IMAGES): sign-image-%: $(COSIGN)
	@echo "==> Signing $(REGISTRY)/$*:$(VERSION)"
	$(COSIGN) sign $(REGISTRY)/$*:$(VERSION)
	$(COSIGN) verify $(REGISTRY)/$*:$(VERSION)
	@echo "==> Signed and verified $(REGISTRY)/$*:$(VERSION)"

BUILD_ALL_IMAGES:= $(addprefix build-image-,$(IMAGE_TARGETS))
build-all-images: $(BUILD_ALL_IMAGES)
$(BUILD_ALL_IMAGES): build-image-%: $(ROOT_DIR)/dockerfiles/%.dockerfile $$(%.REQUIREMENTS)
	@echo "==> Building $(REGISTRY)/$*:$(VERSION)"
	docker build . --file $< --tag $(REGISTRY)/$*:$(VERSION)
	@echo "==> Built $(REGISTRY)/$*:$(VERSION) successfully"

PUSH_ALL_IMAGES:= $(addprefix push-image-,$(IMAGE_TARGETS))
push-all-images: $(PUSH_ALL_IMAGES)
$(PUSH_ALL_IMAGES): push-image-%:
	@echo "==> Pushing $(REGISTRY)/$* with tags '$(VERSION)' and 'latest'"
	docker tag $(REGISTRY)/$*:$(VERSION) $(REGISTRY)/$*:latest
	docker push $(REGISTRY)/$*:$(VERSION)
	docker push $(REGISTRY)/$*:latest
	@echo "==> Pushed $(REGISTRY)/$* with tags '$(VERSION)' and 'latest'"


ATTEST_ALL_IMAGES:= $(addprefix attest-image-,$(IMAGE_TARGETS))
attest-all-images: $(SIGN_ALL_IMAGES)
$(ATTEST_ALL_IMAGES): attest-image-%: $(COSIGN) $(GHA_SLSA)
	@echo "==> Attaching Github Actions attestation to $(REGISTRY)/$*:$(VERSION)"
	$(GHA_SLSA) generate -artifact_path $(GHA_SLSA) -output_path provenance.json -github_context '$(GITHUB_CONTEXT)' -runner_context '$(RUNNER_CONTEXT)'
	jq '.predicate' provenance.json > predicate.json
	$(COSIGN) attest --type slsaprovenance --predicate predicate.json $(REGISTRY)/$*:$(VERSION)
	$(COSIGN) verify-attestation --type slsaprovenance $(REGISTRY)/$*:$(VERSION)
	@echo "==> Attached Github Actions attestation to $(REGISTRY)/$*:$(VERSION)"

output-image-ref-%:
	echo "::set-output name=image_ref::$(REGISTRY)/$*:$(VERSION)"
