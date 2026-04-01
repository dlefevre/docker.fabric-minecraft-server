IMAGE  := minecraft-fabric
TAG    := latest

.PHONY: build build-x86 clean

build:
	docker build -t $(IMAGE):$(TAG) .

build-x86:
	docker buildx build --platform linux/amd64 -t $(IMAGE):$(TAG) .

clean:
	docker rmi $(IMAGE):$(TAG)
