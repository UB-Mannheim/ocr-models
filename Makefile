SHELL := /bin/bash
PATH := ./node_modules/.bin:$(PATH)
DOCKER_IMAGE := kbai/ocr-models

TRAF = traf
AJV = ajv validate --all-errors
MKDIR = mkdir -p
ZIP = zip -r
RM = rm -rf

SED ?= sed

METADATA_SCHEMA = schema/description.schema.json
MODEL_DESCRIPTIONS = $(shell find . -name 'DESCRIPTION'|$(SED) -e 's,^./,,')
ZIPPED_MODELS = $(shell find . -name 'DESCRIPTION'|$(SED) -e 's,./models,zip,' -e 's,/DESCRIPTION,.zip,')

all: zip db

.PHONY: db
db: models.ndjson

models.ndjson: $(MODEL_DESCRIPTIONS)
	@$(RM) "$@"
	@for desc in $(MODEL_DESCRIPTIONS);do \
		id=$$desc; \
		id=$${id/models\//}; \
		id=$${id/\/DESCRIPTION/}; \
		id="$$(echo $$id | tr '[:upper:]' '[:lower:]')"; \
		zip="zip/$$id.zip"; \
		zip_size="$$(wc -c zip/$$id.zip|cut -d' ' -f1)"; \
		echo ">>> DB-ifying $$desc"; \
		cat "$$desc" \
			| $(SED) "1a \"_id\": \"$$id\"," \
			| $(SED) "2a \"zip\": \"$$zip\"," \
			| $(SED) "3a \"zip-size\": \"$$zip_size\"," \
			| $(TRAF) -i JSON -o JSON - - \
			2>/dev/null \
			>> "$@" ; \
		echo >> "$@"; \
	done


.PHONY: zip
zip: $(ZIPPED_MODELS)

$(ZIPPED_MODELS) : zip/%.zip: models/%
	@$(MKDIR) $(dir $@)
	@echo ">>> Zipping $<"
	@$(ZIP) -j "$@" "$<" >/dev/null

.PHONY: schema
schema: $(METADATA_SCHEMA)

schema/%.json: schema/%.yml
	$(TRAF) "$<" "$@"

validate: schema
	@echo ">>>"
	@echo ">>> Validating metadata"
	@echo ">>>"
	@find . -name 'DESCRIPTION' -exec \
		$(AJV) -s "$(METADATA_SCHEMA)" -d "{}" \;

docker:
	docker build -t '$(DOCKER_IMAGE)' .
