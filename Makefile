.PHONY: build run simple advanced clean help

IMAGE_NAME := organize-dedup
VERSION := 2.0.0

help:
	@echo "organize-dedup Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  build         Build Docker image"
	@echo "  run           Run with custom options (use OPTS variable)"
	@echo "  simple        Run in simple mode"
	@echo "  advanced      Run in advanced mode (default)"
	@echo "  clean         Remove Docker image"
	@echo "  help          Show this help message"
	@echo ""
	@echo "Examples:"
	@echo "  make build"
	@echo "  make simple INPUT=/path/to/files OUTPUT=/path/to/output"
	@echo "  make advanced INPUT=/path/to/files OUTPUT=/path/to/output"
	@echo "  make run OPTS='--mode simple --hash-algorithm md5'"

build:
	docker build -t $(IMAGE_NAME):$(VERSION) -t $(IMAGE_NAME):latest .

run:
	docker run --rm \
		-v $(INPUT):/input \
		-v $(OUTPUT):/output \
		$(IMAGE_NAME):latest \
		-i /input -o /output $(OPTS)

simple:
	docker run --rm \
		-v $(INPUT):/input \
		-v $(OUTPUT):/output \
		$(IMAGE_NAME):latest \
		--mode simple -i /input -o /output

advanced:
	docker run --rm \
		-v $(INPUT):/input \
		-v $(OUTPUT):/output \
		$(IMAGE_NAME):latest \
		--mode advanced -i /input -o /output

clean:
	docker rmi $(IMAGE_NAME):$(VERSION) $(IMAGE_NAME):latest
