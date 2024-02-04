
build = build

.PHONY: test fetch

fetch:
	corral fetch

test: $(build)/test
	./build/test

$(build)/test: flying_pace/*
	@mkdir -p $(build)
	corral run -- ponyc -Dopenssl_3.0.x --debug --output $(build) flying_pace/test
	
clean:
	corral clean
	rm -rf build
