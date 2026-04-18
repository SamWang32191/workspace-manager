SHELL := /bin/bash

.PHONY: test
test:
	bash tests/help_test.sh
	bash tests/list_profiles_test.sh
