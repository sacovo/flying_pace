
build = build

.PHONY: test fetch

fetch:
	corral fetch

test: $(build)/test
	./build/test

usage: $(build)/usage

$(build)/test: flying_pace/*
	@mkdir -p $(build)
	corral run -- ponyc -Dopenssl_3.0.x --debug --output $(build) flying_pace/test

$(build)/usage: flying_pace/* examples/usage/*
	@mkdir -p $(build)
	corral run -- ponyc -Dopenssl_3.0.x --debug --output $(build) examples/usage
	
clean:
	corral clean
	rm -rf build
