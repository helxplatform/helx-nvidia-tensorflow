# Makefile for building a docker iamge.

# Thanks to  https://gist.github.com/mpneuried/0594963ad38e68917ef189b4e6a269db
# for a lot of this.
#
# import config.
# You can change the default config with `make cnf="config_special.env" build`
cnf ?= config.env
include $(cnf)
export $(shell sed 's/=.*//' $(cnf))

DATETIME := $(shell /bin/date "+%Y%m%d%H%M")
# get the latest commit hash in the short form
COMMIT_HASH := $(shell git rev-parse --short HEAD)
COMMIT_DATETIME := $(shell git log -1 --format=%cd --date=format:"%Y%m%d%H%M")
ifneq ($(shell git status --porcelain),)
    # add the date/time and '-dirty' if the tree is dirty
	COMMIT_HASH := $(COMMIT_HASH)-$(DATETIME)-dirty
else
	# add the commit date/time if the tree is clean
	COMMIT_HASH := $(COMMIT_HASH)-$(COMMIT_DATETIME)
endif

# HELP
# This will output the help for each task
# thanks to https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
.PHONY: help build build-nc build-kaniko run run-kaniko up stop release \
	publish publish-latest publish-version publish-short-hash \
	tag tag-latest tag-version tag-short-hash docker-clean 

help: ## This help.
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.DEFAULT_GOAL := help

build: ## Build the image.
	    docker build --pull \
		--build-arg BASE_IMAGE=${BASE_IMAGE} \
		--build-arg BASE_IMAGE_TAG=${BASE_IMAGE_TAG} \
		-t ${APP_NAME} .

build-nc: ## Build the image without caching.
	    docker build --pull --no-cache \
		--build-arg BASE_IMAGE=${BASE_IMAGE} \
		--build-arg BASE_IMAGE_TAG=${BASE_IMAGE_TAG} \
		-t ${APP_NAME} .

build-kaniko: ## Build the image with Kaniko.
		./create-image-registry-auth-file.sh
		docker run \
			-v $(PWD)/.image-registry-auth-config.json:/kaniko/.docker/config.json:ro \
    		-v $(PWD):/workspace \
    		gcr.io/kaniko-project/executor:latest \
    		--dockerfile Dockerfile \
			--build-arg BASE_IMAGE=${BASE_IMAGE} \
			--build-arg BASE_IMAGE_TAG=${BASE_IMAGE_TAG} \
    		--destination "$(IMAGE_REPO)/$(APP_NAME):$(TAG)" \
    		--context dir:///workspace/
		dd if=/dev/urandom of=.image-registry-auth-config.json bs=10 count=20
		rm .image-registry-auth-config.json
		echo "WARNING: The file/dir permission changes don't seem to be kept in the kaniko-built image."

run: ## Run container on port configured in `config.env`
	mkdir -p ./host
	docker run -i -t --rm --env-file=./run.env -u $(UID):$(GID) \
	  $(HOST_MOUNT) $(GPUS_ARG) -p=$(HOST_PORT):$(CONTAINER_PORT) \
	  --name="$(APP_NAME)" $(ENTRYPOINT_ARG) $(APP_NAME) $(ENTRYPOINT) \
	  $(DOCKER_RUN_CMD_ARGS)

run-kaniko: ## Run container on port configured in `config.env` using remote image built by Kaniko.
	mkdir -p ./host
	docker run -i -t --rm --env-file=./run.env -u $(UID):$(GID) \
	  -v $(PWD)/host:/host -p=$(HOST_PORT):$(CONTAINER_PORT) \
	  --name="$(APP_NAME)" $(ENTRYPOINT_ARG) $(IMAGE_REPO)/$(APP_NAME):$(TAG) \
	  $(ENTRYPOINT) $(DOCKER_RUN_CMD_ARGS)

up: build run ## Run container on port configured in `config.env` (Alias to run)

stop: ## Stop and remove a running container
	docker stop $(APP_NAME); docker rm $(APP_NAME)

release: build-nc publish ## Make a release by building and publishing tagged containers to ECR

# Docker publish
publish: publish-latest publish-version publish-short-hash ## Publish tags
	@echo 'publish tags latest $(TAG) $(COMMIT_HASH) to $(IMAGE_REPO)'

publish-latest: tag-latest ## Publish the `latest` tagged container to ECR
	@echo 'publish latest to $(IMAGE_REPO)'
	docker push $(IMAGE_REPO)/$(APP_NAME):latest

publish-version: tag-version ## Publish the `{TAG}` tagged container to ECR
	@echo 'publish $(TAG) to $(IMAGE_REPO)'
	docker push $(IMAGE_REPO)/$(APP_NAME):$(TAG)

publish-short-hash: tag-short-hash ## Publish the short-hash tagged container to ECR
	@echo 'publish $(COMMIT_HASH) to $(IMAGE_REPO)'
	docker push $(IMAGE_REPO)/$(APP_NAME):$(COMMIT_HASH)

# Docker tagging
tag: tag-latest tag-version tag-short-hash ## Generate container tags

tag-latest: ## Generate container `latest` tag
	@echo 'create tag latest'
	docker tag $(APP_NAME) $(IMAGE_REPO)/$(APP_NAME):latest

tag-version: ## Generate container `{TAG}` tag
	@echo 'create tag $(TAG)'
	docker tag $(APP_NAME) $(IMAGE_REPO)/$(APP_NAME):$(TAG)

tag-short-hash: ## Generate container short-hash tag created from last commit or current datetime if tree is dirty
	@echo 'create tag $(COMMIT_HASH)'
	docker tag $(APP_NAME) $(IMAGE_REPO)/$(APP_NAME):$(COMMIT_HASH)

docker-clean: ## Prune unused images, containers, and networks from the local Docker system.
	docker system prune -f
