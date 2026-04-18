.RECIPEPREFIX := >
SHELL := /bin/bash

.PHONY: test
test:
> bash tests/help_test.sh
> bash tests/list_profiles_test.sh
> bash tests/create_workspace_test.sh
> bash tests/sync_workspace_test.sh
